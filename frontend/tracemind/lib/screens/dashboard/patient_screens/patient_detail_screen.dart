import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; // <--- NEW CHART IMPORT
import 'package:tracemind/screens/dashboard/patient_screens/session_report_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> patientData;

  const PatientDetailScreen({
    super.key,
    required this.docId,
    required this.patientData
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // --- CONFIGURATION ---
  final String _backendUrl = "http://192.168.137.1:5000"; // Keep your IP here
  // ---------------------

  // --- ALGORITHM: Convert Emotion to a Graphable "Well-being Score" ---
  double _calculateMoodScore(String emotion, int confidence) {
    String em = emotion.toLowerCase();
    // Positive (Score 70-100)
    if (em == 'happy' || em == 'joy') return 70.0 + (confidence * 0.3); 
    // Neutral (Score 40-70)
    if (em == 'neutral' || em == 'surprise') return 40.0 + (confidence * 0.3);
    // Negative (Score 0-40) -> Higher confidence in negative = Lower score
    return 40.0 - (confidence * 0.3).clamp(0, 40); 
  }

  // (Your existing dialog and upload methods remain exactly the same)
  Future<void> _showVideoSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Video Source", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(icon: Icons.videocam, label: "Record Video", color: Colors.redAccent, onTap: () {
                    Navigator.pop(context); _pickAndUpload(ImageSource.camera);
                  }),
                  _buildSourceOption(icon: Icons.video_library, label: "Gallery", color: Colors.teal, onTap: () {
                    Navigator.pop(context); _pickAndUpload(ImageSource.gallery);
                  }),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
      if (video == null) return;

      setState(() => _isUploading = true);

      var request = http.MultipartRequest('POST', Uri.parse('$_backendUrl/analyze'));
      request.files.add(await http.MultipartFile.fromPath('video', video.path));

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String userId = prefs.getString('user_id') ?? FirebaseAuth.instance.currentUser?.uid ?? "unknown_doctor";
      request.fields['user_id'] = userId; 

      request.fields['name'] = widget.patientData['name'] ?? 'Unknown';
      request.fields['id'] = widget.patientData['patient_id'] ?? 'TM-000';
      request.fields['age'] = widget.patientData['age']?.toString() ?? 'N/A';
      request.fields['gender'] = widget.patientData['gender'] ?? 'N/A';
      
      String condition = widget.patientData['condition'] ?? 'General Checkup';
      String sourceNote = source == ImageSource.camera ? "Live Recording" : "Gallery Upload";
      request.fields['notes'] = "Condition: $condition. ($sourceNote)"; 
      request.fields['date'] = DateTime.now().toString().split(' ')[0];

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final stats = jsonResponse['stats']; 
        final String pdfPath = jsonResponse['pdf_url']; 
        
        String dominantEmotion = "Neutral";
        double maxVal = 0.0;
        stats.forEach((key, value) {
          if (value > maxVal) { maxVal = value.toDouble(); dominantEmotion = key; }
        });

        String sessionId = "SESS-${DateTime.now().millisecondsSinceEpoch}";
        
        await FirebaseFirestore.instance.collection('patients').doc(widget.docId).collection('sessions').add({
          'session_id': sessionId,
          'created_at': FieldValue.serverTimestamp(),
          'video_name': video.name,
          'dominant_emotion': dominantEmotion,
          'confidence_score': maxVal.toInt(),
          'full_stats': stats,
          'status': 'Completed',
          'pdf_url': pdfPath,
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Successful!"), backgroundColor: Colors.teal));
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- NEW: THE CHART WIDGET ---
  Widget _buildProgressChart(List<QueryDocumentSnapshot> sessions) {
    if (sessions.isEmpty) {
      return const Center(child: Text("No data to display graph.", style: TextStyle(color: Colors.grey)));
    }
    if (sessions.length == 1) {
      return const Center(child: Text("Graph will generate after the 2nd session.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
    }

    // Map sessions to FlSpots (X, Y points)
    List<FlSpot> spots = [];
    for (int i = 0; i < sessions.length; i++) {
      var data = sessions[i].data() as Map<String, dynamic>;
      String emotion = data['dominant_emotion'] ?? 'Neutral';
      int confidence = data['confidence_score'] ?? 50;
      
      double score = _calculateMoodScore(emotion, confidence);
      spots.add(FlSpot(i.toDouble(), score));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Y numbers to keep it clean
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("S${value.toInt() + 1}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sessions.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.teal,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.teal.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.patientData;
    final String name = data['name'] ?? 'Unknown';
    final String condition = data['condition'] ?? 'Unknown';
    final String gender = data['gender'] ?? '-';
    final int age = data['age'] ?? 0;
    final String patientId = data['patient_id'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      // --- NEW: Wrap entire scroll body in StreamBuilder to share session data ---
      body: StreamBuilder<QuerySnapshot>(
        // NOTE: We fetch oldest-to-newest for the graph to plot left-to-right correctly
        stream: FirebaseFirestore.instance.collection('patients').doc(widget.docId).collection('sessions').orderBy('created_at', descending: false).snapshots(),
        builder: (context, snapshot) {
          
          List<QueryDocumentSnapshot> allSessions = [];
          if (snapshot.hasData) {
            allSessions = snapshot.data!.docs;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Patient Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.teal, Color(0xFF4DB6AC)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))]
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text(name.isNotEmpty ? name[0] : "?", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal))),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patientId, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text("Condition: $condition", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text("Age: $age | $gender", style: const TextStyle(color: Colors.white70)),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 2. New Session Button
                const Text("New Session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                InkWell(
                  onTap: _isUploading ? null : _showVideoSourceDialog, 
                  child: Container(
                    width: double.infinity, height: 120,
                    decoration: BoxDecoration(border: Border.all(color: Colors.teal.shade200, width: 2), borderRadius: BorderRadius.circular(20), color: Colors.teal.shade50),
                    child: _isUploading
                        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Uploading & Analyzing...")]))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.teal.shade700), const SizedBox(height: 10), Text("Upload Video for Analysis", style: TextStyle(fontSize: 16, color: Colors.teal.shade900, fontWeight: FontWeight.bold))]),
                  ),
                ),
                const SizedBox(height: 30),

                // 3. PROGRESS GRAPH SECTION (NEW)
                if (allSessions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Emotional Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Well-being Trend", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildProgressChart(allSessions),
                  const SizedBox(height: 30),
                ],

                // 4. Session History List
                const Text("Session History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (allSessions.isEmpty)
                  const Text("No sessions recorded yet.", style: TextStyle(color: Colors.grey))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allSessions.length,
                    // Reverse the index so the newest shows at the top of the list!
                    itemBuilder: (context, index) {
                      final reversedIndex = allSessions.length - 1 - index;
                      final sessionData = allSessions[reversedIndex].data() as Map<String, dynamic>;

                      final String emotion = sessionData['dominant_emotion'] ?? 'Processing';
                      final int score = sessionData['confidence_score'] ?? 0;
                      final Timestamp? ts = sessionData['created_at'];
                      final String dateStr = ts != null ? "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}" : "Just now";

                      Color statusColor = Colors.grey;
                      if (emotion == 'Anxiety' || emotion == 'Fear') statusColor = Colors.orange;
                      else if (emotion == 'Happy') statusColor = Colors.green;
                      else if (emotion == 'Sad' || emotion == 'Sadness') statusColor = Colors.blue;
                      else if (emotion == 'Angry') statusColor = Colors.red;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        child: ListTile(
                          onTap: () {
                            Map<String, dynamic> stats = sessionData['full_stats'] != null ? Map<String, dynamic>.from(sessionData['full_stats']) : {'Neutral': 100};
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SessionReportScreen(sessionData: sessionData, patientName: name, patientId: patientId, emotionData: stats)));
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.analytics_outlined, color: statusColor),
                          ),
                          title: Text(emotion, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("$dateStr • Confidence: $score%"),
                          trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey),
                        ),
                      );
                    },
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}