const express = require('express');
const router = express.Router();
const faceController = require('../controllers/faceController');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// Face Enrolment (self or admin)
router.post('/enroll/:employeeId?', faceController.enrollFace);
router.get('/status/:employeeId?', faceController.getBiometricStatus);
router.delete('/enroll/:employeeId?', faceController.deleteBiometricData);

module.exports = router;
