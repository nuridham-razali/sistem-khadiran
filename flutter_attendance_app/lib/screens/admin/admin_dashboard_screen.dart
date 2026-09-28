import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/office.dart';
import '../../models/user.dart';
import '../../models/attendance_record.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<Office> _offices = [];
  List<AttendanceRecord> _records = [];
  List<User> _employees = [];
  Map<String, dynamic> _metrics = {};

  String _searchQuery = '';
  String? _selectedStatus;

  DateTimeRange? _payrollRange;
  Map<String, dynamic>? _payrollPreview;

  @override
  void initState() {
    super.initState();
    // 4 Tab: Lokasi Pejabat, Rekod Kehadiran, Kakitangan, Laporan Gaji
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final offices = await _api.getOffices();
      final records = await _api.getAllAttendance(
        search: _searchQuery,
        status: _selectedStatus,
      );
      final employees = await _api.getEmployees();
      final metrics = await _api.getAdminMetrics();

      setState(() {
        _offices = offices;
        _records = records;
        _employees = employees;
        _metrics = metrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
      }
    }
  }

  void _showEditOfficeDialog(Office office) {
    final nameCtrl = TextEditingController(text: office.name);
    final latCtrl = TextEditingController(text: office.latitude.toString());
    final lngCtrl = TextEditingController(text: office.longitude.toString());
    final radiusCtrl = TextEditingController(text: office.radiusMeters.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Pejabat',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Text(
              'Konfigurasi nama, koordinat dan radius geofens lokasi kerja.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const Divider(color: Color(0xFF334155), height: 24),
          ],
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Pejabat', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Pejabat Utama Halagel'),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latitud', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: latCtrl,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Longitud', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: lngCtrl,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        latCtrl.text = '3.1478';
                        lngCtrl.text = '101.6953';
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Koordinat lokasi Halagel HQ diambil')),
                        );
                      },
                      icon: const Icon(Icons.my_location, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Ambil Lokasi Semasa', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Koordinat: ${latCtrl.text}, ${lngCtrl.text}')),
                        );
                      },
                      icon: const Icon(Icons.map, size: 16, color: Colors.white70),
                      label: const Text('Semak di Google Maps', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Radius Kehadiran (meter)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                    suffixText: 'm',
                    suffixStyle: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final newRadius = double.tryParse(radiusCtrl.text.trim()) ?? 50.0;
                        await _api.updateOffice(
                          office.officeId,
                          {
                            'name': nameCtrl.text.trim(),
                            'latitude': double.parse(latCtrl.text.trim()),
                            'longitude': double.parse(lngCtrl.text.trim()),
                            'radiusMeters': newRadius,
                          },
                        );
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Pejabat berjaya dikemas kini (Radius: ${newRadius.toInt()}m)'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('Padam Rekod', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halagel Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Halagel (M) Sdn Bhd • Portal Pentadbir', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.location_city), text: 'Pejabat'),
            Tab(icon: Icon(Icons.fingerprint), text: 'Kehadiran'),
            Tab(icon: Icon(Icons.people), text: 'Kakitangan'),
            Tab(icon: Icon(Icons.assessment), text: 'Laporan Gaji'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOfficesTab(),
                _buildAttendanceTab(),
                _buildEmployeesTab(),
                _buildPayrollTab(),
              ],
            ),
    );
  }

  Widget _buildOfficesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lokasi Pejabat',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_offices.length} pejabat didaftarkan. Kakitangan hanya boleh merekod kehadiran dalam radius yang ditetapkan.',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ Tambah Pejabat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _offices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) {
                  final off = _offices[i];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182234),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.business, color: Color(0xFF10B981), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      off.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Radius kehadiran ${off.radiusMeters.toInt()} m',
                                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70),
                              tooltip: 'Edit Pejabat',
                              onPressed: () => _showEditOfficeDialog(off),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            _coordBox('Latitud', off.latitude.toString()),
                            const SizedBox(width: 12),
                            _coordBox('Longitud', off.longitude.toString()),
                          ],
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Peta dibuka: ${off.latitude}, ${off.longitude}')),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new, size: 14, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Buka di Google Maps',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coordBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pemantauan Kehadiran Halagel', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final r = _records[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF182234),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                      child: const Icon(Icons.check, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.employeeName} (${r.employeeId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Masuk: ${r.clockInTimeKL} • Keluar: ${r.clockOutTimeKL.isEmpty ? "Aktif" : r.clockOutTimeKL}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          Text('Bahagian: ${r.department} • Wajah: ${r.faceVerified}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(r.attendanceStatus == 'COMPLETED' ? 'SELESAI' : (r.attendanceStatus == 'IN_PROGRESS' ? 'AKTIF' : r.attendanceStatus), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                      labelStyle: const TextStyle(color: Color(0xFF34D399)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final e = _employees[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF182234),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E293B),
              child: Icon(Icons.person, color: e.isAdmin ? Colors.purpleAccent : const Color(0xFF10B981)),
            ),
            title: Text('${e.name} (${e.employeeId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${e.email} • ${e.department}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: Chip(
              label: Text(e.faceEnrolled ? 'Wajah Didaftar' : 'Belum Didaftar', style: const TextStyle(fontSize: 10)),
              backgroundColor: e.faceEnrolled ? const Color(0xFF10B981).withOpacity(0.15) : Colors.orange.withOpacity(0.15),
              labelStyle: TextStyle(color: e.faceEnrolled ? const Color(0xFF34D399) : Colors.orangeAccent),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPayrollTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF182234),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Eksport Laporan Gaji (Payroll) Halagel (M) Sdn Bhd', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Muat turun fail CSV ringkasan rekod kehadiran kakitangan yang diselaraskan dengan Google Sheets untuk pemprosesan gaji bulanan.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final url = _api.getPayrollCsvUrl();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const Text('Muat Turun Fail Payroll CSV'),
                        content: Text('Pautan muat turun:\n$url\n\nLajur: EmployeeID, EmployeeName, Department, WorkDate, ClockIn, ClockOut, WorkedMinutes, WorkedHours, AttendanceStatus, ExceptionNotes'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Muat Turun Rekod CSV'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
