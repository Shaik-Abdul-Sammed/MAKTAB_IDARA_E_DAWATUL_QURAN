import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:maktab_app/services/secure_env_service.dart';

class AiService {
  static final String _apiKey = SecureEnvService.geminiApiKey;
  
  late GenerativeModel _model;

  AiService() {
    // gemini-1.5-flash is extremely fast and capable of both text and vision
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  /// Analyzes a student's attendance and Quran progress and generates a constructive summary for parents.
  Future<String> generateStudentReportSummary(String studentName, Map<String, dynamic> performanceData) async {
    try {
      final prompt = '''
      You are an encouraging and professional Islamic school (Maktab) teacher. 
      Analyze the following student data for "$studentName" and write a short, constructive paragraph (max 3 sentences) to share with their parents.
      Focus on their attendance pattern and their Quran recitation progress.
      
      Data:
      ${jsonEncode(performanceData)}
      
      Return ONLY the summary paragraph.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Unable to generate summary at this time.';
    } catch (e) {
      debugPrint('AI Service Error: $e');
      return 'AI Analysis currently unavailable. Please check internet connection.';
    }
  }

  Future<String> smartTranslate(String text, String targetLanguage, {List<String> namesToIgnore = const []}) async {
    try {
      String namesContext = '';
      if (namesToIgnore.isNotEmpty) {
        namesContext = "DO NOT translate the following proper nouns/names: ${namesToIgnore.join(', ')}. Keep them exactly as they are or transliterate them accurately if necessary.";
      }
      
      final prompt = '''
You are a professional translator for an Islamic educational application.
Translate the following text into $targetLanguage.
$namesContext

Text to translate:
"$text"

Return ONLY the translated text, nothing else.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? text;
    } catch (e) {
      debugPrint('Translation Error: $e');
      return text;
    }
  }
}
