import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracemind/screens/authentication/login_screen.dart';
import 'package:tracemind/screens/dashboard/patient_screens/patient_listing.dart';
// import 'package:url_launcher/url_launcher.dart'; // Uncomment if you add url_launcher to pubspec.yaml

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String currentUserId = "";
  String patientCount = "0";
  String reportCount = "0";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('user_id');

    if (savedId == null || savedId.isEmpty) {
      // Fail-safe: Redirect to login if ID is missing
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } else {
      setState(() {
        currentUserId = savedId;
      });
      _fetchCounts(); // Load the numbers for the cards
    }
  }

  // Helper to count documents for the Stat Cards
  void _fetchCounts() async {
    if (currentUserId.isEmpty) return;

    // 1. Count Patients
    QuerySnapshot patients = await FirebaseFirestore.instance
        .collection('patients')
        .where('doctor_id', isEqualTo: currentUserId)
        .get();

    // 2. Count Reports
    QuerySnapshot reports = await FirebaseFirestore.instance
        .collection('activity_log')
        .where('doctor_id', isEqualTo: currentUserId)
        .get();

    if (mounted) {
      setState(() {
        patientCount = patients.docs.length.toString();
        reportCount = reports.docs.length.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Coming soon")));
            },
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. STAT CARDS (Restored!) ---
            Row(
              children: [
                Expanded(
                  child: _buildStatCard("Total Patients", patientCount,
                      Colors.blue.shade100, Colors.blue),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildStatCard("Reports Ready", reportCount,
                      Colors.orange.shade100, Colors.orange),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text("Recent Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- 2. RECENT ACTIVITY LIST (Firebase Stream) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_log')
                  .where('doctor_id', isEqualTo: currentUserId)
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text("No recent activity found.",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          child: const Icon(Icons.analytics_outlined,
                              color: Colors.teal, size: 20),
                        ),
                        title: Text(data['message'] ?? "Session Analysis",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            "Confidence: ${data['confidence'] ?? 0}%",
                            style: TextStyle(color: Colors.grey[600])),
                        trailing: const Icon(Icons.picture_as_pdf,
                            color: Colors.redAccent, size: 20),
                        onTap: () {
                          // PDF opening logic will go here
                          String? url = data['pdf_url'];
                          if (url != null) {
                            print("Open PDF: $url");
                            // launchUrl(Uri.parse(url)); 
                          }
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- 3. BUTTONS (Restored!) ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.people),
                label: const Text("View All Patients"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PatientListScreen()),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER FUNCTIONS ---
  Widget _buildStatCard(
      String title, String count, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count,
              style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.bold, color: iconColor)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}