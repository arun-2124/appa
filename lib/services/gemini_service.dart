import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Gemini chat service ────────────────────────────────────────────────────
// REST call to Google's Gemini API (generateContent).
// Requires the `http` package in pubspec.yaml.
//
// HOW TO ADD YOUR KEY:
//   Paste your key from https://aistudio.google.com/apikey
//   directly into defaultValue below.

class GeminiService {
  // ✅ Paste your Gemini API key here as the defaultValue
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '123',
  );

  static const String _model = 'gemini-2.5-flash';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ✅ FIXED: only treats key as missing if it's empty or the literal
  // placeholder text — a real key always passes this check.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _apiKey != '123';

  /// Sends [prompt] to Gemini, optionally with prior [history] turns and a
  /// [systemInstruction] persona string.
  ///
  /// [history] format: [{'role': 'user'|'model', 'text': '...'}]
  static Future<String> generateReply({
    required String prompt,
    List<Map<String, String>>? history,
    String? systemInstruction,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'No Gemini API key found. Open lib/services/gemini_service.dart '
        'and paste your key into the defaultValue field.',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl/$_model:generateContent?key=$_apiKey',
    );

    // Build contents array from history + new prompt
    final contents = <Map<String, dynamic>>[];

    if (history != null) {
      for (final turn in history) {
        contents.add({
          'role' : turn['role'],
          'parts': [
            {'text': turn['text']}
          ],
        });
      }
    }

    // Add current user message
    contents.add({
      'role' : 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final body = <String, dynamic>{
      'contents': contents,
      if (systemInstruction != null)
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ],
        },
      'generationConfig': {
        'maxOutputTokens': 500,
        'temperature'    : 0.7,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body   : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data       = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'Gemini returned no candidates — possibly blocked by safety filters.',
      );
    }

    final parts = (candidates.first['content']?['parts'] as List?) ?? [];
    final text  = parts
        .map((p) => p['text']?.toString() ?? '')
        .join()
        .trim();

    if (text.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    return text;
  }
}