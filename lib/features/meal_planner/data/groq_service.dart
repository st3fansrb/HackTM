import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../features/auth/domain/user_preferences.dart';
import '../../../features/auth/domain/user_profile.dart';
import '../../pantry/domain/food_item.dart';
import 'chat_message.dart';
import 'preferences_extractor.dart';

class GroqService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _model = 'llama-3.3-70b-versatile';
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static List<Map<String, dynamic>>? _cachedRecipes;

  static const _systemPromptBase =
      'Ești Frigo AI, asistentul inteligent pentru reducerea risipei alimentare.\n'
      'Răspunde ÎNTOTDEAUNA în română.\n'
      'Când sugerezi rețete, prioritizează ingredientele care expiră cel mai curând.\n'
      "Când identifici produse lipsă dintr-o rețetă, listează-le pe linii separate prefixate cu '🛒 Lipsește:'.\n"
      'Dacă pantry-ul e gol, sugerează ce ar trebui cumpărat pentru o săptămână normală.\n'
      'Când userul întreabă ce să gătească, sugerează ÎNTOTDEAUNA o singură rețetă '
      'concretă — nu lista de opțiuni, nu "poți face X sau Y". '
      'O rețetă, completă, cu ingrediente și pași.\n'
      'Pentru răspunsuri care NU sunt rețete: fii concis, maxim 3-4 rânduri, text simplu fără markdown.\n'
      'Când userul cere o rețetă, răspunde ÎNTOTDEAUNA în acest format exact:\n\n'
      '🍽️ [NUME REȚETĂ]\n\n'
      '⏱️ Timp: X minute | 👥 Porții: X\n\n'
      '📋 Ingrediente:\n'
      '- X cantitate unitate ingredient\n\n'
      '👨‍🍳 Mod de preparare:\n'
      '1. Pas 1\n'
      '2. Pas 2\n\n'
      'Nu devia de la acest format când e cerută o rețetă.';

  Future<List<Map<String, dynamic>>> _loadRecipes() async {
    if (_cachedRecipes != null) return _cachedRecipes!;
    final raw = await rootBundle.loadString('assets/data/recipes_database.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final all = <Map<String, dynamic>>[];
    for (final category in json.values) {
      if (category is List) all.addAll(category.cast<Map<String, dynamic>>());
    }
    _cachedRecipes = all;
    return all;
  }

  List<Map<String, dynamic>> _filterRecipes(
    List<Map<String, dynamic>> all,
    List<FoodItem> pantryItems,
    ExtractedPreferences? prefs, {
    List<String> expiringIngredients = const [],
    String? craving,
  }) {
    final pantryNames = pantryItems.map((i) => i.name.toLowerCase()).toList();
    final disliked = prefs?.disliked.map((d) => d.toLowerCase()).toList() ?? [];
    final liked = prefs?.liked.map((l) => l.toLowerCase()).toList() ?? [];
    final cravingWords = (craving ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();
    final expiringLower = expiringIngredients.map((e) => e.toLowerCase()).toList();

    bool hasDisliked(List<dynamic> ings) => ings.any(
          (ing) => disliked.any((d) => ing.toString().toLowerCase().contains(d)),
        );

    final withScores = all
        .where((r) => !hasDisliked(r['ingredients'] as List))
        .map((r) {
          final ings = (r['ingredients'] as List)
              .map((i) => i.toString().toLowerCase())
              .toList();
          final name = (r['name'] as String).toLowerCase();
          final total = ings.length;

          // scor pantry: 0.0–0.3
          final matched = ings
              .where((ing) =>
                  pantryNames.any((p) => ing.contains(p) || p.contains(ing)))
              .length;
          final pantryScore = total > 0 ? (matched / total) * 0.3 : 0.0;

          // bonus poftă: +1.0
          double cravingBonus = 0.0;
          if (cravingWords.isNotEmpty &&
              (cravingWords.any((w) => name.contains(w)) ||
               cravingWords.any((w) => ings.any((ing) => ing.contains(w))))) {
            cravingBonus = 1.0;
          }

          // bonus expirare: +0.6
          final expiryBonus = expiringLower.any((exp) =>
                  ings.any((ing) => ing.contains(exp) || exp.contains(ing)))
              ? 0.6
              : 0.0;

          // bonus liked: +0.4
          final likedBonus =
              liked.any((l) => ings.any((ing) => ing.contains(l))) ? 0.4 : 0.0;

          return (
            recipe: r,
            score: pantryScore + cravingBonus + expiryBonus + likedBonus,
            pantryScore: pantryScore,
            cravingBonus: cravingBonus,
            expiryBonus: expiryBonus,
          );
        })
        .toList();

    // include doar rețete cu cel puțin un criteriu de relevanță
    final relevant = withScores
        .where((e) => e.pantryScore > 0 || e.cravingBonus > 0 || e.expiryBonus > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final result = relevant.map((e) => e.recipe).toList();

    // fallback: completează până la 8 cu rețete care au scor pantry > 0
    if (result.length < 6) {
      final extras = withScores
          .where((e) => e.pantryScore > 0 && !result.contains(e.recipe))
          .toList()
        ..sort((a, b) => b.pantryScore.compareTo(a.pantryScore));
      for (final e in extras) {
        if (result.length >= 8) break;
        result.add(e.recipe);
      }
    }

    return result;
  }

  String _buildRecipeContext(List<Map<String, dynamic>> recipes) {
    final sb = StringBuffer('Baza de date rețete (alege EXCLUSIV din această listă):\n');
    for (final r in recipes) {
      final ingredients = (r['ingredients'] as List).join(', ');
      sb.writeln('[${r['type']}] ${r['name']} (${r['prep_time_minutes']} min): $ingredients');
    }
    return sb.toString();
  }

  String _buildProfileContext(
    UserProfile profile, [
    ExtractedPreferences? prefs,
    UserPreferences? userPrefs,
  ]) {
    final hasPrefs = prefs != null &&
        (prefs.disliked.isNotEmpty ||
            prefs.liked.isNotEmpty ||
            prefs.dietary.isNotEmpty);
    final hasUserPrefs = userPrefs != null && !userPrefs.isEmpty;

    final userPrefsBlock = hasUserPrefs
        ? '\n\nPREFERINȚELE UTILIZATORULUI (respectă ÎNTOTDEAUNA fără excepție):\n'
            '${userPrefs.allergies.isNotEmpty ? "Alergii: ${userPrefs.allergies.join(', ')}\n" : ""}'
            '${userPrefs.dietaryRestrictions.isNotEmpty ? "Restricții dietetice: ${userPrefs.dietaryRestrictions.join(', ')}\n" : ""}'
            '${userPrefs.dislikedIngredients.isNotEmpty ? "Ingrediente evitate: ${userPrefs.dislikedIngredients.join(', ')}\n" : ""}'
            '${userPrefs.preferredCuisines.isNotEmpty ? "Bucătării preferate: ${userPrefs.preferredCuisines.join(', ')}\n" : ""}'
            'Nu sugera NICIODATĂ alimente sau rețete care conțin ingredientele din alergii sau restricții dietetice.'
        : '';

    return 'Profil utilizator:\n'
        'Nume: ${profile.displayName}\n'
        'Persoane în gospodărie: ${profile.householdSize}\n'
        'Dietă: ${profile.dietType}\n'
        'Alergii: ${profile.allergies.isEmpty ? 'niciuna' : profile.allergies.join(', ')}\n'
        'Condimente disponibile: ${profile.ownedCondiments.isEmpty ? 'nespecificate' : profile.ownedCondiments.join(', ')}'
        '${prefs != null && prefs.disliked.isNotEmpty ? '\nAlimente nedorite: ${prefs.disliked.join(", ")}' : ''}'
        '${prefs != null && prefs.liked.isNotEmpty ? '\nAlimente preferate: ${prefs.liked.join(", ")}' : ''}'
        '${prefs != null && prefs.dietary.isNotEmpty ? '\nRestricții suplimentare: ${prefs.dietary.join(", ")}' : ''}'
        '${hasPrefs ? '\n\nCând interpretezi preferințele utilizatorului, aplică matching semantic larg:\n'
            '- Un ingredient din lista de disliked/liked acoperă toate variantele sale: forme flexionate, derivate, compuse și produse asociate.\n'
            '- Exemple: "ardei" → "boia de ardei", "ardei iute", "ardeiul", "ardei roșu", "ardei kapia"; "lactate" → "lapte", "smântână", "unt", "iaurt", "brânză"; "porc" → "costiță", "slănină", "carne de porc", "kaiser".\n'
            '- Dacă un ingredient din rețetă este semantic legat de un disliked ingredient, tratează rețeta ca nepotrivită.\n'
            '- Aplică aceeași logică și pentru dietaryRestrictions.' : ''}'
        '$userPrefsBlock';
  }

  String _buildPantryContext(List<FoodItem> pantryItems) {
    final sorted = [...pantryItems]
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
    return sorted
        .map((i) =>
            '${i.name}: ${i.quantity}${i.unit}, expiră în ${i.daysUntilExpiry} zile')
        .join('\n');
  }

  Future<String> sendMessage(
    List<ChatMessage> history,
    List<FoodItem> pantryItems, {
    UserProfile? profile,
    ExtractedPreferences? prefs,
    UserPreferences? userPrefs,
  }) async {
    final pantryContext = _buildPantryContext(pantryItems);
    final systemWithContext = '$_systemPromptBase\n\n'
        '${profile != null ? "${_buildProfileContext(profile, prefs, userPrefs)}\n\n" : ""}'
        'Pantry utilizator:\n$pantryContext';

    final recent =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    final messages = [
      {'role': 'system', 'content': systemWithContext},
      ...recent.map((m) => {'role': m.role, 'content': m.content}),
    ];

    return _callApi(messages, maxTokens: 1200);
  }

  Future<String> predictExpiry(
    List<FoodItem> pantryItems, {
    UserProfile? profile,
    ExtractedPreferences? prefs,
  }) async {
    final expiringSoon = pantryItems
        .where((i) => i.daysUntilExpiry < 5)
        .toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    if (expiringSoon.isEmpty) {
      return 'Felicitări! 🎉 Nu ai produse care expiră în curând. '
          'Pantry-ul tău e în formă bună! Pot să te ajut cu idei de rețete?';
    }

    final pantryContext = _buildPantryContext(pantryItems);
    final expiryContext = expiringSoon
        .map((i) =>
            '${i.name}: ${i.quantity}${i.unit}, expiră în ${i.daysUntilExpiry} zile')
        .join('\n');

    final systemWithContext = '$_systemPromptBase\n\n'
        '${profile != null ? "${_buildProfileContext(profile, prefs)}\n\n" : ""}'
        'Pantry complet:\n$pantryContext';

    final messages = [
      {'role': 'system', 'content': systemWithContext},
      {
        'role': 'user',
        'content':
            'Produse care expiră curând:\n$expiryContext\n\nÎntr-un răspuns scurt de 2-3 rânduri: ce expiră cel mai curând și ce ar trebui consumat azi?',
      },
    ];

    return _callApi(messages, maxTokens: 200);
  }

  Future<String> generateWelcome(
    List<FoodItem> pantryItems, {
    UserProfile? profile,
    ExtractedPreferences? prefs,
    UserPreferences? userPrefs,
  }) async {
    final emptyPantry = pantryItems.isEmpty;
    final expiringSoon = pantryItems
        .where((i) => i.daysUntilExpiry < 3 && i.daysUntilExpiry >= 0)
        .toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    final expiringNames = prefs != null && prefs.disliked.isNotEmpty
        ? expiringSoon
            .where((i) =>
                !prefs.disliked.any((d) => i.name.toLowerCase().contains(d.toLowerCase())))
            .map((i) => i.name)
            .toList()
        : expiringSoon.map((i) => i.name).toList();

    String userContext;
    if (emptyPantry) {
      userContext = 'Pantry utilizator: gol (niciun produs)';
    } else if (expiringNames.isNotEmpty) {
      userContext =
          'Pantry utilizator:\n${_buildPantryContext(pantryItems)}\n\n'
          'Produse care expiră în mai puțin de 3 zile: ${expiringNames.join(", ")}';
    } else if (prefs != null && prefs.disliked.isNotEmpty) {
      userContext =
          'Pantry utilizator:\n${_buildPantryContext(pantryItems)}\n'
          'Utilizator nu își dorește: ${prefs.disliked.join(", ")}';
    } else {
      userContext = 'Pantry utilizator:\n${_buildPantryContext(pantryItems)}';
    }

    final welcomeSystem =
        'Ești Frigo AI. Generează un mesaj de bun venit personalizat, scurt '
        '(maxim 150 tokeni), în română, bazat pe pantry-ul și preferințele '
        'utilizatorului. Fii prietenos și concret. Fără markdown.';

    final messages = [
      {'role': 'system', 'content': welcomeSystem},
      {'role': 'user', 'content': userContext},
    ];

    return _callApi(messages, maxTokens: 200);
  }

  Future<String> generateShoppingPlan(
    List<FoodItem> pantryItems, {
    UserProfile? profile,
    ExtractedPreferences? prefs,
  }) async {
    final pantryContext = _buildPantryContext(pantryItems);
    const shoppingPlanPrompt =
        'Ești Frigo AI. Analizezi pantry-ul utilizatorului și sugerezi 3 rețete posibile.\n'
        'Sugerează DOAR rețete reale și cunoscute cu combinații culinare corecte.\n'
        'Nu combina ingrediente care nu se potrivesc gastronomic (ex: ayran cu lapte).\n'
        'Dacă ingredientele din pantry nu sunt suficiente pentru 3 rețete coerente,\n'
        'sugerează rețete cu ingrediente lipsă — nu inventa combinații absurde.\n'
        'Respectă preferințele utilizatorului: nu sugera alimente din lista disliked.\n'
        'Pentru fiecare rețetă specifică exact ce ingrediente lipsesc din pantry.\n'
        'Răspunde DOAR cu JSON valid, fără text explicativ, fără markdown, fără backticks.\n'
        'Format exact:\n'
        '{"retete": [{"nume": "Nume rețetă", "ingrediente_lipsa": ["ingredient1"]}]}\n'
        'Dacă o rețetă se poate face complet din pantry, ingrediente_lipsa este [].\n'
        'Maxim 3 rețete. Potrivite pentru dieta și profilul utilizatorului.';

    final systemWithContext = '$shoppingPlanPrompt\n\n'
        '${profile != null ? "${_buildProfileContext(profile, prefs)}\n\n" : ""}'
        'Pantry utilizator:\n$pantryContext';

    final messages = [
      {'role': 'system', 'content': systemWithContext},
      {'role': 'user', 'content': 'Sugerează 3 rețete pe baza pantry-ului meu.'},
    ];

    return _callApi(messages, maxTokens: 400);
  }

  Future<String> generateWeeklyPlan(
    List<FoodItem> pantryItems, {
    required int days,
    required int mealsPerDay,
    String? craving,
    UserProfile? profile,
    ExtractedPreferences? prefs,
  }) async {
    final pantryContext = _buildPantryContext(pantryItems);
    const allDays = ['Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică'];
    final selectedDays = allDays.sublist(0, days);
    final cravingNote = (craving != null && craving.isNotEmpty)
        ? 'Preferința utilizatorului pentru această săptămână: "$craving".\n'
        : '';

    final allRecipes = await _loadRecipes();
    final expiringIngredients = pantryItems
        .where((i) => i.daysUntilExpiry < 3)
        .map((i) => i.name.toLowerCase())
        .toList();
    final filtered = _filterRecipes(
      allRecipes,
      pantryItems,
      prefs,
      expiringIngredients: expiringIngredients,
      craving: craving,
    );
    final recipeContext = _buildRecipeContext(filtered);

    final prompt =
        'Ești Frigo AI. Creează un plan de mese pentru $days zile cu $mealsPerDay mese/zi.\n'
        '$cravingNote'
        'Tipuri de mese în funcție de numărul per zi:\n'
        '- 1 masă/zi: fel principal complet (prânz)\n'
        '- 2 mese/zi: Masa 1 = prânz consistent, Masa 2 = cină mai ușoară\n'
        '- 3 mese/zi: Masa 1 = mic dejun simplu (ouă, iaurt, pâine), Masa 2 = prânz, Masa 3 = cină\n'
        'Prioritizează ingredientele din pantry care expiră cel mai curând.\n'
        'Respectă preferințele și restricțiile utilizatorului.\n'
        'Alege EXCLUSIV rețetele din lista furnizată mai jos. Nu inventa rețete care nu se află în acea listă.\n'
        'REGULI OBLIGATORII pentru fiecare masă:\n'
        '- Fiecare masă trebuie să fie o rețetă completă cu minim 2-3 ingrediente compatibile.\n'
        '- Nu combina ingrediente incompatibile într-o singură masă (ex: couscous cu lapte, cartofi prăjiți singuri ca masă principală, paste cu brânză telemea și maioneză).\n'
        '- Fiecare masă trebuie să aibă sens culinar: proteină + garnitură, supă/ciorbă completă, sau fel unic tradițional.\n'
        '- Exemple de mese corecte: ciorbă de legume, mușchi de porc cu cartofi la cuptor, omletă cu legume, fasole bătută cu ceapă, mămăligă cu brânză și smântână.\n'
        '- NU sugera: un singur ingredient ca masă, combinații inexistente gastronomic, mese fără sens culinar.\n'
        'REGULI SUPLIMENTARE OBLIGATORII:\n'
        '- Nu repeta același ingredient principal în mai mult de 3 mese din același plan.\n'
        '- Condimentele de bază (ulei, sare, piper, oțet) NU se trec în ingredients_missing — se consideră că utilizatorul le are mereu.\n'
        '- Masa de prânz trebuie să fie consistentă (fel principal cu proteină sau supă/ciorbă completă). Masa de seară poate fi mai ușoară dar trebuie să fie o masă reală, nu o gustare.\n'
        '- Nu repeta aceeași rețetă în două zile diferite ale săptămânii. Fiecare zi trebuie să aibă rețete unice față de celelalte zile.\n'
        '- Fiecare element din ingredients_missing și ingredients_available TREBUIE să includă cantitatea și unitatea de măsură. Format obligatoriu: "{cantitate} {unitate} {nume}". Exemple corecte: "200g făină", "1L lapte", "3 ouă", "500g piept de pui". NU include niciodată un ingredient fără cantitate.\n'
        '- ingredients_missing și ingredients_available conțin DOAR numele ingredientului cu cantitate, câte un singur ingredient per element. NU include explicații, sugestii, alternative sau text descriptiv (ex: "sau alte ingrediente", "dacă doriți", "pentru aromă", "după gust"). Fiecare element = exact un ingredient.\n'
        "Pentru fiecare rețetă, câmpul 'instructions' este OBLIGATORIU și trebuie "
        'să conțină minim 3 pași detaliați de preparare, scrisi în română, '
        'separați prin newline. Nu lăsa instructions gol sau null niciodată.\n'
        'Răspunde DOAR cu JSON valid, fără text explicativ, fără markdown, fără backticks.\n'
        'Zilele planului: ${selectedDays.join(", ")}.\n'
        'Format exact:\n'
        '{"plan":[{"day":"Luni","meals":[{"name":"Rețetă","ingredients_available":["200g ing1"],"ingredients_missing":["3 buc ing2"],"instructions":"1. Primul pas detaliat.\\n2. Al doilea pas detaliat.\\n3. Al treilea pas detaliat."}]}]}\n'
        'Fiecare zi trebuie să aibă exact $mealsPerDay mese.';

    final systemWithContext = '$prompt\n\n'
        '$recipeContext\n'
        '${profile != null ? "${_buildProfileContext(profile, prefs)}\n\n" : ""}'
        'Pantry utilizator:\n$pantryContext';

    final messages = [
      {'role': 'system', 'content': systemWithContext},
      {
        'role': 'user',
        'content': 'Generează planul pentru $days zile, $mealsPerDay mese/zi.',
      },
    ];

    return _callApi(messages, maxTokens: 2000);
  }

  Future<String> regenerateSingleMeal(
    List<FoodItem> pantryItems, {
    required String dayName,
    required List<String> existingRecipeNames,
    UserProfile? profile,
    ExtractedPreferences? prefs,
  }) async {
    final pantryContext = _buildPantryContext(pantryItems);
    final existing = existingRecipeNames.isEmpty
        ? '(niciuna)'
        : existingRecipeNames.map((n) => '- $n').join('\n');

    final prompt =
        'Ești Frigo AI. Sugerează O SINGURĂ rețetă nouă pentru ziua $dayName.\n'
        'Rețeta trebuie să fie DIFERITĂ de cele din lista de mai jos (nu repeta '
        'niciuna dintre ele):\n'
        '$existing\n'
        'Prioritizează ingredientele din pantry care expiră cel mai curând.\n'
        'Respectă preferințele și restricțiile utilizatorului.\n'
        'Rețeta trebuie să aibă sens culinar: proteină + garnitură, supă/ciorbă '
        'completă, sau fel unic tradițional. Minim 3 ingrediente compatibile.\n'
        'Condimentele de bază (ulei, sare, piper, oțet) se consideră deja '
        'deținute — nu le adăuga în ingrediente.\n'
        "Câmpul 'instructions' este OBLIGATORIU și trebuie să conțină minim 3 "
        'pași detaliați de preparare, scrisi în română, separați prin newline. '
        'Nu lăsa instructions gol sau null niciodată.\n'
        'Răspunde DOAR cu JSON valid, fără text explicativ, fără markdown, fără backticks.\n'
        'Format exact:\n'
        '{"name":"Nume rețetă","ingredients":[{"name":"ingredient","quantity":200,"unit":"g"}],'
        '"instructions":"1. Primul pas detaliat.\\n2. Al doilea pas detaliat.\\n3. Al treilea pas detaliat."}';

    final systemWithContext = '$prompt\n\n'
        '${profile != null ? "${_buildProfileContext(profile, prefs)}\n\n" : ""}'
        'Pantry utilizator:\n$pantryContext';

    final messages = [
      {'role': 'system', 'content': systemWithContext},
      {
        'role': 'user',
        'content': 'Generează o rețetă nouă pentru ziua $dayName.',
      },
    ];

    return _callApi(messages, maxTokens: 800);
  }

  Future<String> generateInstructions(
    String recipeName,
    List<String> ingredients,
  ) async {
    final messages = [
      {
        'role': 'system',
        'content':
            'Ești Frigo AI. Răspunde DOAR cu pașii ceruți, numerotați, în română. '
            'Fără introducere, fără concluzie, fără markdown.',
      },
      {
        'role': 'user',
        'content':
            'Scrie 4-5 pași detaliați de preparare pentru rețeta "$recipeName" '
            'cu ingredientele: ${ingredients.join(', ')}. Răspunde doar cu pașii, '
            'numerotați, în română.',
      },
    ];
    return _callApi(messages, maxTokens: 500);
  }

  Future<String> _callApi(
    List<Map<String, String>> messages, {
    required int maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': 0.4,
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Cheia API Groq nu este validă sau a expirat.');
    } else if (response.statusCode == 429) {
      throw Exception('Limita de cereri Groq a fost atinsă. Încearcă mai târziu.');
    } else if (response.statusCode != 200) {
      throw Exception('Serviciul AI nu este disponibil (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }
}
