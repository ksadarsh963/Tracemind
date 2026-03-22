import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_new_patient.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final String? loggedDoctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Patients"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
            color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPatientScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .where('doctor_id', isEqualTo: loggedDoctorId)


            .snapshots(),
        builder: (context, snapshot) {


          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }


          if (snapshot.hasError) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Something went wrong.\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
            );
          }


          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  const Text(
                    "No patients added yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddPatientScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade50,
                        foregroundColor: Colors.teal,
                        elevation: 0
                    ),
                    child: const Text("Add Your First Patient"),
                  )
                ],
              ),
            );
          }


          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final String name = data['name'] ?? 'Unknown';
              final String condition = data['condition'] ?? 'Unspecified';
              final String patientId = data['patient_id'] ?? 'ID-PENDING';

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.teal.shade50,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                          ),
                          child: Text(
                              patientId,
                              style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(condition, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {

                String docId = docs[index].id;


                Map<String, dynamic> patientData = docs[index].data() as Map<String, dynamic>;

                Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailScreen(
                    docId: docId,             // PASS ID
                    patientData: patientData, // PASS DATA
                  ),
                ),
              );
            },
                ),
              );
            },
          );
        },
      ),
    );
  }
}