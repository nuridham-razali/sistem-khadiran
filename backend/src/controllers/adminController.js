const { stringify } = require('csv-stringify');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const sheetsService = require('../services/sheetsService');
const { getNowUTC, formatKualaLumpurTime } = require('../utils/timeUtils');

/**
 * Overview statistics for Admin Dashboard
 */
async function getDashboardMetrics(req, res) {
  try {
    const employees = await sheetsService.getEmployees();
    const offices = await sheetsService.getOffices();
    const records = await sheetsService.getAttendanceRecords();

    const nowUtc = getNowUTC();
    const klTime = formatKualaLumpurTime(nowUtc);

    const todayRecords = records.filter((r) => r.WorkDate === klTime.dateKL);
    const activeSessions = records.filter((r) => r.AttendanceStatus === 'IN_PROGRESS');
    const exceptions = records.filter(
      (r) =>
        r.AttendanceStatus.startsWith('EXCEPTION_') ||
        (r.ExceptionNotes && r.ExceptionNotes.trim().length > 0)
    );

    return res.json({
      success: true,
      currentKLTime: klTime,
      metrics: {
        totalEmployees: employees.length,
        activeEmployees: employees.filter((e) => String(e.Active).toUpperCase() === 'TRUE').length,
        totalOffices: offices.length,
        activeSessionsNow: activeSessions.length,
        todayTotalClockIns: todayRecords.length,
        todayCompletedSessions: todayRecords.filter((r) => r.AttendanceStatus === 'COMPLETED').length,
        flaggedExceptions: exceptions.length,
      },
    });
  } catch (err) {
    console.error('[Admin Metrics Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed fetching admin metrics.' });
  }
}

/**
 * Filter & search attendance records across all employees
 */
async function getAllAttendance(req, res) {
  try {
    const { employeeId, department, officeId, startDate, endDate, status, search } = req.query;

    let records = await sheetsService.getAttendanceRecords({
      employeeId,
      department,
      officeId,
      startDate,
      endDate,
      status,
    });

    if (search) {
      const q = search.toLowerCase();
      records = records.filter(
        (r) =>
          r.EmployeeName?.toLowerCase().includes(q) ||
          r.EmployeeID?.toLowerCase().includes(q) ||
          r.Department?.toLowerCase().includes(q)
      );
    }

    return res.json({
      success: true,
      records,
      totalCount: records.length,
    });
  } catch (err) {
    console.error('[Admin Get Attendance Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed fetching attendance records.' });
  }
}

/**
 * Admin manual correction of an attendance record.
 * MANDATORY: Requires a reason, and writes before/after state to AuditLog.
 */
