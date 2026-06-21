import 'dart:convert';
import 'package:http/http.dart' as http;

class DrugInteraction {
  final String severity; // 'high', 'moderate', 'low', 'none'
  final String title;
  final String description;
  final String advice;

  DrugInteraction({
    required this.severity,
    required this.title,
    required this.description,
    required this.advice,
  });

  factory DrugInteraction.fromJson(Map<String, dynamic> json) {
    return DrugInteraction(
      severity: json['severity'] ?? 'low',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      advice: json['advice'] ?? '',
    );
  }
}

class DrugInteractionResult {
  final List<DrugInteraction> interactions;
  final String summary;
  final bool isSafe;

  DrugInteractionResult({
    required this.interactions,
    required this.summary,
    required this.isSafe,
  });
}

class ClaudeAIService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  // Store your API key securely — use flutter_dotenv or Firebase Remote Config
  // Never hardcode in production. Use: const String.fromEnvironment('CLAUDE_API_KEY')
  final String apiKey;

  ClaudeAIService({required this.apiKey});

  Future<DrugInteractionResult> checkDrugInteractions(
      List<String> medications) async {
    if (medications.length < 2) {
      return DrugInteractionResult(
        interactions: [],
        summary: 'Please add at least 2 medications to check interactions.',
        isSafe: true,
      );
    }

    final medicationList = medications.join(', ');

    final systemPrompt = '''
You are a clinical pharmacist AI assistant helping elderly patients and caregivers understand potential drug interactions. 
You must respond ONLY with valid JSON. No markdown, no explanations outside JSON.

Respond with this exact structure:
{
  "summary": "One sentence overall assessment",
  "isSafe": true or false,
  "interactions": [
    {
      "severity": "high" | "moderate" | "low",
      "title": "Drug A + Drug B interaction name",
      "description": "Plain language explanation of what happens",
      "advice": "What the patient/caregiver should do"
    }
  ]
}

Rules:
- Use simple language suitable for elderly users
- severity "high" = dangerous, needs immediate doctor consultation
- severity "moderate" = monitor carefully, inform doctor at next visit  
- severity "low" = minor, generally safe but worth noting
- If no interactions found, return empty interactions array and isSafe: true
- Always recommend consulting their doctor for final decisions
''';

    final userMessage =
        'Check drug interactions for these medications: $medicationList';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1000,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'] as String;

        // Strip any accidental markdown fences
        final cleanJson =
            content.replaceAll(RegExp(r'```json|```'), '').trim();
        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;

        final interactions = (parsed['interactions'] as List)
            .map((i) => DrugInteraction.fromJson(i as Map<String, dynamic>))
            .toList();

        return DrugInteractionResult(
          interactions: interactions,
          summary: parsed['summary'] ?? '',
          isSafe: parsed['isSafe'] ?? true,
        );
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to check interactions: $e');
    }
  }

  Future<String> askMedicineQuestion(String question,
      {List<String>? currentMeds}) async {
    final medsContext = currentMeds != null && currentMeds.isNotEmpty
        ? "\n\nPatient's current medications: ${currentMeds.join(', ')}"
        : '';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 500,
          'system':
              'You are a friendly clinical pharmacist assistant for elderly patients. Give clear, simple, compassionate answers. Always recommend consulting their doctor or pharmacist for personal medical decisions. Keep responses concise and easy to understand.$medsContext',
          'messages': [
            {'role': 'user', 'content': question}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get answer: $e');
    }
  }
}