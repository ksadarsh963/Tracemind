import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to store text
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedGender = 'Male'; // Default value
  bool _isSaving = false;



  Future<void> _savePatient() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final String doctorId = FirebaseAuth.instance.currentUser!.uid;
        final FirebaseFirestore firestore = FirebaseFirestore.instance;

        // START TRANSACTION (Ensures unique ID generation)
        await firestore.runTransaction((transaction) async {

          // 1. Reference to the Counter Document
          // We create a collection 'metadata' to hold stats
          DocumentReference counterRef = firestore.collection('metadata').doc('patient_counter');

          // 2. Read the current count
          DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

          int nextSequence = 1; // Default if no patients exist yet

          if (counterSnapshot.exists) {
            // If exists, get the last number and add 1
            nextSequence = (counterSnapshot.get('current_sequence') as int) + 1;
          }

          // 3. Generate the Custom ID String
          // Format: TM-YYYY-MM-XXXX (e.g., TM-2025-12-0067)
          DateTime now = DateTime.now();
          String year = now.year.toString();
          String month = now.month.toString().padLeft(2, '0'); // Ensures '05' instead of '5'
          String sequence = nextSequence.toString().padLeft(4, '0'); // Ensures '0067'

          String customId = "TM-$year-$month-$sequence";

          // 4. Prepare Patient Data
          final Map<String, dynamic> patientData = {
            "patient_id": customId, // The generated ID
            "doctor_id": doctorId,
            "name": _nameController.text.trim(),
            "age": int.parse(_ageController.text.trim()),
            "gender": _selectedGender,
            "condition": _conditionController.text.trim(),
            "notes": _notesController.text.trim(),
            "created_at": FieldValue.serverTimestamp(),
          };

          // 5. Writes: Save Patient & Update Counter
          // Create a new ref for the patient
          DocumentReference newPatientRef = firestore.collection('patients').doc();

          transaction.set(newPatientRef, patientData); // Save Patient

          DocumentReference logRef = firestore.collection('activity_log').doc();
          transaction.set(logRef, {
            'type': 'patient', // Identifies this as a patient action
            'message': 'New Patient Added: ${_nameController.text}',
            'timestamp': FieldValue.serverTimestamp(),
            'doctor_id': doctorId,
          });


          transaction.set(counterRef, {'current_sequence': nextSequence}); // Update Counter
        });

        // 6. Success UI Updates
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Patient Added!"),
              backgroundColor: Colors.teal,
            ),
          );
          Navigator.pop(context);
        }

      } catch (e) {
        print("Error: $e");
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Soft grey background
      appBar: AppBar(
        title: const Text("New Patient Entry"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Patient Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 5),
              const Text(
                "Please fill in the details carefully.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // 1. Name Field
              _buildLabel("Full Name"),
              _buildTextField(
                controller: _nameController,
                hint: "ex: John Doe",
                icon: Icons.person_outline,
                validator: (value) => value!.isEmpty ? "Name is required" : null,
              ),

              const SizedBox(height: 20),

              // 2. Age and Gender Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Age"),
                        _buildTextField(
                          controller: _ageController,
                          hint: "24",
                          icon: Icons.cake_outlined,
                          isNumber: true,
                          validator: (value) => value!.isEmpty ? "Required" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Gender"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGender,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                              items: ['Male', 'Female', 'Other'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedGender = newValue!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Condition Field
              _buildLabel("Diagnosed Condition"),
              _buildTextField(
                controller: _conditionController,
                hint: "ex: Anxiety Disorder, PTSD",
                icon: Icons.medical_services_outlined,
                validator: (value) => value!.isEmpty ? "Condition is required" : null,
              ),

              const SizedBox(height: 20),

              // 4. Notes Field (Multiline)
              _buildLabel("Initial Notes (Optional)"),
              _buildTextField(
                controller: _notesController,
                hint: "Any specific observations...",
                icon: Icons.note_alt_outlined,
                maxLines: 4,
              ),

              const SizedBox(height: 40),

              // 5. Save Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _savePatient,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "SAVE PATIENT RECORD",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.teal) : Padding(padding: const EdgeInsets.only(bottom: 60), child: Icon(icon, color: Colors.teal)),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}