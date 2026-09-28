import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'employee/employee_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'renaldi@example.com');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillAccount(String email, String pwd) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = pwd;
      _loginError = null;
    });
  }

  Future<void> _submitLogin() async {
    setState(() => _loginError = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      if (auth.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmployeeDashboardScreen()),
        );
      }
    } else {
      setState(() {
        _loginError = 'Emel atau kata laluan tidak sah';
      });
    }
  }

  void _showServerSettings() {
    final api = ApiService();
    final ctrl = TextEditingController(text: api.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Tetapan Pelayan Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Alamat IP Pelayan Express.js (Gunakan http://10.0.2.2:4000/api untuk Android emulator):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'URL API'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              api.setBaseUrl(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white60),
            tooltip: 'Tetapan Pelayan',
            onPressed: _showServerSettings,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Biometrik Bersinar Hijau
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fingerprint,
                          size: 46,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lencana Syarikat
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Halagel (M) Sdn Bhd',
                        style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tajuk & Sari Kata dalam Bahasa Melayu
                  const Text(
                    'Selamat Kembali',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Log masuk untuk merekod kehadiran dan tugasan kerja hari ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Makluman Ralat Jika Ada
                  if (_loginError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _loginError!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // Medan Emel
                  const Text('Alamat Emel', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'renaldi@example.com',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.alternate_email, color: Colors.white54, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Sila masukkan alamat emel anda' : null,
                  ),
                  const SizedBox(height: 16),

                  // Medan Kata Laluan
                  const Text('Kata Laluan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Kata Laluan',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Sila masukkan kata laluan' : null,
                  ),
                  const SizedBox(height: 10),

                  // Pilihan "Ingat saya" & "Lupa Kata Laluan?"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _rememberMe = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Ingat saya', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Lupa Kata Laluan?',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Butang Log Masuk
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Log Masuk Kehadiran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.fingerprint, color: Color(0xFF10B981)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Penderia biometrik cap jari sedia diimbas')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Pilihan Akaun Demo Halagel
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182234),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Akaun Contoh Halagel:',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              backgroundColor: const Color(0xFF1E293B),
                              avatar: const Icon(Icons.person, color: Color(0xFF10B981), size: 16),
                              label: const Text('Renaldottt (Kakitangan)', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _fillAccount('renaldi@example.com', 'Password123!'),
                            ),
                            ActionChip(
                              backgroundColor: const Color(0xFF1E293B),
                              avatar: const Icon(Icons.admin_panel_settings, color: Colors.purpleAccent, size: 16),
                              label: const Text('Admin Halagel (Pengurus)', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _fillAccount('admin@halagel.com', 'AdminPassword123!'),
                            ),
                            ActionChip(
                              backgroundColor: const Color(0xFF1E293B),
                              avatar: const Icon(Icons.person_outline, color: Colors.orangeAccent, size: 16),
                              label: const Text('Nurul Huda (Staf Baharu)', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _fillAccount('nurul@halagel.com', 'Password123!'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
