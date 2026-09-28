const { v4: uuidv4 } = require('uuid');
const sheetsService = require('../services/sheetsService');
const biometricService = require('../services/biometricService');
const { validateLocation, calculateHaversineDistanceMeters } = require('../utils/geoUtils');
const { getNowUTC, formatKualaLumpurTime, calculateWorkedDuration } = require('../utils/timeUtils');

/**
 * Retrieves the current dashboard state for an employee:
 * - Assigned office and geofence specifications
 * - Open attendance session if active
 * - Today's status in Asia/Kuala_Lumpur time
 */
async function getDashboardStatus(req, res) {
  try {
    const employeeId = req.user.employeeId;
    const employee = await sheetsService.getEmployeeById(employeeId);

    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    const office = employee.AssignedOfficeID
      ? await sheetsService.getOfficeById(employee.AssignedOfficeID)
      : null;

    const openSession = await sheetsService.getOpenSession(employeeId);
    const nowUtc = getNowUTC();
    const klTime = formatKualaLumpurTime(nowUtc);

    // Get today's completed or in-progress records in KL date
    const todayRecords = await sheetsService.getAttendanceRecords({
      employeeId,
      startDate: klTime.dateKL,
      endDate: klTime.dateKL,
    });

    return res.json({
      success: true,
      serverTimeUTC: nowUtc,
      serverTimeKL: klTime,
      employee: {
        employeeId: employee.EmployeeID,
        name: employee.Name,
        department: employee.Department,
        faceEnrolled: String(employee.FaceEnrolled).toUpperCase() === 'TRUE',
      },
      assignedOffice: office
        ? {
            officeId: office.OfficeID,
            name: office.Name,
            latitude: Number(office.Latitude),
            longitude: Number(office.Longitude),
            radiusMeters: Number(office.RadiusMeters),
            maxAccuracyMeters: Number(office.MaxAccuracyMeters || 50),
            maxAgeSeconds: Number(office.MaxAgeSeconds || 60),
            address: office.Address,
          }
        : null,
      openSession: openSession || null,
      todayRecords,
      statusSummary: openSession ? 'IN_PROGRESS' : todayRecords.length > 0 ? 'COMPLETED' : 'NOT_CLOCKED_IN',
    });
  } catch (err) {
    console.error('[Dashboard Status Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed fetching dashboard status.' });
  }
}

/**
 * Clocks In an employee.
 * Validates GPS location freshness, accuracy, and radius server-side.
 */
