import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HalagelAttendanceApp());
}

class HalagelAttendanceApp extends StatelessWidget {
  const HalagelAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Exact dark theme and emerald green accents matching the user's video demo
    const primaryEmerald = Color(0xFF10B981); // Emerald 500
    const primaryDarkEmerald = Color(0xFF059669); // Emerald 600
    const darkBackground = Color(0xFF0F172A); // Slate 900
    const darkSurface = Color(0xFF1E293B); // Slate 800
    const darkCard = Color(0xFF182234);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        title: 'Halagel Presensi',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark, // Default to dark theme matching video
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: darkBackground,
          colorScheme: const ColorScheme.dark(
            primary: primaryEmerald,
            secondary: Color(0xFF34D399),
            surface: darkSurface,
            surfaceContainerHighest: darkCard,
            onPrimary: Colors.white,
            onSurface: Colors.white,
          ),
          cardTheme: CardTheme(
            color: darkSurface,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: darkBackground,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryEmerald, width: 1.5),
            ),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
