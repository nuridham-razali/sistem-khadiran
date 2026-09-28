const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

router.use(authenticateToken);
router.use(requireAdmin);

// Dashboard metrics
router.get('/metrics', adminController.getDashboardMetrics);

// Attendance query & filters
router.get('/attendance', adminController.getAllAttendance);

// Attendance manual correction with mandatory reason
router.put('/attendance/:sessionId/correct', adminController.correctAttendance);

// Payroll export
router.get('/payroll/preview', adminController.getPayrollPreview);
router.get('/payroll/export.csv', adminController.exportPayrollCsv);

// Office management
router.get('/offices', adminController.getOffices);
router.post('/offices', adminController.createOffice);
router.put('/offices/:officeId', adminController.updateOffice);

// Employee management
router.get('/employees', adminController.getEmployees);
router.post('/employees', adminController.createEmployee);
router.put('/employees/:employeeId', adminController.updateEmployee);

// Audit logs
router.get('/audit-logs', adminController.getAuditLogs);

module.exports = router;
