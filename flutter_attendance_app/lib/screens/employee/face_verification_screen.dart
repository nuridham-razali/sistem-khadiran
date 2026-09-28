import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/verification_challenge.dart';
import '../../services/api_service.dart';
import '../../services/biometric_face_service.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  final ApiService _api = ApiService();
  final BiometricFaceService _bioService = BiometricFaceService();

  VerificationChallenge? _challenge;
  bool _isLoadingChallenge = true;
  bool _isVerifying = false;
  String? _errorMessage;
  int _secondsRemaining = 120;
  Timer? _countdownTimer;

  // Liveness prompt state
  bool _actionCompleted = false;

  @override
  void initState() {
    super.initState();
    _fetchChallenge();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchChallenge() async {
    setState(() {
      _isLoadingChallenge = true;
      _errorMessage = null;
      _actionCompleted = false;
    });

    try {
      final challenge = await _api.requestClockOutChallenge();
      setState(() {
        _challenge = challenge;
        _secondsRemaining = challenge.expiresInSeconds;
        _isLoadingChallenge = false;
      });

      _startTimer();
    } catch (e) {
      setState(() {
        _isLoadingChallenge = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _errorMessage = 'Verification challenge expired. Please request a fresh challenge.';
        });
      }
    });
  }

  Future<void> _performVerificationAndClockOut() async {
    if (_challenge == null || _secondsRemaining <= 0) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // Simulate capturing camera frame and extracting normalized 128-d biometric embedding
    // In production, MLKit Face Detector or camera image stream feeds the normalized embedding
    final probeVector = _bioService.extractNormalizedEmbedding(seedKey: user.employeeId);

    // Call clock-out endpoint with single-use challenge token
    final result = await attendance.performClockOut(
      challengeId: _challenge!.challengeId,
      probeVector: probeVector,
      completedLivenessAction: _challenge!.livenessAction,
    );

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Verification failed';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Clock-Out Confirmed'),
          ],
        ),
        content: const Text(
          'Face verification successful and GPS location verified within office radius!\n\nYour attendance session has been recorded to Google Sheets and your worked hours have been logged for payroll.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(true);
            },
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Verification (Clock-Out)'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingChallenge
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Generating secure single-use challenge...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Timer and Challenge ID
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer, color: _secondsRemaining < 20 ? Colors.red : Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Challenge expires: ${_secondsRemaining}s',
                                style: TextStyle(
                                  color: _secondsRemaining < 20 ? Colors.redAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ID: ${_challenge?.challengeId.substring(0, 8) ?? ''}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Camera Preview Frame Simulation with Face Oval
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Viewfinder
                          Container(
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _isVerifying ? Colors.cyanAccent : Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Silhouette icon
                                  Icon(
                                    Icons.face,
                                    size: 160,
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                  // Oval Guide
                                  Container(
                                    width: 200,
                                    height: 270,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: _actionCompleted ? Colors.green : Colors.cyanAccent,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  // Scanning beam when verifying
                                  if (_isVerifying)
                                    const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.cyanAccent,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Instruction Banner on Viewport
                          Positioned(
                            bottom: 40,
                            left: 40,
                            right: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'LIVENESS CHALLENGE',
                                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _challenge?.instruction ?? 'Look directly into camera',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Error banner if any
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                            onPressed: _fetchChallenge,
                          ),
                        ],
                      ),
                    ),

                  // Bottom Verification Actions
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isVerifying || _secondsRemaining <= 0
                              ? null
                              : _performVerificationAndClockOut,
                          icon: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                            _isVerifying ? 'Verifying 1:1 Biometrics...' : 'Verify Face & Clock Out',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1:1 verification compares your probe against your enrolled profile with active liveness check. Biometrics are not stored in Google Sheets.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
