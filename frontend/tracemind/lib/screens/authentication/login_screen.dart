import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- 1. NEW IMPORT
import '../dashboard/dashboard.dart';
import 'package:tracemind/screens/authentication/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // 1. Start Loading
    setState(() => _isLoading = true);
        
    try {
      // 2. Authenticate with Firebase
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. --- CRITICAL FIX: SAVE THE ID ---
      // This bridges the gap so Dashboard can find who you are
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String userId = userCredential.user!.uid;
      await prefs.setString('user_id', userId);
      print("✅ User ID saved: $userId");
      // ------------------------------------

      if (mounted) {
        // 4. Navigate to Dashboard (Now it won't spin forever!)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // ... (Error handling remains the same) ...
      print("LOGIN ERROR: ${e.code} - ${e.message}");

      String message = "An error occurred";
      if (e.code == 'invalid-credential') {
        message = "Invalid email or password.";
      } 
      else if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } 
      else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } 
      else if (e.code == 'invalid-email') {
        message = 'The email address is badly formatted.';
      }
      else if (e.code == 'operation-not-allowed') {
        message = 'Email/Password login is not enabled in Firebase Console.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -50, left: -50,
            child: CircleAvatar(radius: 100, backgroundColor: Colors.teal.withOpacity(0.1)),
          ),
          Positioned(
            bottom: 100, right: -30,
            child: CircleAvatar(radius: 80, backgroundColor: Colors.teal.withOpacity(0.08)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.teal.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.psychology, size: 50, color: Colors.teal),
                  ),
                  const SizedBox(height: 24),

                  const Text("TraceMind", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                  const SizedBox(height: 8),
                  const Text("Authorized Access Only", style: TextStyle(fontSize: 16, color: Color(0xFF718096))),
                  const SizedBox(height: 40),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          hint: "Official Email",
                          obscure: false,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          controller: _passwordController,
                          icon: Icons.lock_outline_rounded,
                          hint: "Password",
                          obscure: true,
                        ),
                        const SizedBox(height: 30),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        
                        // Sign Up Link
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                                );
                              },
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool obscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.teal.shade300),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}