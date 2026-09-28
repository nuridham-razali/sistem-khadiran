const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const sheetsService = require('../services/sheetsService');

const JWT_SECRET = process.env.JWT_SECRET || 'geoattend_jwt_secure_key_change_in_production_2026';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

async function login(req, res) {
  try {
    const { identifier, password } = req.body; // identifier can be EmployeeID or Email

    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Employee ID/Email and password are required.',
      });
    }

    // Lookup employee in Sheets DB
    const employees = await sheetsService.getEmployees();
    const employee = employees.find(
      (e) =>
        String(e.EmployeeID).toLowerCase() === String(identifier).toLowerCase() ||
        String(e.Email).toLowerCase() === String(identifier).toLowerCase()
    );

    if (!employee) {
      return res.status(401).json({
        success: false,
        errorCode: 'INVALID_CREDENTIALS',
        message: 'Invalid Employee ID/Email or password.',
      });
    }

    if (String(employee.Active).toUpperCase() === 'FALSE') {
      return res.status(403).json({
        success: false,
        errorCode: 'ACCOUNT_DEACTIVATED',
        message: 'Your employee account has been deactivated. Contact HR.',
      });
    }

    // Verify Password
    const passwordMatch = await bcrypt.compare(password, employee.PasswordHash);
    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        errorCode: 'INVALID_CREDENTIALS',
        message: 'Invalid Employee ID/Email or password.',
      });
    }

    // Load assigned office details
    const office = employee.AssignedOfficeID
      ? await sheetsService.getOfficeById(employee.AssignedOfficeID)
      : null;

    // Create JWT
    const payload = {
      id: employee.EmployeeID,
      employeeId: employee.EmployeeID,
      name: employee.Name,
      email: employee.Email,
      role: employee.Role || 'employee',
      department: employee.Department,
      officeId: employee.AssignedOfficeID,
    };

    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    return res.json({
      success: true,
      message: 'Login successful.',
      token,
      user: {
        employeeId: employee.EmployeeID,
        name: employee.Name,
        email: employee.Email,
        department: employee.Department,
        role: employee.Role,
        faceEnrolled: String(employee.FaceEnrolled).toUpperCase() === 'TRUE',
        faceEnrolledAt: employee.FaceEnrolledAt || null,
        assignedOffice: office,
      },
    });
  } catch (err) {
    console.error('[Auth Login Error]:', err);
    return res.status(500).json({
      success: false,
      message: 'Internal server error during authentication.',
    });
  }
}

async function getProfile(req, res) {
  try {
    const employee = await sheetsService.getEmployeeById(req.user.employeeId);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee profile not found.' });
    }

    const office = employee.AssignedOfficeID
      ? await sheetsService.getOfficeById(employee.AssignedOfficeID)
      : null;

    return res.json({
      success: true,
      user: {
        employeeId: employee.EmployeeID,
        name: employee.Name,
        email: employee.Email,
        department: employee.Department,
        role: employee.Role,
        active: String(employee.Active).toUpperCase() === 'TRUE',
        faceEnrolled: String(employee.FaceEnrolled).toUpperCase() === 'TRUE',
        faceEnrolledAt: employee.FaceEnrolledAt,
        assignedOffice: office,
      },
    });
  } catch (err) {
    console.error('[Get Profile Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed retrieving profile.' });
  }
}

module.exports = {
  login,
  getProfile,
};
