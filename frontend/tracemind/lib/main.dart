import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORTS FOR YOUR SCREENS ---
// Make sure these paths match your project structure
import 'package:tracemind/screens/authentication/login_screen.dart';
import 'package:tracemind/screens/dashboard/dashboard.dart';
import 'firebase_options.dart';

Future<void> main() async {
  print("1. STARTING APP...");
  WidgetsFlutterBinding.ensureInitialized();
  print("2. FLUTTER BINDING DONE");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("3. FIREBASE INITIALIZED");
  } catch (e) {
    print("ERROR INITIALIZING FIREBASE: $e");
  }
  runApp(const TraceMindApp());
  print("4. RUNAPP CALLED");
}

class TraceMindApp extends StatelessWidget {
  const TraceMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TraceMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Light Grey background
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
              color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      // CHANGE: Use AuthCheck instead of SplashScreen
      home: const AuthCheck(),
    );
  }
}

// --- NEW SMART WIDGET TO FIX BUFFERING ---
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 1. Add a tiny delay to ensure Firebase is ready (prevents glitches)
    await Future.delayed(const Duration(milliseconds: 1000));

    // 2. Check Firebase User
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      print("✅ User is logged in: ${user.uid}");
      
      // 3. AUTO-REPAIR: Ensure User ID is in SharedPreferences for Dashboard
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedId = prefs.getString('user_id');
      
      if (savedId == null || savedId.isEmpty) {
        await prefs.setString('user_id', user.uid);
        print("🔄 ID was missing, re-saved to storage.");
      }

      // 4. Navigate to Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } else {
      print("❌ No user found. Going to Login.");
      // 5. Navigate to Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This acts as your Splash Screen while checking logic
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your Logo or Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, size: 60, color: Colors.teal),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.teal),
          ],
        ),
      ),
    );
  }
}