async function clockIn(req, res) {
  try {
    const { latitude, longitude, accuracy, timestamp, isMockLocation, notes } = req.body;
    const employeeId = req.user.employeeId;

    // 1. Fetch employee and assigned office
    const employee = await sheetsService.getEmployeeById(employeeId);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee profile not found.' });
    }

    if (!employee.AssignedOfficeID) {
      return res.status(400).json({
        success: false,
        errorCode: 'NO_ASSIGNED_OFFICE',
        message: 'No office location has been assigned to your profile. Contact your manager or HR.',
      });
    }

    const office = await sheetsService.getOfficeById(employee.AssignedOfficeID);
    if (!office || String(office.Active).toUpperCase() === 'FALSE') {
      return res.status(400).json({
        success: false,
        errorCode: 'OFFICE_NOT_AVAILABLE',
        message: 'Assigned office location is inactive or invalid.',
      });
    }

    // 2. Prevent duplicate open sessions
    const existingOpenSession = await sheetsService.getOpenSession(employeeId);
    if (existingOpenSession) {
      return res.status(400).json({
        success: false,
        errorCode: 'SESSION_ALREADY_OPEN',
        message: `You already have an active attendance session opened at ${existingOpenSession.ClockInTimeKL}. Please clock out first.`,
        session: existingOpenSession,
      });
    }

    // 3. Strict Server-Side Location Validation
    const validation = validateLocation({
      clientLat: Number(latitude),
      clientLng: Number(longitude),
      clientAccuracy: Number(accuracy),
      clientTimestamp: timestamp,
      isMockLocation: Boolean(isMockLocation),
      office: {
        latitude: Number(office.Latitude),
        longitude: Number(office.Longitude),
        radiusMeters: Number(office.RadiusMeters),
        maxAccuracyMeters: Number(office.MaxAccuracyMeters),
        maxAgeSeconds: Number(office.MaxAgeSeconds),
        name: office.Name,
      },
    });

    if (!validation.isValid) {
      return res.status(400).json({
        success: false,
        errorCode: validation.errorCode,
        message: validation.errorMessage,
        details: {
          distanceMeters: validation.distanceMeters,
          radiusMeters: validation.radiusMeters,
          accuracy: validation.accuracy,
        },
      });
    }

    // 4. Generate Server Timestamps
    const nowUTC = getNowUTC();
    const klTime = formatKualaLumpurTime(nowUTC);
    const sessionId = uuidv4();

    const newRecord = {
      SessionID: sessionId,
      EmployeeID: employee.EmployeeID,
      EmployeeName: employee.Name,
      Department: employee.Department,
      OfficeID: office.OfficeID,
      WorkDate: klTime.dateKL,
      ClockInTimeUTC: nowUTC,
      ClockInTimeKL: `${klTime.dateKL} ${klTime.timeKL}`,
      ClockOutTimeUTC: '',
      ClockOutTimeKL: '',
      ClockInLat: latitude,
      ClockInLng: longitude,
      ClockInAccuracy: accuracy,
      ClockInDistanceMeters: validation.distanceMeters,
      ClockOutLat: '',
      ClockOutLng: '',
      ClockOutAccuracy: '',
      ClockOutDistanceMeters: '',
      FaceVerified: 'N/A',
      FaceVerificationConfidence: '',
      WorkedMinutes: '',
      WorkedHours: '',
      AttendanceStatus: 'IN_PROGRESS',
      ExceptionNotes: notes || '',
      LastModifiedBy: employee.EmployeeID,
      LastModifiedAt: nowUTC,
    };

    // 5. Persist to Sheets DB
    await sheetsService.saveAttendanceSession(newRecord);

    // 6. Record Audit Log
    await sheetsService.recordAuditLog({
      actorId: employee.EmployeeID,
      actorName: employee.Name,
      action: 'CLOCK_IN',
      affectedRecordType: 'Attendance',
      affectedRecordId: sessionId,
      timestampUTC: nowUTC,
      timestampKL: klTime.displayKL,
      reason: 'Standard Employee Clock-In',
      afterValues: newRecord,
    });

    return res.status(201).json({
      success: true,
      message: `Clock-in successful at ${office.Name}.`,
      session: newRecord,
      validation,
    });
  } catch (err) {
    console.error('[Clock In Error]:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to record clock-in. Please retry.',
    });
  }
}

/**
 * Requests a short-lived single-use clock-out challenge.
 * Checks that the user has an open session and enrolled face.
 */
async function requestClockOutChallenge(req, res) {
  try {
    const employeeId = req.user.employeeId;

    const employee = await sheetsService.getEmployeeById(employeeId);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    // Check open session
    const openSession = await sheetsService.getOpenSession(employeeId);
    if (!openSession) {
      return res.status(400).json({
        success: false,
        errorCode: 'NO_OPEN_SESSION',
        message: 'No active attendance session found to clock out from.',
      });
    }

    // Check face enrolment
    if (String(employee.FaceEnrolled).toUpperCase() !== 'TRUE') {
      return res.status(403).json({
        success: false,
        errorCode: 'FACE_NOT_ENROLLED',
        message: 'Your face biometric profile is not enrolled yet. Please complete face enrolment with HR approval before clocking out.',
      });
    }

    const challenge = biometricService.createClockOutChallenge(employeeId);

    return res.json({
      success: true,
      message: 'Clock-out verification challenge generated.',
      challenge,
    });
  } catch (err) {
    console.error('[ClockOut Challenge Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed generating clock-out challenge.' });
  }
}

/**
 * Clocks Out an employee.
 * Requires:
 * - Valid single-use challenge token and liveness action
 * - Face probe verification against enrolled template
 * - Revalidated GPS location within office radius
 * - Links to open session (supporting overnight shifts)
 */