async function correctAttendance(req, res) {
  try {
    const { sessionId } = req.params;
    const {
      clockInTimeKL,
      clockOutTimeKL,
      attendanceStatus,
      workedMinutes,
      reason,
      exceptionNotes,
    } = req.body;

    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({
        success: false,
        errorCode: 'REASON_REQUIRED',
        message: 'A mandatory justification reason (min 5 characters) is required for manual attendance corrections.',
      });
    }

    const currentRecord = await sheetsService.getAttendanceById(sessionId);
    if (!currentRecord) {
      return res.status(404).json({ success: false, message: 'Attendance session not found.' });
    }

    const beforeValues = {
      ClockInTimeKL: currentRecord.ClockInTimeKL,
      ClockOutTimeKL: currentRecord.ClockOutTimeKL,
      AttendanceStatus: currentRecord.AttendanceStatus,
      WorkedMinutes: currentRecord.WorkedMinutes,
      WorkedHours: currentRecord.WorkedHours,
      ExceptionNotes: currentRecord.ExceptionNotes,
    };

    const calculatedHours = workedMinutes
      ? Math.round((Number(workedMinutes) / 60) * 100) / 100
      : currentRecord.WorkedHours;

    const updates = {
      ClockInTimeKL: clockInTimeKL !== undefined ? clockInTimeKL : currentRecord.ClockInTimeKL,
      ClockOutTimeKL: clockOutTimeKL !== undefined ? clockOutTimeKL : currentRecord.ClockOutTimeKL,
      AttendanceStatus: attendanceStatus || 'CORRECTED',
      WorkedMinutes: workedMinutes !== undefined ? workedMinutes : currentRecord.WorkedMinutes,
      WorkedHours: calculatedHours,
      ExceptionNotes: `[Admin Correction: ${reason}] ${exceptionNotes || currentRecord.ExceptionNotes || ''}`.trim(),
      LastModifiedBy: `Admin:${req.user.employeeId}`,
      LastModifiedAt: getNowUTC(),
    };

    const updatedRecord = await sheetsService.updateAttendanceSession(sessionId, updates);

    const nowUtc = getNowUTC();
    const klTime = formatKualaLumpurTime(nowUtc);

    // Audit Log entry
    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'CORRECT_ATTENDANCE_RECORD',
      affectedRecordType: 'Attendance',
      affectedRecordId: sessionId,
      timestampUTC: nowUtc,
      timestampKL: klTime.displayKL,
      reason,
      beforeValues,
      afterValues: updates,
    });

    return res.json({
      success: true,
      message: 'Attendance record corrected successfully. Audit log created.',
      record: updatedRecord,
    });
  } catch (err) {
    console.error('[Correct Attendance Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed correcting attendance record.' });
  }
}

/**
 * Preview Payroll Export Data
 */
async function getPayrollPreview(req, res) {
  try {
    const { startDate, endDate, officeId, department } = req.query;

    const records = await sheetsService.getAttendanceRecords({
      startDate,
      endDate,
      officeId,
      department,
    });

    // Mark incomplete records
    const processed = records.map((r) => {
      const isIncomplete =
        r.AttendanceStatus === 'IN_PROGRESS' ||
        !r.ClockOutTimeKL ||
        r.AttendanceStatus.startsWith('EXCEPTION_');

      return {
        ...r,
        isIncomplete,
        flag: isIncomplete ? 'FLAGGED_REVIEW' : 'VERIFIED',
      };
    });

    return res.json({
      success: true,
      payrollPeriod: { startDate, endDate },
      totalSessions: processed.length,
      incompleteCount: processed.filter((p) => p.isIncomplete).length,
      records: processed,
    });
  } catch (err) {
    console.error('[Payroll Preview Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed generating payroll preview.' });
  }
}

/**
 * Stream Payroll Export CSV with configurable column mapping & headers
 */
