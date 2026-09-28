const biometricService = require('../services/biometricService');
const sheetsService = require('../services/sheetsService');
const { getNowUTC, formatKualaLumpurTime } = require('../utils/timeUtils');

/**
 * Enrolls an employee's face feature template.
 * Requires:
 * - faceVector (array of normalized floats)
 * - consentText (affirmative consent)
 */
async function enrollFace(req, res) {
  try {
    const targetEmployeeId = req.params.employeeId || req.user.employeeId;

    // RBAC: Can only enroll own face unless admin
    if (req.user.role !== 'admin' && String(req.user.employeeId).toLowerCase() !== String(targetEmployeeId).toLowerCase()) {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN',
        message: 'You can only enroll your own biometric profile.',
      });
    }

    const { faceVector, consentText } = req.body;

    if (!faceVector || !Array.isArray(faceVector) || faceVector.length < 16) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_BIOMETRIC_DATA',
        message: 'A valid face feature vector embedding (min 16 dimensions) is required for biometric matching.',
      });
    }

    if (!consentText || consentText.trim().length < 10) {
      return res.status(400).json({
        success: false,
        errorCode: 'CONSENT_REQUIRED',
        message: 'Explicit signed biometric consent is required before saving facial templates.',
      });
    }

    const employee = await sheetsService.getEmployeeById(targetEmployeeId);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    // Save template to isolated protected storage (never in Google Sheets)
    const result = await biometricService.enrollFaceTemplate({
      employeeId: employee.EmployeeID,
      faceVector,
      consentText,
      enrolledBy: req.user.employeeId,
    });

    const nowUtc = getNowUTC();
    const klTime = formatKualaLumpurTime(nowUtc);

    // Update FaceEnrolled flag in Sheets DB
    await sheetsService.updateEmployee(employee.EmployeeID, {
      FaceEnrolled: 'TRUE',
      FaceEnrolledAt: nowUtc,
    });

    // Record Audit Log
    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'ENROLL_FACE_BIOMETRIC',
      affectedRecordType: 'BiometricProfile',
      affectedRecordId: employee.EmployeeID,
      timestampUTC: nowUtc,
      timestampKL: klTime.displayKL,
      reason: 'Biometric face enrollment completed with signed employee consent.',
      afterValues: { checksum: result.checksum, dimensions: faceVector.length },
    });

    return res.status(201).json({
      success: true,
      message: 'Face biometric template enrolled and saved securely.',
      enrolledAt: result.enrolledAt,
      checksum: result.checksum,
    });
  } catch (err) {
    console.error('[Enroll Face Error]:', err);
    return res.status(500).json({ success: false, message: err.message || 'Failed enrolling face.' });
  }
}

/**
 * Gets face enrolment status
 */
async function getBiometricStatus(req, res) {
  try {
    const targetEmployeeId = req.params.employeeId || req.user.employeeId;
    const template = biometricService.getEnrolledTemplate(targetEmployeeId);

    return res.json({
      success: true,
      employeeId: targetEmployeeId,
      isEnrolled: !!template,
      enrolledAt: template ? template.enrolledAt : null,
      algorithm: template ? template.algorithm : null,
      dimensions: template ? template.dimensions : null,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed fetching biometric status.' });
  }
}

/**
 * Revokes and deletes biometric data (GDPR right to erasure)
 */
async function deleteBiometricData(req, res) {
  try {
    const targetEmployeeId = req.params.employeeId || req.user.employeeId;

    if (req.user.role !== 'admin' && String(req.user.employeeId).toLowerCase() !== String(targetEmployeeId).toLowerCase()) {
      return res.status(403).json({ success: false, message: 'Forbidden.' });
    }

    const result = biometricService.deleteBiometricData(targetEmployeeId);

    await sheetsService.updateEmployee(targetEmployeeId, {
      FaceEnrolled: 'FALSE',
      FaceEnrolledAt: '',
    });

    const nowUtc = getNowUTC();
    await sheetsService.recordAuditLog({
      actorId: req.user.employeeId,
      actorName: req.user.name,
      action: 'DELETE_BIOMETRIC_DATA',
      affectedRecordType: 'BiometricProfile',
      affectedRecordId: targetEmployeeId,
      timestampUTC: nowUtc,
      timestampKL: formatKualaLumpurTime(nowUtc).displayKL,
      reason: 'Biometric profile deletion requested and purged from secure storage.',
    });

    return res.json({
      success: true,
      message: 'Biometric template and consent successfully deleted.',
      result,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed deleting biometric data.' });
  }
}

module.exports = {
  enrollFace,
  getBiometricStatus,
  deleteBiometricData,
};
