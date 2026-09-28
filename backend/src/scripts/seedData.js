require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const bcrypt = require('bcryptjs');
const sheetsService = require('../services/sheetsService');
const { getNowUTC, formatKualaLumpurTime } = require('../utils/timeUtils');

async function seed() {
  console.log('[Seed] Inisialisasi sistem Halagel (M) Sdn Bhd (Bebas Data Palsu)...');

  const passwordHashAdmin = await bcrypt.hash('admin123', 10);

  // 1. Lokasi Pejabat Rasmi Halagel (M) Sdn Bhd
  const offices = [
    {
      OfficeID: 'OFF-01',
      Name: 'Ibu Pejabat & Kilang Halagel',
      Latitude: 5.6432,
      Longitude: 100.4912,
      RadiusMeters: 120,
      MaxAccuracyMeters: 50,
      MaxAgeSeconds: 60,
      Address: 'Kawasan Perusahaan MIEL, 08000 Sungai Petani, Kedah',
      Active: 'TRUE',
    },
    {
      OfficeID: 'OFF-02',
      Name: 'Pejabat Korporat & Pemasaran',
      Latitude: 3.1478,
      Longitude: 101.6953,
      RadiusMeters: 80,
      MaxAccuracyMeters: 50,
      MaxAgeSeconds: 60,
      Address: 'Halagel Corporate Centre, Kuala Lumpur',
      Active: 'TRUE',
    },
    {
      OfficeID: 'OFF-03',
      Name: 'Pusat Pengedaran & Logistik',
      Latitude: 2.9213,
      Longitude: 101.6559,
      RadiusMeters: 150,
      MaxAccuracyMeters: 50,
      MaxAgeSeconds: 60,
      Address: 'Cyberjaya, Selangor',
      Active: 'TRUE',
    },
  ];

  // 2. Akaun Pentadbir Admin Rasmi (Tiada kakitangan dummy)
  const employees = [
    {
      EmployeeID: 'ADMIN',
      Name: 'Pentadbir Admin Halagel',
      Email: 'admin@halagel.com',
      Department: 'Pentadbiran & Operasi Halagel',
      AssignedOfficeID: 'OFF-01',
      Role: 'admin',
      Active: 'TRUE',
      PasswordHash: passwordHashAdmin,
      FaceEnrolled: 'TRUE',
      FaceEnrolledAt: '2026-01-01T00:00:00Z',
      CreatedAt: '2026-01-01T00:00:00Z',
    },
  ];

  const now = getNowUTC();
  const klTime = formatKualaLumpurTime(now);

  sheetsService.cache['Offices'] = offices;
  sheetsService.cache['Employees'] = employees;
  sheetsService.cache['Attendance'] = []; // Kosong, menunggu rekod staf sebenar
  sheetsService.cache['AuditLog'] = [
    {
      LogID: 'LOG-INIT-001',
      ActorID: 'SYSTEM',
      ActorName: 'Sistem Inisialisasi Halagel',
      Action: 'BOOTSTRAP',
      AffectedRecordType: 'Database',
      AffectedRecordID: 'ALL',
      TimestampUTC: now,
      TimestampKL: klTime.displayKL,
      Reason: 'Pangkalan data sedia menerima senarai ID dan nama kakitangan sebenar.',
      BeforeValues: '',
      AfterValues: { syarikat: 'Halagel (M) Sdn Bhd', status: 'Sedia menerima data' },
    },
  ];

  sheetsService.saveLocalCache();
  console.log('[Seed] Pangkalan data Halagel berjaya diinisialisasi tanpa sebarang data palsu!');
}

if (require.main === module) {
  seed();
}

module.exports = seed;
