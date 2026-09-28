const request = require('supertest');
const app = require('../src/app');
const sheetsService = require('../src/services/sheetsService');
const seed = require('../src/scripts/seedData');
const biometricService = require('../src/services/biometricService');

let adminToken;
let employeeToken; // Alex Tan (Enrolled)
let unenrolledEmployeeToken; // Siti Aminah (Unenrolled)

beforeAll(async () => {
  // Seed fresh database state
  await seed();

  // Login Admin
  const adminRes = await request(app)
    .post('/api/auth/login')
    .send({ identifier: 'admin@halagel.com', password: 'AdminPassword123!' });
  adminToken = adminRes.body.token;

  // Login Employee Renaldottt
  const empRes = await request(app)
    .post('/api/auth/login')
    .send({ identifier: 'renaldi@example.com', password: 'Password123!' });
  employeeToken = empRes.body.token;

  // Login Unenrolled Employee Nurul Huda
  const unenrolledRes = await request(app)
    .post('/api/auth/login')
    .send({ identifier: 'nurul@halagel.com', password: 'Password123!' });
  unenrolledEmployeeToken = unenrolledRes.body.token;
});

describe('1. Geofence Radius Boundaries and Location Validation', () => {
  test('Rejects clock-in when location is OUTSIDE office radius', async () => {
    // KL HQ is at 3.1478, 101.6953. This location is ~15 km away in Petaling Jaya
    const res = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        latitude: 3.1073,
        longitude: 101.5951,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.errorCode).toBe('OUTSIDE_RADIUS');
    expect(res.body.details.distanceMeters).toBeGreaterThan(150);
  });

  test('Accepts clock-in when location is strictly INSIDE office radius', async () => {
    // 10 meters from KL HQ
    const res = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 8,
        timestamp: Date.now(),
        notes: 'Arrived at reception lobby',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.session.AttendanceStatus).toBe('IN_PROGRESS');
    expect(res.body.session.EmployeeID).toBe('EMP101');
  });

  test('Rejects clock-in with STALE GPS reading (> 60s old)', async () => {
    // Clock in using another employee or fresh session
    const staleTime = Date.now() - 120 * 1000; // 2 minutes old

    const res = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${unenrolledEmployeeToken}`)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: staleTime,
      });

    expect(res.status).toBe(400);
    expect(res.body.errorCode).toBe('STALE_GPS_READING');
  });

  test('Rejects clock-in with INACCURATE GPS reading (> 50m accuracy)', async () => {
    const res = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${unenrolledEmployeeToken}`)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 120, // 120 metres is too inaccurate
        timestamp: Date.now(),
      });

    expect(res.status).toBe(400);
    expect(res.body.errorCode).toBe('INACCURATE_GPS');
  });
});

describe('2. Duplicate Submissions & Idempotent Retries', () => {
  test('Prevents duplicate clock-ins while session is already open', async () => {
    // Alex Tan is already clocked in
    const res = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res.status).toBe(400);
    expect(res.body.errorCode).toBe('SESSION_ALREADY_OPEN');
  });

  test('Idempotent retry with same X-Idempotency-Key returns cached response without duplicate creation', async () => {
    const idempotencyKey = 'retry-test-uuid-999';

    // First attempt for Siti Aminah
    const res1 = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${unenrolledEmployeeToken}`)
      .set('X-Idempotency-Key', idempotencyKey)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res1.status).toBe(201);
    const originalSessionId = res1.body.session.SessionID;

    // Retry request with same key
    const res2 = await request(app)
      .post('/api/attendance/clock-in')
      .set('Authorization', `Bearer ${unenrolledEmployeeToken}`)
      .set('X-Idempotency-Key', idempotencyKey)
      .send({
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res2.status).toBe(201);
    expect(res2.body.session.SessionID).toBe(originalSessionId);
    expect(res2.headers['x-cache-lookup']).toBe('HIT');
  });
});

describe('3. Biometric Face Verification & Clock-Out Security', () => {
  let validChallenge;

  test('Rejects clock-out challenge request if user face is not enrolled', async () => {
    // Siti Aminah has not enrolled her face
    const res = await request(app)
      .post('/api/attendance/clock-out-challenge')
      .set('Authorization', `Bearer ${unenrolledEmployeeToken}`);

    expect(res.status).toBe(403);
    expect(res.body.errorCode).toBe('FACE_NOT_ENROLLED');
  });

  test('Issues single-use challenge token for enrolled employee', async () => {
    const res = await request(app)
      .post('/api/attendance/clock-out-challenge')
      .set('Authorization', `Bearer ${employeeToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.challenge.challengeId).toBeDefined();
    expect(res.body.challenge.livenessAction).toBeDefined();
    validChallenge = res.body.challenge;
  });

  test('Rejects clock-out if probe face vector does NOT match enrolled template', async () => {
    // Generate random mismatched face vector
    const mismatchedVector = Array.from({ length: 128 }, () => Math.random());

    const res = await request(app)
      .post('/api/attendance/clock-out')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        challengeId: validChallenge.challengeId,
        probeVector: mismatchedVector,
        completedLivenessAction: validChallenge.livenessAction,
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res.status).toBe(401);
    expect(res.body.errorCode).toBe('FACE_MISMATCH');
  });

  test('Rejects replayed or expired verification challenge', async () => {
    // Challenge was already burned in the previous attempt
    const res = await request(app)
      .post('/api/attendance/clock-out')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        challengeId: validChallenge.challengeId,
        probeVector: Array.from({ length: 128 }, () => 0.5),
        completedLivenessAction: validChallenge.livenessAction,
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res.status).toBe(400);
    expect(res.body.errorCode).toBe('INVALID_OR_EXPIRED_CHALLENGE');
  });

  test('Successfully clocks out when face match, liveness, and location all pass', async () => {
    // 1. Get new challenge
    const chalRes = await request(app)
      .post('/api/attendance/clock-out-challenge')
      .set('Authorization', `Bearer ${employeeToken}`);
    const freshChallenge = chalRes.body.challenge;

    // 2. Fetch enrolled template vector for Alex Tan
    const template = biometricService.getEnrolledTemplate('EMP101');
    expect(template).not.toBeNull();

    // 3. Submit probe vector matching enrolled face
    const res = await request(app)
      .post('/api/attendance/clock-out')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        challengeId: freshChallenge.challengeId,
        probeVector: template.embedding,
        completedLivenessAction: freshChallenge.livenessAction,
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
        notes: 'Heading home',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.session.AttendanceStatus).toBe('COMPLETED');
    expect(res.body.session.FaceVerified).toBe('YES');
    expect(res.body.duration.workedMinutes).toBeDefined();
  });
});