async function clockOut(req, res) {
  try {
    const {
      challengeId,
      probeVector,
      completedLivenessAction,
      latitude,
      longitude,
      accuracy,
      timestamp,
      isMockLocation,
      notes,
    } = req.body;
    const employeeId = req.user.employeeId;

    // 1. Fetch Open Session
    const openSession = await sheetsService.getOpenSession(employeeId);
    if (!openSession) {
      return res.status(400).json({
        success: false,
        errorCode: 'NO_OPEN_SESSION',
        message: 'No active attendance session found to clock out from.',
      });
    }

    // 2. Validate and Burn Single-Use Challenge Token
    const challengeValidation = biometricService.validateAndBurnChallenge(challengeId, employeeId);
    if (!challengeValidation.isValid) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_OR_EXPIRED_CHALLENGE',
        message: `Face verification challenge is invalid or has expired (${challengeValidation.reason}). Please generate a fresh challenge.`,
      });
    }

    const challenge = challengeValidation.challenge;

    // 3. Verify Biometric Face Probe
    const faceResult = biometricService.verifyFace({
      employeeId,
      probeVector,
      completedLivenessAction,
      expectedLivenessAction: challenge.livenessAction,
    });

    if (!faceResult.isVerified) {
      return res.status(401).json({
        success: false,
        errorCode: faceResult.reason,
        message: faceResult.message,
        confidence: faceResult.confidence,
      });
    }

    // 4. Re-validate GPS Geofence at Clock-Out
    const office = await sheetsService.getOfficeById(openSession.OfficeID);
    if (!office) {
      return res.status(400).json({ success: false, message: 'Office configuration missing.' });
    }

    const locValidation = validateLocation({
      clientLat: Number(latitude),
      clientLng: Number(longitude),
      clientAccuracy: Number(accuracy),
      clientTimestamp: timestamp,
      isMockLocation: Boolean(isMockLocation),
      office: {
        latitude: Number(office.Latitude),
        longitude: Number(office.Longitude),
        radiusMeters: Number(office.RadiusMeters),
        maxAccuracyMeters: Number(office.MaxAccuracyMeters),
        maxAgeSeconds: Number(office.MaxAgeSeconds),
        name: office.Name,
      },
    });

    if (!locValidation.isValid) {
      return res.status(400).json({
        success: false,
        errorCode: locValidation.errorCode,
        message: locValidation.errorMessage,
        details: {
          distanceMeters: locValidation.distanceMeters,
          radiusMeters: locValidation.radiusMeters,
        },
      });
    }

    // 5. Calculate Worked Duration
    const clockOutUTC = getNowUTC();
    const klTime = formatKualaLumpurTime(clockOutUTC);
    const duration = calculateWorkedDuration(openSession.ClockInTimeUTC, clockOutUTC);

    // 6. Update Open Session in Sheets DB
    const updates = {
      ClockOutTimeUTC: clockOutUTC,
      ClockOutTimeKL: `${klTime.dateKL} ${klTime.timeKL}`,
      ClockOutLat: latitude,
      ClockOutLng: longitude,
      ClockOutAccuracy: accuracy,
      ClockOutDistanceMeters: locValidation.distanceMeters,
      FaceVerified: 'YES',
      FaceVerificationConfidence: `${(faceResult.confidence * 100).toFixed(1)}%`,
      WorkedMinutes: duration.workedMinutes,
      WorkedHours: duration.workedHours,
      AttendanceStatus: 'COMPLETED',
      ExceptionNotes: notes ? `${openSession.ExceptionNotes || ''} | ${notes}` : openSession.ExceptionNotes,
      LastModifiedBy: employeeId,
      LastModifiedAt: clockOutUTC,
    };

    const completedRecord = await sheetsService.updateAttendanceSession(openSession.SessionID, updates);

    // 7. Record Audit Log
    await sheetsService.recordAuditLog({
      actorId: employeeId,
      actorName: openSession.EmployeeName,
      action: 'CLOCK_OUT_FACE_VERIFIED',
      affectedRecordType: 'Attendance',
      affectedRecordId: openSession.SessionID,
      timestampUTC: clockOutUTC,
      timestampKL: klTime.displayKL,
      reason: 'Clock-out with biometric face verification and geofence check.',
      beforeValues: { Status: openSession.AttendanceStatus, ClockIn: openSession.ClockInTimeKL },
      afterValues: updates,
    });

    return res.json({
      success: true,
      message: `Clock-out completed successfully! Total worked: ${duration.workedHours} hrs (${duration.workedMinutes} mins).`,
      session: completedRecord,
      duration,
    });
  } catch (err) {
    console.error('[Clock Out Error]:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to process clock-out. Please retry.',
    });
  }
}

/**
 * Retrieves attendance records for the logged-in employee.
 */
async function getMyHistory(req, res) {
  try {
    const employeeId = req.user.employeeId;
    const { startDate, endDate, status } = req.query;

    const records = await sheetsService.getAttendanceRecords({
      employeeId,
      startDate,
      endDate,
      status,
    });

    return res.json({
      success: true,
      records,
      count: records.length,
    });
  } catch (err) {
    console.error('[My History Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed fetching attendance history.' });
  }
}

module.exports = {
  getDashboardStatus,
  clockIn,
  requestClockOutChallenge,
  clockOut,
  getMyHistory,
};
