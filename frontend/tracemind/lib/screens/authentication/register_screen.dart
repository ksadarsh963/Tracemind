import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:tracemind/screens/dashboard/patient_screens/ocr_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  
  File? _proofImage;
  bool _isVerified = false;
  bool _isScanning = false;
  bool _isLoading = false; // Added to match the login loading state

  Future<void> _pickAndScanImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File image = File(pickedFile.path);
      
      setState(() {
        _proofImage = image;
        _isScanning = true;
      });

      // Run the OCR Service
      bool isValid = await OCRService.verifyMedicalID(image);

      setState(() {
        _isVerified = isValid;
        _isScanning = false;
      });
      
      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.teal, content: Text("✅ ID Verified Successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.orange, content: Text("⚠️ Verification failed. Account will need manual approval.")),
        );
      }
    }
  }

  Future<void> _register() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty || _licenseController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
       return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload proof!")));
      return;
    }

    setState(() => _isLoading = true);

    var uri = Uri.parse("http://192.168.1.5:5000/register"); // UPDATE WITH YOUR IP
    var request = http.MultipartRequest('POST', uri);

    request.fields['username'] = _userController.text;
    request.fields['password'] = _passController.text;
    request.fields['license_id'] = _licenseController.text;
    
    // Send the verification status we found on the phone
    request.fields['is_verified'] = _isVerified ? "true" : "false";

    request.files.add(await http.MultipartFile.fromPath('proof', _proofImage!.path));

    try {
      var response = await request.send();

      if (response.statusCode == 201) {
        // Success! Go back to Login Screen
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Registration Successful"),
            content: Text(_isVerified 
              ? "Your ID was verified instantly. You can now login." 
              : "We couldn't verify your ID automatically. Please wait for Admin approval."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Go back to Login Screen
                },
                child: const Text("OK", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Failed. Try a different username.")));
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server Error. Check your connection.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Matches Login Background
      body: Stack(
        children: [
          // Background Decor (Matching Login)
          Positioned(
            top: -50, left: -50,
            child: CircleAvatar(radius: 100, backgroundColor: Colors.teal.withOpacity(0.1)),
          ),
          Positioned(
            bottom: 100, right: -30,
            child: CircleAvatar(radius: 80, backgroundColor: Colors.teal.withOpacity(0.08)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.teal.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 50, color: Colors.teal),
                    ),
                    const SizedBox(height: 24),
                    const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                    const SizedBox(height: 8),
                    const Text("Join the TraceMind Network", style: TextStyle(fontSize: 16, color: Color(0xFF718096))),
                    const SizedBox(height: 40),

                    // Registration Form Card
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
                            controller: _userController,
                            icon: Icons.person_outline,
                            hint: "Username",
                            obscure: false,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _licenseController,
                            icon: Icons.badge_outlined,
                            hint: "Medical License ID",
                            obscure: false,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _passController,
                            icon: Icons.lock_outline_rounded,
                            hint: "Password",
                            obscure: true,
                          ),
                          const SizedBox(height: 24),

                          // ID Scanner Button (Styled to match theme)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isScanning ? null : _pickAndScanImage,
                              icon: _isScanning 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 2)) 
                                  : Icon(_isVerified ? Icons.check_circle : Icons.document_scanner_outlined),
                              label: Text(
                                _isScanning ? "Scanning ID..." : (_isVerified ? "ID Verified" : "Scan ID Proof"),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isVerified ? Colors.green.shade50 : Colors.teal.shade50,
                                foregroundColor: _isVerified ? Colors.green.shade700 : Colors.teal.shade700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: _isVerified ? Colors.green.shade200 : Colors.teal.shade200),
                              ),
                            ),
                          ),
                          
                          if (_proofImage != null && !_isVerified && !_isScanning)
                            const Padding(
                              padding: EdgeInsets.only(top: 12.0),
                              child: Text("⚠️ Auto-check failed. Manual approval required.", style: TextStyle(color: Colors.orange, fontSize: 12)),
                            ),

                          const SizedBox(height: 30),

                          // Main Register Button
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
                              onPressed: _isLoading ? null : _register,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          
                          // Navigation Back to Login
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? ", style: TextStyle(color: Color(0xFF718096))),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    color: Colors.teal,
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
          ),
        ],
      ),
    );
  }

  // Reused exact input field style from LoginScreen
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