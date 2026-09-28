import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import 'attendance_flow_screen.dart';
import 'attendance_history_screen.dart';
import 'face_enrolment_screen.dart';
import '../login_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _selectedNavIndex = 0;
  Timer? _clockTimer;
  DateTime _currentDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).refreshDashboard();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _openAttendanceFlow(bool isClockIn) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceFlowScreen(isClockIn: isClockIn),
      ),
    );

    if (result == true && mounted) {
      Provider.of<AttendanceProvider>(context, listen: false).refreshDashboard();
    }
  }

  void _showQuickActionDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(description, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);
    final user = auth.currentUser;
    final openSession = attendance.openSession;
    final office = attendance.assignedOffice;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: attendance.refreshDashboard,
          color: const Color(0xFF10B981),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Bar Pengguna & Logo Halagel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                          child: const Icon(Icons.person, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat Datang,',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Text(
                              user?.name ?? 'Renaldottt',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Halagel (M) Sdn Bhd',
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Kad Utama: Jam Digital & Butang Rakam Masuk/Keluar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182234),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tarikh & Syif Kerja
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('EEEE, d MMM', 'ms_MY').format(_currentDateTime),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Syif Pagi (08:00 - 17:00)',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Lokasi Pejabat
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            office?.name ?? 'Pejabat Utama Halagel',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const Text(' • GPS dari pejabat', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Jam Digital
                      Text(
                        DateFormat('hh:mm:ss').format(_currentDateTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'WAKTU STANDARD MALAYSIA (MYT / Asia/Kuala_Lumpur)',
                        style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),

                      // Status Biometrik & GPS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Biometrik & GPS Automatik Aktif',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Butang Tindakan Rakam Masuk / Keluar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openAttendanceFlow(openSession == null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: openSession == null ? const Color(0xFF10B981) : Colors.amber.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                openSession == null ? 'Rakam Masuk' : 'Rakam Keluar',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Kehadiran Semasa
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: openSession != null ? const Color(0xFF10B981) : Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              openSession != null
                                  ? 'Status Hari Ini: Telah Masuk (${openSession.clockInTimeKL.split(" ").last})'
                                  : 'Status Hari Ini: Belum Rakam Kehadiran',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Grid Tindakan Pantas (Aksi Pantas)
                const Text(
                  'Tindakan Pantas',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                  children: [
                    _quickActionTile(
                      'Mohon Cuti',
                      Icons.event_note,
                      const Color(0xFF10B981),
                      () => _showQuickActionDialog('Mohon Cuti', 'Borang permohonan cuti tahunan / sakit staf Halagel.'),
                    ),
                    _quickActionTile(
                      'Lebih Masa',
                      Icons.timelapse,
                      Colors.blueAccent,
                      () => _showQuickActionDialog('Kerja Lebih Masa (OT)', 'Rekod tuntutan kerja lebih masa Halagel (M) Sdn Bhd.'),
                    ),
                    _quickActionTile(
                      'Jadual Syif',
                      Icons.calendar_month,
                      Colors.purpleAccent,
                      () => _showQuickActionDialog('Jadual Syif', 'Jadual bertugas anda: Syif Pagi (08:00 - 17:00 MYT).'),
                    ),
                    _quickActionTile(
                      'Pembetulan',
                      Icons.edit_calendar,
                      Colors.orangeAccent,
                      () => _showQuickActionDialog('Pembetulan Kehadiran', 'Permohonan pelarasan masa kehadiran kepada Bahagian Sumber Manusia (HR).'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (user?.faceEnrolled != true)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.face_retouching_natural, color: Colors.amber),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Wajah anda belum didaftarkan. Sila daftarkan profil biometrik untuk pengesahan.',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceEnrolmentScreen()));
                          },
                          child: const Text('Daftar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      // 4. Bar Navigasi Bawah
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(top: BorderSide(color: Color(0xFF334155), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            setState(() => _selectedNavIndex = index);
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
            } else if (index == 3) {
              _showProfileSheet(context, user);
            }
          },
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Laman Utama',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Sejarah',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description),
              label: 'Cuti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, user) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                  child: Text(user?.name.isNotEmpty == true ? user!.name[0] : 'H',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Kakitangan', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user?.email ?? '', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    Text('Halagel (M) Sdn Bhd • ${user?.department ?? ""}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 32),
            ListTile(
              leading: const Icon(Icons.fingerprint, color: Color(0xFF10B981)),
              title: const Text('Status Biometrik Wajah', style: TextStyle(color: Colors.white)),
              trailing: Text(user?.faceEnrolled == true ? 'Terdaftar' : 'Belum Berdaftar', style: TextStyle(color: user?.faceEnrolled == true ? Colors.green : Colors.orange)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceEnrolmentScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Keluar (Keluar Sistem)', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
