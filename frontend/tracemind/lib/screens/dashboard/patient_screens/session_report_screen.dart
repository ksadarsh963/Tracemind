import 'package:flutter/material.dart';
import '../../common/pdf_viewer.dart';

class SessionReportScreen extends StatelessWidget {
  final Map<String, dynamic> sessionData;
  final String patientName;
  final String patientId;
  // 1. Added this field to explicitly accept the emotion numbers
  final Map<String, dynamic> emotionData; 

  const SessionReportScreen({
    super.key,
    required this.sessionData,
    required this.patientName,
    required this.patientId,
    // 2. Added to constructor (You will need to update the calling screen to pass this!)
    required this.emotionData, 
  });

  @override
  Widget build(BuildContext context) {
    // Extract Data
    final String dominantEmotion = sessionData['dominant_emotion'] ?? 'Happy';
    final int confidence = sessionData['confidence_score'] ?? 96;
    final String date = sessionData['created_at'] != null
        ? (sessionData['created_at'] as dynamic).toDate().toString().split(' ')[0]
        : "2024-12-12"; 

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Clinical Report"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coming Soon")));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPdfViewer(context),
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text("View PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PATIENT: $patientName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("ID: $patientId", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("DATE", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const Divider(height: 30),

            // 1. Executive Summary
            const Text("1. EXECUTIVE SUMMARY", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80, height: 80,
                        child: CircularProgressIndicator(
                          value: confidence / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        ),
                      ),
                      Text("$confidence%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Dominant State: ${dominantEmotion.toUpperCase()}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("The subject appeared predominantly engaged and stable throughout the session.",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. Emotional Distribution (FIXED)
            const Text("2. EMOTIONAL DISTRIBUTION", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              // 3. FIX: Removed 'widget.' so it works in StatelessWidget
              child: Column(
                children: emotionData.entries.map((entry) {
                  double percentage = (entry.value is int) 
                      ? entry.value / 100 
                      : (entry.value as double) / 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("${entry.value.toStringAsFixed(1)}%"),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[200],
                          color: _getEmotionColor(entry.key), // Uses helper below
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            ),

            const SizedBox(height: 30),

            // 3. Temporal Analysis
            const Text("3. TEMPORAL ANALYSIS", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),

            Container(
            width: double.infinity,
            decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(16),
                   ),
            child: Theme(
             data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    
                // START OF FIX: Wrap the DataTable in a ScrollView
            child: SingleChildScrollView( 
            scrollDirection: Axis.horizontal, // Allows side-to-side scrolling
      
             child: DataTable(
             headingTextStyle: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black, fontSize: 12),
            columns: const [
                           DataColumn(label: Text("Time Interval")),
                           DataColumn(label: Text("Emotion")), // If this text gets long, it pushes the width
                          DataColumn(label: Text("Score")),
                     ],
                  rows: _generateMockTimelineRows(dominantEmotion),
                )
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // 4. FIX: Added the missing color helper method here
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.blue;
      case 'sad': return Colors.blueGrey;
      case 'angry': return Colors.red;
      case 'neutral': return Colors.grey;
      case 'fear': return Colors.purple;
      case 'disgust': return Colors.green;
      case 'surprise': return Colors.orange;
      default: return Colors.teal;
    }
  }

  // Helper for mock timeline
  List<DataRow> _generateMockTimelineRows(String dominant) {
    List<Map<String, String>> data = [
      {"time": "0-3s", "score": "91.4%"},
      {"time": "3-6s", "score": "83.1%"},
      {"time": "6-9s", "score": "97.7%"},
      {"time": "9-12s", "score": "86.7%"},
      {"time": "12-15s", "score": "78.1%"},
      {"time": "15-18s", "score": "86.9%"},
    ];

    return data.map((item) {
      return DataRow(cells: [
        DataCell(Text(item['time']!, style: const TextStyle(color: Colors.grey))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4)
          ),
          child: Text(dominant, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
        )),
        DataCell(Text(item['score']!, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]);
    }).toList();
  }

  void _openPdfViewer(BuildContext context) {
    // 1. Get the Raw URL from Firestore
    String? rawUrl = sessionData['pdf_url'];

    if (rawUrl == null || rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No PDF URL found.")),
      );
      return;
    }

    // 2. THE FIX: Clean the URL if it's corrupted
    // We check if "https://" appears somewhere in the middle (index > 0)
    // This detects the "http://10.107...https://..." error
    String finalUrl = rawUrl;
    if (rawUrl.contains("https://storage.googleapis.com")) {
      int index = rawUrl.indexOf("https://storage.googleapis.com");
      if (index > 0) {
        // Cut off the bad "http://10.107..." part from the beginning
        finalUrl = rawUrl.substring(index);
      }
    }

    print("Original URL: $rawUrl"); // Debug
    print("Cleaned URL: $finalUrl");  // Debug

    // 3. Open the Viewer with the Clean URL
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: finalUrl,
          title: "Clinical Report - $patientName",
        ),
      ),
    );
  }}