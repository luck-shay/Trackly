import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''); // You can compile with --dart-define=GEMINI_API_KEY=YOUR_KEY

  static Future<bool> validateHabitCompletion(String habitTitle, File imageFile) async {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        print("No Gemini API Key provided, rejecting photo validation.");
      }
      return false;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = TextPart('''
        Analyze this image. The user claims this picture proves they completed their habit: "$habitTitle".
        Does the image realistically demonstrate the completion or participation in this habit?
        Reply with a single word "YES" if it proves it, or "NO" if it clearly does not.
      ''');

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final text = response.text?.trim().toUpperCase() ?? 'NO';
      return text.contains('YES');
    } catch (e) {
      if (kDebugMode) print("Error during AI validation: $e");
      return false;
    }
  }
}
