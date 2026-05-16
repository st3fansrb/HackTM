import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/nutri_score_calculator.dart';

class GeminiOcrService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const _allowedUnits = {'g', 'kg', 'ml', 'L', 'buc'};
  static const _allowedCategories = {
    'dairy',
    'meat',
    'vegetables',
    'fruits',
    'grains',
    'other',
  };

  static const _prompt =
      'Ești un sistem de extragere a datelor de pe ambalajul produselor '
      'alimentare din România. Analizează imaginea unui produs alimentar '
      '(fața ambalajului și/sau tabelul nutrițional) și returnează DOAR un '
      'JSON valid, fără text suplimentar, fără markdown, fără explicații. '
      'Structura exactă: {"name": string sau null, "brand": string sau null, '
      '"quantity": number sau null, "unit": string sau null, '
      '"category": string sau null, "calories": number sau null, '
      '"protein": number sau null, "fat": number sau null, '
      '"carbs": number sau null, "sugar": number sau null, '
      '"salt": number sau null}. '
      'Reguli: '
      '"name" = denumirea produsului de pe față (ex: "Lapte Zuzu 1.5%"), '
      'dedu-o chiar dacă nu există tabel nutrițional. '
      '"brand" = marca/producătorul (ex: "Zuzu", "Danone"). '
      '"quantity" și "unit" = conținutul net de pe ambalaj: '
      '"500 g" -> quantity 500, unit "g"; "1 L" -> 1, "L"; '
      '"1,5 L" -> 1.5, "L"; "10 ouă" -> 10, "buc". '
      '"unit" trebuie să fie EXACT una dintre: "g", "kg", "ml", "L", "buc". '
      '"category" trebuie să fie EXACT una dintre: "dairy" (lactate, ouă), '
      '"meat" (carne, mezeluri, pește), "vegetables" (legume), '
      '"fruits" (fructe), "grains" (pâine, cereale, paste, orez), '
      '"other" (orice altceva). '
      'Valorile nutriționale sunt per 100g/100ml. '
      'Pune null pentru orice câmp care nu poate fi citit sau dedus.';

  Future<NutritionalData?> extractFromImage(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'Cheia API Gemini lipsește. Rulează cu --dart-define=GEMINI_API_KEY=...');
    }

    try {
      final base64Image = base64Encode(imageBytes);

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': _detectMime(imageBytes),
                  'data': base64Image,
                }
              },
              {'text': _prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0,
        }
      });

      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Cheia API Gemini nu este validă sau a expirat.');
      } else if (response.statusCode == 429) {
        throw Exception('Limita de cereri Gemini a fost atinsă.');
      } else if (response.statusCode != 200) {
        throw Exception(
            'Serviciul OCR nu este disponibil (${response.statusCode}).');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String?;
      if (text == null) return null;

      final cleanText =
          text.replaceAll('```json', '').replaceAll('```', '').trim();

      final data = jsonDecode(cleanText) as Map<String, dynamic>;

      return NutritionalData(
        name: (data['name'] as String?)?.trim(),
        brand: (data['brand'] as String?)?.trim(),
        quantity: (data['quantity'] as num?)?.toDouble(),
        unit: _normalizeUnit(data['unit'] as String?),
        category: _normalizeCategory(data['category'] as String?),
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

  String _detectMime(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  String? _normalizeUnit(String? raw) {
    if (raw == null) return null;
    final u = raw.trim().toLowerCase();
    switch (u) {
      case 'g':
      case 'gr':
      case 'gram':
      case 'grame':
        return 'g';
      case 'kg':
      case 'kilogram':
      case 'kilograme':
        return 'kg';
      case 'ml':
      case 'mililitri':
        return 'ml';
      case 'l':
      case 'litru':
      case 'litri':
        return 'L';
      case 'buc':
      case 'bucata':
      case 'bucată':
      case 'bucati':
      case 'bucăți':
      case 'pcs':
        return 'buc';
      default:
        return _allowedUnits.contains(raw) ? raw : null;
    }
  }

  String? _normalizeCategory(String? raw) {
    if (raw == null) return null;
    final c = raw.trim().toLowerCase();
    return _allowedCategories.contains(c) ? c : null;
  }
}
