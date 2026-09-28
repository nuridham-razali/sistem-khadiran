import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/verification_challenge.dart';
import '../../services/api_service.dart';
import '../../services/biometric_face_service.dart';

class AttendanceFlowScreen extends StatefulWidget {
  final bool isClockIn; // true = Rakam Masuk, false = Rakam Keluar

  const AttendanceFlowScreen({super.key, required this.isClockIn});

  @override
  State<AttendanceFlowScreen> createState() => _AttendanceFlowScreenState();
}

class _AttendanceFlowScreenState extends State<AttendanceFlowScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final BiometricFaceService _bioService = BiometricFaceService();

  int _currentStep = 1; // 1: Lokasi, 2: Swafoto, 3: Pengesahan
  bool _isSearchingLocation = true;
  bool _isSubmitting = false;

  VerificationChallenge? _challenge;
  bool _challengeLoading = false;
  String _livenessInstruction = 'Posisikan wajah anda dalam bulatan bujur';

  late AnimationController _radarController;
  late Animation<double> _radarAnimation;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _radarAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );

    _startLocationSearch();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _startLocationSearch() async {
    setState(() => _isSearchingLocation = true);

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 1500));
    await attendance.checkCurrentLocation();

    if (mounted) {
      setState(() => _isSearchingLocation = false);
    }
  }

  Future<void> _proceedToPhotoStep() async {
    setState(() {
      _currentStep = 2;
      _challengeLoading = true;
    });

    try {
      if (!widget.isClockIn) {
        final chal = await _api.requestClockOutChallenge();
        setState(() {
          _challenge = chal;
          _livenessInstruction = chal.instruction;
          _challengeLoading = false;
        });
      } else {
        setState(() {
          _livenessInstruction = 'Lihat lurus ke kamera dan kelip mata anda 2 kali';
          _challengeLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _challengeLoading = false;
        _livenessInstruction = 'Posisikan wajah anda dengan jelas di dalam bulatan bujur';
      });
    }
  }

  void _proceedToConfirmationStep() {
    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) return;

    final probeVector = _bioService.extractNormalizedEmbedding(seedKey: user.employeeId);

    Map<String, dynamic> result;
    if (widget.isClockIn) {
      result = await attendance.performClockIn();
    } else {
      final challengeId = _challenge?.challengeId ?? 'direct-verify';
      final action = _challenge?.livenessAction ?? 'BLINK_TWICE';
      result = await attendance.performClockOut(
        challengeId: challengeId,
        probeVector: probeVector,
        completedLivenessAction: action,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal memproses kehadiran'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 56),
            ),
            const SizedBox(height: 18),
            Text(
              widget.isClockIn ? 'Rakam Masuk Berjaya!' : 'Rakam Keluar Berjaya!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Data kehadiran anda telah disahkan dan direkodkan dengan selamat ke pangkalan data Google Sheets Halagel (M) Sdn Bhd.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Kembali ke Laman Utama'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isClockIn ? 'Rakam Masuk' : 'Rakam Keluar';
    final subtitle = _currentStep == 1
        ? 'Langkah 1 daripada 3 • Semak lokasi anda'
        : (_currentStep == 2
            ? 'Langkah 2 daripada 3 • Ambil swafoto kehadiran'
            : 'Langkah 3 daripada 3 • Pengesahan data');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildStepperHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: _currentStep == 1
                  ? _buildLocationStep()
                  : (_currentStep == 2 ? _buildPhotoStep() : _buildConfirmationStep()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem(1, 'Lokasi', Icons.location_on),
          _stepDivider(_currentStep > 1),
          _stepItem(2, 'Swafoto', Icons.camera_alt),
          _stepDivider(_currentStep > 2),
          _stepItem(3, 'Pengesahan', Icons.fact_check),
        ],
      ),
    );
  }

  Widget _stepItem(int stepNumber, String title, IconData icon) {
    final isActive = _currentStep >= stepNumber;
    final isCurrent = _currentStep == stepNumber;

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? Colors.white : Colors.white54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildLocationStep() {
    final attendance = Provider.of<AttendanceProvider>(context);

    if (_isSearchingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _radarAnimation,
              builder: (context, child) {
                return Container(
                  width: 140 * _radarAnimation.value,
                  height: 140 * _radarAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.25 / _radarAnimation.value),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.8 / _radarAnimation.value),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 36),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Sedang mengesan lokasi anda...',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Sila tunggu beberapa saat. Pastikan peranti anda mengaktifkan GPS dan sambungan internet stabil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  ),
                  SizedBox(width: 12),
                  Text('Mengesan lokasi...', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final office = attendance.assignedOffice;
    final position = attendance.currentPosition;
    final isInside = attendance.isInsideAttendanceArea;
    final distanceMeters = attendance.distanceToOfficeMeters;
    final allowedRadius = office?.radiusMeters ?? 50.0;

    final officeLatLng = LatLng(office?.latitude ?? 3.1478, office?.longitude ?? 101.6953);
    final userLatLng = position != null ? LatLng(position.latitude, position.longitude) : officeLatLng;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paparan Peta
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: userLatLng,
                      initialZoom: 16.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.halagel.presensi',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: officeLatLng,
                            color: isInside
                                ? const Color(0xFF10B981).withOpacity(0.22)
                                : Colors.red.withOpacity(0.22),
                            borderColor: isInside ? const Color(0xFF10B981) : Colors.red,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: allowedRadius,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: officeLatLng,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                          ),
                          Marker(
                            point: userLatLng,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.person_pin_circle, color: Color(0xFF10B981), size: 36),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Text('🔴 Pejabat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Text('🟢 Anda', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Kad Status Lingkungan Geofens
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF182234),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInside ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isInside ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isInside ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${distanceMeters.toInt()} m',
                      style: TextStyle(
                        color: isInside ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInside ? 'Anda kini berada di kawasan pejabat' : 'Anda belum berada di kawasan pejabat',
                        style: TextStyle(
                          color: isInside ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isInside
                            ? 'Lokasi disahkan. Sila teruskan untuk mengambil swafoto.'
                            : 'Jarak anda ${distanceMeters.toInt()} m (had lingkungan ${allowedRadius.toInt()} m). Sila dekati kawasan pejabat dan semak semula.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.business, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            'Pejabat terdekat: ${office?.name ?? "Pejabat Utama Halagel"}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Butang Tindakan
          if (isInside) ...[
            ElevatedButton.icon(
              onPressed: _proceedToPhotoStep,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Teruskan Ambil Swafoto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _startLocationSearch,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text('Semak Semula Lokasi', style: TextStyle(color: Colors.white70)),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _startLocationSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Semak Semula Lokasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF182234),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.face_retouching_natural, color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengesahan Wajah Biometrik',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _livenessInstruction,
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Container(
              width: 250,
              height: 310,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.face, size: 140, color: Colors.white.withOpacity(0.15)),
                  Container(
                    width: 180,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(90),
                      border: Border.all(color: const Color(0xFF34D399), width: 2),
                    ),
                  ),
                  if (_challengeLoading)
                    const CircularProgressIndicator(color: Color(0xFF10B981)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _proceedToConfirmationStep,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ambil Swafoto Kehadiran'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    final attendance = Provider.of<AttendanceProvider>(context);
    final office = attendance.assignedOffice;
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
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
                const Text(
                  'Ringkasan Data Kehadiran',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(color: Color(0xFF334155), height: 24),
                _summaryRow('Jenis Kehadiran', widget.isClockIn ? 'Rakam Masuk' : 'Rakam Keluar'),
                _summaryRow('Syarikat', 'Halagel (M) Sdn Bhd'),
                _summaryRow('Lokasi Pejabat', office?.name ?? 'Pejabat Utama Halagel'),
                _summaryRow('Waktu (MYT)', DateFormat('dd MMM yyyy, HH:mm:ss').format(now)),
                _summaryRow('Jarak ke Pejabat', '${attendance.distanceToOfficeMeters.toStringAsFixed(1)} m'),
                _summaryRow('Status Geofens', 'Di dalam kawasan pejabat'),
                _summaryRow('Pengecaman Wajah', 'Tervalidasi (1:1 Padanan Biometrik)'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitAttendance,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSubmitting ? 'Menghantar data...' : 'Hantar Kehadiran ke Google Sheets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