async function exportPayrollCsv(req, res) {
  try {
    const { startDate, endDate, officeId, department, columns } = req.query;

    const records = await sheetsService.getAttendanceRecords({
      startDate,
      endDate,
      officeId,
      department,
    });

    // Default payroll columns matching requirement
    const defaultColumnConfig = [
      { key: 'EmployeeID', label: 'EmployeeID' },
      { key: 'EmployeeName', label: 'EmployeeName' },
      { key: 'Department', label: 'Department' },
      { key: 'WorkDate', label: 'WorkDate' },
      { key: 'ClockInTimeKL', label: 'ClockIn' },
      { key: 'ClockOutTimeKL', label: 'ClockOut' },
      { key: 'WorkedMinutes', label: 'WorkedMinutes' },
      { key: 'WorkedHours', label: 'WorkedHours' },
      { key: 'AttendanceStatus', label: 'AttendanceStatus' },
      { key: 'ExceptionNotes', label: 'ExceptionNotes' },
    ];

    let activeCols = defaultColumnConfig;
    if (columns) {
      try {
        const requestedKeys = columns.split(',');
        activeCols = requestedKeys
          .map((k) => defaultColumnConfig.find((c) => c.key === k || c.label === k))
          .filter(Boolean);
      } catch (e) {
        // fallback to default
      }
    }

    const rows = records.map((r) => {
      const row = {};
      activeCols.forEach((col) => {
        let val = r[col.key] ?? '';
        if (col.key === 'ClockOutTimeKL' && !val && r.AttendanceStatus === 'IN_PROGRESS') {
          val = 'OPEN_SESSION_MISSING_CLOCK_OUT';
        }
        row[col.label] = val;
      });
      return row;
    });

    const filename = `payroll_export_${startDate || 'all'}_to_${endDate || 'latest'}.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    const stringifier = stringify({ header: true, columns: activeCols.map((c) => c.label) });
    stringifier.pipe(res);

    rows.forEach((r) => stringifier.write(r));
    stringifier.end();

    // Log the export action
    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'EXPORT_PAYROLL_CSV',
      affectedRecordType: 'PayrollExport',
      affectedRecordId: filename,
      timestampUTC: getNowUTC(),
      timestampKL: formatKualaLumpurTime().displayKL,
      reason: `Admin CSV payroll download for period ${startDate} - ${endDate}`,
      afterValues: { recordCount: rows.length, filename },
    });
  } catch (err) {
    console.error('[Export Payroll Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed exporting CSV.' });
  }
}

// ==========================================
// OFFICE MANAGEMENT
// ==========================================

async function getOffices(req, res) {
  try {
    const offices = await sheetsService.getOffices();
    return res.json({ success: true, offices });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed fetching offices.' });
  }
}

async function createOffice(req, res) {
  try {
    const { name, latitude, longitude, radiusMeters, maxAccuracyMeters, maxAgeSeconds, address } = req.body;

    if (!name || latitude === undefined || longitude === undefined || !radiusMeters) {
      return res.status(400).json({
        success: false,
        message: 'Office name, latitude, longitude, and radius in metres are required.',
      });
    }

    const officeId = `OFF-${uuidv4().substring(0, 8).toUpperCase()}`;

    const newOffice = {
      OfficeID: officeId,
      Name: name,
      Latitude: Number(latitude),
      Longitude: Number(longitude),
      RadiusMeters: Number(radiusMeters),
      MaxAccuracyMeters: maxAccuracyMeters ? Number(maxAccuracyMeters) : 50,
      MaxAgeSeconds: maxAgeSeconds ? Number(maxAgeSeconds) : 60,
      Address: address || '',
      Active: 'TRUE',
    };

    await sheetsService.saveOffice(newOffice);

    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'CREATE_OFFICE',
      affectedRecordType: 'Offices',
      affectedRecordId: officeId,
      timestampUTC: getNowUTC(),
      timestampKL: formatKualaLumpurTime().displayKL,
      reason: `Created office location ${name}`,
      afterValues: newOffice,
    });

    return res.status(201).json({ success: true, office: newOffice });
  } catch (err) {
    console.error('[Create Office Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed creating office.' });
  }
}

async function updateOffice(req, res) {
  try {
    const { officeId } = req.params;
    const current = await sheetsService.getOfficeById(officeId);
    if (!current) {
      return res.status(404).json({ success: false, message: 'Office not found.' });
    }

    const updates = {};
    const allowed = ['Name', 'Latitude', 'Longitude', 'RadiusMeters', 'MaxAccuracyMeters', 'MaxAgeSeconds', 'Address', 'Active'];
    for (const key of allowed) {
      const lower = key.charAt(0).toLowerCase() + key.slice(1);
      if (req.body[lower] !== undefined) updates[key] = req.body[lower];
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const updated = await sheetsService.updateOffice(officeId, updates);

    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'UPDATE_OFFICE',
      affectedRecordType: 'Offices',
      affectedRecordId: officeId,
      timestampUTC: getNowUTC(),
      timestampKL: formatKualaLumpurTime().displayKL,
      reason: `Updated office parameters for ${officeId}`,
      beforeValues: current,
      afterValues: updated,
    });

    return res.json({ success: true, office: updated });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed updating office.' });
  }
}

// ==========================================
// EMPLOYEE MANAGEMENT
// ==========================================

async function getEmployees(req, res) {
  try {
    const employees = await sheetsService.getEmployees();
    // Strip password hashes from response
    const sanitized = employees.map(({ PasswordHash, ...rest }) => rest);
    return res.json({ success: true, employees: sanitized });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed fetching employees.' });
  }
}

async function createEmployee(req, res) {
  try {
    const { employeeId, name, email, department, assignedOfficeId, role, password } = req.body;

    if (!employeeId || !name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Employee ID, name, email, and initial password are required.',
      });
    }

    const existing = await sheetsService.getEmployeeById(employeeId);
    if (existing) {
      return res.status(409).json({ success: false, message: `Employee ID ${employeeId} already exists.` });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const newEmp = {
      EmployeeID: employeeId.toUpperCase(),
      Name: name,
      Email: email.toLowerCase(),
      Department: department || 'General',
      AssignedOfficeID: assignedOfficeId || '',
      Role: role || 'employee',
      Active: 'TRUE',
      PasswordHash: passwordHash,
      FaceEnrolled: 'FALSE',
      FaceEnrolledAt: '',
      CreatedAt: getNowUTC(),
    };

    await sheetsService.saveEmployee(newEmp);

    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'CREATE_EMPLOYEE',
      affectedRecordType: 'Employees',
      affectedRecordId: newEmp.EmployeeID,
      timestampUTC: getNowUTC(),
      timestampKL: formatKualaLumpurTime().displayKL,
      reason: `Added new employee ${name} (${employeeId})`,
      afterValues: { EmployeeID: newEmp.EmployeeID, Name: name, Department: department },
    });

    const { PasswordHash, ...sanitized } = newEmp;
    return res.status(201).json({ success: true, employee: sanitized });
  } catch (err) {
    console.error('[Create Employee Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed creating employee.' });
  }
}

async function updateEmployee(req, res) {
  try {
    const { employeeId } = req.params;
    const current = await sheetsService.getEmployeeById(employeeId);
    if (!current) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    const updates = {};
    if (req.body.name) updates.Name = req.body.name;
    if (req.body.department) updates.Department = req.body.department;
    if (req.body.assignedOfficeId !== undefined) updates.AssignedOfficeID = req.body.assignedOfficeId;
    if (req.body.active !== undefined) updates.Active = String(req.body.active).toUpperCase();
    if (req.body.role) updates.Role = req.body.role;
    if (req.body.password) {
      updates.PasswordHash = await bcrypt.hash(req.body.password, 10);
    }

    const updated = await sheetsService.updateEmployee(employeeId, updates);

    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'UPDATE_EMPLOYEE',
      affectedRecordType: 'Employees',
      affectedRecordId: employeeId,
      timestampUTC: getNowUTC(),
      timestampKL: formatKualaLumpurTime().displayKL,
      reason: `Admin updated employee profile ${employeeId}`,
      beforeValues: { Name: current.Name, Department: current.Department, AssignedOfficeID: current.AssignedOfficeID, Active: current.Active },
      afterValues: { Name: updated.Name, Department: updated.Department, AssignedOfficeID: updated.AssignedOfficeID, Active: updated.Active },
    });

    const { PasswordHash, ...sanitized } = updated;
    return res.json({ success: true, employee: sanitized });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed updating employee.' });
  }
}

async function getAuditLogs(req, res) {
  try {
    const limit = parseInt(req.query.limit || '100', 10);
    const logs = await sheetsService.getAuditLogs(limit);
    return res.json({ success: true, logs });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed fetching audit logs.' });
  }
}

module.exports = {
  getDashboardMetrics,
  getAllAttendance,
  correctAttendance,
  getPayrollPreview,
  exportPayrollCsv,
  getOffices,
  createOffice,
  updateOffice,
  getEmployees,
  createEmployee,
  updateEmployee,
  getAuditLogs,
};
