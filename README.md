# Halagel Kehadiran - Halagel (M) Sdn Bhd

Sistem Kehadiran Pekerja Digital & Geofens GPS rasmi yang dibina untuk **Halagel (M) Sdn Bhd**, dilengkapi antara muka bertema gelap zamrud (*dark emerald*), aplikasi mudah alih **Flutter & Android Jetpack Compose**, bahagian belakang (*backend*) **Node.js dengan Express.js**, serta integrasi terus ke **Google Sheets** sebagai pangkalan data kehadiran dan sistem penggajian (*payroll*).

---

## 1. Ciri-Ciri Utama Sistem

| Ciri Sistem | Butiran Pelaksanaan |
|---|---|
| **Identiti & Tema Jenama** | Latar belakang gelap korporat (`#0F172A`), aksen hijau zamrud Halagel (`#10B981` / `#34D399`), sasaran imbasan biometrik, dan kad M3 moden. |
| **Papan Pemuka Kakitangan (Dashboard)** | Nama staf (Ahmad Farhan), ID Staf (HLG-2024-089), Jabatan Jaminan Kualiti Halal (QA), Jam Digital Masa Nyata Waktu Standard Malaysia (MYT / `Asia/Kuala_Lumpur`), status syif kerja, dan status kehadiran hari ini. |
| **Geofens GPS Masa Nyata** | Pengiraan formula Haversine antara lokasi GPS staf dan pejabat Halagel, penunjuk ketepatan isyarat GPS, dan lencana status jelas ("Di Dalam Sempadan Kehadiran" / "Di Luar Sempadan Kehadiran"). |
| **Aliran Kehadiran 3-Langkah** | 1. Semakan Lokasi GPS Geofens<br>2. Pengesahan Wajah Biometrik Masa Nyata (Ujian Keaktifan / *Liveness*)<br>3. Pengesahan & Penghantaran Rekod ke Google Sheets. |
| **Pengesahan Wajah Biometrik (Rakam Keluar)** | Pengesahan 1:1 terhadap templat wajah berdaftar staf. Ujian keaktifan (kelip mata/senyum) bagi mencegah penipuan foto/video. |
| **Pengurusan Pejabat Pentadbir** | Pendaftaran dan penyuntingan pejabat Halagel (Ibu Pejabat & Kilang Sungai Petani, Pejabat Korporat KL, Pusat Logistik Cyberjaya) beserta koordinat latitud/longitud dan radius kehadiran (meter). |
| **Eksport Penggajian (Payroll)** | Penjanaan laporan kehadiran lengkap dan keupayaan muat turun fail CSV untuk sistem penggajian syarikat. |
| **Pematuhan PDPA & Keselamatan** | Templat biometrik disulitkan secara berasingan. Cap masa menggunakan pelayan (bukan jam peranti pengguna). |

---

## 2. Struktur Pangkalan Data Google Sheets

Akses ke Google Sheets dikendalikan sepenuhnya melalui pelayan Node.js Express menggunakan sistem giliran berturut (*FIFO write serialization queue*) bagi mengelakkan had kuota API Google.

### Lembaran Kerja:
1. **`Employees`**: `EmployeeID, Name, Email, Department, AssignedOfficeID, Role, Active, PasswordHash, FaceEnrolled, FaceEnrolledAt, CreatedAt`
2. **`Offices`**: `OfficeID, Name, Latitude, Longitude, RadiusMeters, MaxAccuracyMeters, MaxAgeSeconds, Address, Active`
3. **`Attendance`**: `SessionID, EmployeeID, EmployeeName, Department, OfficeID, WorkDate, ClockInTimeUTC, ClockInTimeKL, ClockOutTimeUTC, ClockOutTimeKL, ClockInLat, ClockInLng, ClockInAccuracy, ClockInDistanceMeters, ClockOutLat, ClockOutLng, ClockOutAccuracy, ClockOutDistanceMeters, FaceVerified, FaceVerificationConfidence, WorkedMinutes, WorkedHours, AttendanceStatus, ExceptionNotes, LastModifiedBy, LastModifiedAt`
4. **`AuditLog`**: `LogID, ActorID, ActorName, Action, AffectedRecordType, AffectedRecordID, TimestampUTC, TimestampKL, Reason, BeforeValues, AfterValues`

---

## 3. Panduan Menjalankan Sistem

### Maklumat Log Masuk Ujian:
- **Pentadbir Sistem (Admin)**: `admin@halagel.com` atau ID `ADMIN` / `admin123`

### Menjalankan Pelayan Node.js Backend:
```bash
cd backend
npm install
npm run seed-data   # Memasukkan data pejabat dan staf Halagel (M) Sdn Bhd
npm start           # Pelayan beroperasi di http://localhost:4000
```

### Menjalankan Ujian Automasi:
```bash
cd backend
npm test
```

### Menjalankan Aplikasi Flutter:
```bash
cd flutter_attendance_app
flutter pub get
flutter run
```
