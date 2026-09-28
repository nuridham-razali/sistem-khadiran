const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'geoattend_jwt_secure_key_change_in_production_2026';

/**
 * Validates JWT Bearer Token in Authorization Header
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      errorCode: 'AUTH_TOKEN_MISSING',
      message: 'Authentication token required.',
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        errorCode: 'AUTH_TOKEN_INVALID',
        message: 'Invalid or expired session token.',
      });
    }
    req.user = user;
    next();
  });
}

/**
 * Enforces Administrator role
 */
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({
      success: false,
      errorCode: 'FORBIDDEN_ADMIN_ONLY',
      message: 'Access denied. Administrator privileges required.',
    });
  }
  next();
}

/**
 * Enforces that an employee can only query or modify their own data, unless they are an admin.
 * @param {string} paramKey Request parameter or body key containing employeeId (default: 'employeeId')
 */
function requireSelfOrAdmin(paramKey = 'employeeId') {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Unauthenticated.' });
    }

    if (req.user.role === 'admin') {
      return next();
    }

    const requestedEmployeeId =
      req.params[paramKey] || req.body[paramKey] || req.query[paramKey];

    if (
      !requestedEmployeeId ||
      String(req.user.employeeId).toLowerCase() !== String(requestedEmployeeId).toLowerCase()
    ) {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN_RESOURCE_ACCESS',
        message: 'Access denied. You may only view or update your own attendance records.',
      });
    }

    next();
  };
}

module.exports = {
  authenticateToken,
  requireAdmin,
  requireSelfOrAdmin,
};
