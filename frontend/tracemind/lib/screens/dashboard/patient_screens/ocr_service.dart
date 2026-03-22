import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static Future<bool> verifyMedicalID(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // 1. Scan the image
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String fullText = recognizedText.text.toLowerCase();

      print("--- SCANNED TEXT ---");
      print(fullText);
      print("--------------------");

      // 2. Define your Keywords
      List<String> keywords = [
        'license', 
        'psychologist', 
        'medical', 
        'doctor', 
        'registry', 
        'council', 
        'board',
        'clinical'
      ];

      // 3. Check for matches
      for (String word in keywords) {
        if (fullText.contains(word)) {
          print("✅ Verified! Found keyword: $word");
          return true;
        }
      }

      print("❌ Verification Failed: No keywords found.");
      return false;

    } catch (e) {
      print("OCR Error: $e");
      return false;
    } finally {
      textRecognizer.close();
    }
  }
}