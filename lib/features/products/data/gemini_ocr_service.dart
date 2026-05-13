import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/nutri_score_calculator.dart';

class GeminiOcrService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  Future<NutritionalData?> extractFromImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              },
              {
                'text':
                    'Ești un sistem de extragere date nutriționale. Analizează eticheta nutrițională din imagine și returnează DOAR un JSON valid, fără text suplimentar, fără markdown, fără explicații. JSON-ul trebuie să aibă exact această structură: {"name": string sau null, "brand": string sau null, "calories": number sau null, "protein": number sau null, "fat": number sau null, "carbs": number sau null, "sugar": number sau null, "salt": number sau null}. Toate valorile numerice sunt per 100g. Dacă un câmp nu e vizibil în imagine, pune null.'
              }
            ]
          }
        ]
      });

      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Cheia API Gemini nu este validă sau a expirat.');
      } else if (response.statusCode == 429) {
        throw Exception('Limita de cereri Gemini a fost atinsă.');
      } else if (response.statusCode != 200) {
        throw Exception('Serviciul OCR nu este disponibil (${response.statusCode}).');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content =
          candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String?;
      if (text == null) return null;

      final cleanText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final data = jsonDecode(cleanText) as Map<String, dynamic>;

      return NutritionalData(
        name: data['name'] as String?,
        brand: data['brand'] as String?,
        calories: (data['calories'] as num?)?.toDouble(),
        protein: (data['protein'] as num?)?.toDouble(),
        fat: (data['fat'] as num?)?.toDouble(),
        carbs: (data['carbs'] as num?)?.toDouble(),
        sugar: (data['sugar'] as num?)?.toDouble(),
        salt: (data['salt'] as num?)?.toDouble(),
      );
    } catch (e) {
      rethrow;
    }
  }
}