describe('4. Overnight Shift Support & Session Linking', () => {
  test('Clock-out successfully links to open session started on previous calendar date', async () => {
    // Manually create an overnight session started yesterday
    const yesterdayUtc = new Date(Date.now() - 12 * 3600 * 1000).toISOString();
    const sessionId = 'SES-OVERNIGHT-999';

    await sheetsService.saveAttendanceSession({
      SessionID: sessionId,
      EmployeeID: 'EMP101',
      EmployeeName: 'Renaldottt',
      Department: 'Operations & IT',
      OfficeID: 'OFF-HLG-HQ',
      WorkDate: '2026-09-24', // yesterday
      ClockInTimeUTC: yesterdayUtc,
      ClockInTimeKL: '2026-09-24 20:00:00',
      ClockOutTimeUTC: '',
      ClockOutTimeKL: '',
      ClockInLat: 3.14782,
      ClockInLng: 101.69531,
      ClockInAccuracy: 10,
      ClockInDistanceMeters: 4.0,
      AttendanceStatus: 'IN_PROGRESS',
    });

    // Request challenge
    const chalRes = await request(app)
      .post('/api/attendance/clock-out-challenge')
      .set('Authorization', `Bearer ${employeeToken}`);

    const template = biometricService.getEnrolledTemplate('EMP101');

    // Clock out today morning
    const res = await request(app)
      .post('/api/attendance/clock-out')
      .set('Authorization', `Bearer ${employeeToken}`)
      .send({
        challengeId: chalRes.body.challenge.challengeId,
        probeVector: template.embedding,
        completedLivenessAction: chalRes.body.challenge.livenessAction,
        latitude: 3.14782,
        longitude: 101.69531,
        accuracy: 10,
        timestamp: Date.now(),
      });

    expect(res.status).toBe(200);
    expect(res.body.session.SessionID).toBe(sessionId);
    expect(res.body.session.AttendanceStatus).toBe('COMPLETED');
    expect(res.body.duration.workedHours).toBeGreaterThan(11);
  });
});

describe('5. Role Permissions and Access Control (RBAC)', () => {
  test('Employees CANNOT access admin dashboard endpoints', async () => {
    const res = await request(app)
      .get('/api/admin/metrics')
      .set('Authorization', `Bearer ${employeeToken}`);

    expect(res.status).toBe(403);
    expect(res.body.errorCode).toBe('FORBIDDEN_ADMIN_ONLY');
  });

  test('Employees CANNOT view all company attendance records', async () => {
    const res = await request(app)
      .get('/api/admin/attendance')
      .set('Authorization', `Bearer ${employeeToken}`);

    expect(res.status).toBe(403);
  });

  test('Admin CAN view metrics and download payroll CSV', async () => {
    const res = await request(app)
      .get('/api/admin/metrics')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.metrics.totalEmployees).toBeGreaterThan(0);

    const csvRes = await request(app)
      .get('/api/admin/payroll/export.csv')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(csvRes.status).toBe(200);
    expect(csvRes.headers['content-type']).toContain('text/csv');
    expect(csvRes.text).toContain('EmployeeID,EmployeeName,Department,WorkDate');
  });
});
