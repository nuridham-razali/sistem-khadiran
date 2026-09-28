const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { authenticateToken } = require('../middleware/auth');
const idempotencyMiddleware = require('../middleware/idempotency');

router.use(authenticateToken);

// Employee Dashboard & Status
router.get('/status', attendanceController.getDashboardStatus);

// Clock In (with idempotency to prevent double-submit on network retry)
router.post('/clock-in', idempotencyMiddleware, attendanceController.clockIn);

// Clock Out Challenge generation (120s TTL nonce)
router.post('/clock-out-challenge', attendanceController.requestClockOutChallenge);

// Clock Out (verified with face biometric probe, liveness action, and geofence)
router.post('/clock-out', idempotencyMiddleware, attendanceController.clockOut);

// Employee own attendance history
router.get('/my-history', attendanceController.getMyHistory);

module.exports = router;
