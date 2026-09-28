import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_face_service.dart';

class FaceEnrolmentScreen extends StatefulWidget {
  const FaceEnrolmentScreen({super.key});

  @override
  State<FaceEnrolmentScreen> createState() => _FaceEnrolmentScreenState();
}

class _FaceEnrolmentScreenState extends State<FaceEnrolmentScreen> {
  final ApiService _api = ApiService();
  final BiometricFaceService _bioService = BiometricFaceService();

  bool _consentAgreed = false;
  bool _isCapturing = false;
  String? _errorMessage;

  Future<void> _submitEnrolment() async {
    if (!_consentAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the biometric consent to proceed.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      // Extract normalized vector embedding
      final faceVector = _bioService.extractNormalizedEmbedding(seedKey: user.employeeId);

      const consentText = 'I hereby provide explicit affirmative consent for GeoAttend to process and store my biometric facial template in encrypted storage solely for workplace clock-out attendance verification, in accordance with applicable personal data protection laws.';

      await _api.enrollFace(faceVector: faceVector, consentText: consentText);

      // Update local profile
      final updated = user.toJson();
      updated['faceEnrolled'] = true;
      updated['faceEnrolledAt'] = DateTime.now().toIso8601String();
      auth.updateUserProfile(auth.currentUser!);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Face Profile Enrolled'),
            ],
          ),
          content: const Text(
            'Your facial biometric template has been enrolled and protected in secure server storage.\n\nYou are now authorized to complete face-verified clock-outs.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Face Enrolment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Secure Biometric Enrolment',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To enable 1:1 face verification during clock-out, GeoAttend captures an encrypted mathematical feature vector. Raw photos are NEVER stored in Google Sheets.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Camera Viewport Simulation
            Center(
              child: Container(
                width: 260,
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.face, size: 140, color: Colors.white.withOpacity(0.2)),
                    Container(
                      width: 180,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(90),
                        border: Border.all(color: Colors.white54, width: 2, strokeAlign: BorderSide.strokeAlignInside),
                      ),
                    ),
                    if (_isCapturing)
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                    const Positioned(
                      bottom: 16,
                      child: Text(
                        'Align face inside oval frame',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Consent Checkbox
            CheckboxListTile(
              value: _consentAgreed,
              onChanged: (val) => setState(() => _consentAgreed = val ?? false),
              title: const Text(
                'Affirmative Biometric Consent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'I consent to the capture of my facial template solely for attendance verification. I understand I can request deletion at any time.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isCapturing ? null : _submitEnrolment,
              icon: _isCapturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(
                _isCapturing ? 'Processing Biometrics...' : 'Capture & Enroll Face',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
