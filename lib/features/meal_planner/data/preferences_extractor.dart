import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Rezultatul extragerii preferințelor alimentare.
class ExtractedPreferences {
  final List<String> disliked;
  final List<String> liked;
  final List<String> dietary;

  const ExtractedPreferences({
    this.disliked = const [],
    this.liked = const [],
    this.dietary = const [],
  });

  /// Serializează în JSON pentru stocare HTTP.
  Map<String, dynamic> toJson() => {
        'disliked': disliked,
        'liked': liked,
        'dietary': dietary,
      };

  /// Deserializare din JSON.
  factory ExtractedPreferences.fromJson(Map<String, dynamic> json) {
    return ExtractedPreferences(
      disliked: _toList(json['disliked']),
      liked: _toList(json['liked']),
      dietary: _toList(json['dietary']),
    );
  }

  /// Creează un [ExtractedPreferences] gol.
  factory ExtractedPreferences.empty() => const ExtractedPreferences();

  static List<String> _toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    return [value.toString()];
  }
}

/// Serviciu pentru extragerea preferințelor alimentare din mesaje text.
/// Face un apel Groq mic (60 tokeni) și parsează rezultatul ca JSON.
class PreferencesExtractor {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _model = 'llama-3.1-8b-instant';
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _prompt =
      'Extrage preferințele alimentare din mesajul utilizatorului. '
      'Returnează DOAR JSON valid, fără text explicativ, fără backticks. '
      'Format exact: {\"disliked\": [...], \"liked\": [...], \"dietary\": [...]}. '
      'Dacă un câmp e gol, folosește []. '
      'Fii specific cu numele alimentelor.';

  final FirebaseFirestore _firestore;

  PreferencesExtractor([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Extrage preferințele dintr-un mesaj de text.
  /// Pe eroare sau parse failure returnează întotdeauna un rezultat gol.
  Future<ExtractedPreferences> extract(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': _prompt},
            {'role': 'user', 'content': userMessage},
          ],
          'max_tokens': 60,
        }),
      );

      if (response.statusCode != 200) {
        return ExtractedPreferences.empty();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          (data['choices'][0]['message']['content'] as String).trim();
      return ExtractedPreferences.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return ExtractedPreferences.empty();
    }
  }

  /// Salvează preferințele în Firestore pentru [userId].
  /// Fiecare câmp face merge+dedup: se adaugă elemente noi fără a rescrie totul.
  Future<void> saveToFirestore(
    String userId,
    ExtractedPreferences prefs,
  ) async {
    final docRef = _firestore.doc('users/$userId');

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);

      final existing = doc.exists
          ? (doc.data()?['preferences'] as Map<String, dynamic>?)
              ?? <String, dynamic>{}
          : <String, dynamic>{};

      // Mergează fiecare câmp: existent + nou, deduplicat
      final dislikedKeys = existing.containsKey('disliked')
          ? (existing['disliked'] as List<dynamic>).cast<String>()
          : <String>[];
      final likedKeys = existing.containsKey('liked')
          ? (existing['liked'] as List<dynamic>).cast<String>()
          : <String>[];
      final dietaryKeys = existing.containsKey('dietary')
          ? (existing['dietary'] as List<dynamic>).cast<String>()
          : <String>[];

      final mergedDisliked =
          _deduplicate(dislikedKeys, prefs.disliked);
      final mergedLiked =
          _deduplicate(likedKeys, prefs.liked);
      final mergedDietary =
          _deduplicate(dietaryKeys, prefs.dietary);

      tx.set(docRef, {
        'preferences': {
          'disliked': mergedDisliked,
          'liked': mergedLiked,
          'dietary': mergedDietary,
        },
      }, SetOptions(merge: true));
    });
  }

  /// Deduplicează două liste: returnează elementele unice din combined.
  List<String> _deduplicate(List<String> existing, List<String> newItems) {
    final set = <String>{};
    set.addAll(existing);
    set.addAll(newItems);
    return set.toList();
  }
}

/// Provider Riverpod pentru [PreferencesExtractor].
final preferencesExtractorProvider =
    Provider<PreferencesExtractor>((_) => PreferencesExtractor());
