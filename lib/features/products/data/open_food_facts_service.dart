import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OffProduct {
  final String name;
  final String? brand;
  final String? quantity;
  final String? nutriscoreGrade;
  final int? novaGroup;
  final String? ingredientsText;
  final List<String>? allergens;
  final String? imageUrl;
  final String? barcode;
  final String? category;
  final double? calories;
  final double? sugar;
  final double? fat;
  final String source;

  const OffProduct({
    required this.name,
    this.brand,
    this.quantity,
    this.nutriscoreGrade,
    this.novaGroup,
    this.ingredientsText,
    this.allergens,
    this.imageUrl,
    this.barcode,
    this.category,
    this.calories,
    this.sugar,
    this.fat,
    required this.source,
  });

  Map<String, dynamic> toPrefillMap() => {
        'name': name,
        if (brand != null) 'brand': brand,
        if (barcode != null) 'barcode': barcode,
        if (category != null) 'category': category,
        if (calories != null) 'calories': calories,
        if (sugar != null) 'sugar': sugar,
        if (fat != null) 'fat': fat,
        if (nutriscoreGrade != null) 'nutriscoreGrade': nutriscoreGrade,
        if (novaGroup != null) 'novaGroup': novaGroup,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'source': source,
      };
}

class OpenFoodFactsService {
  static const _baseUrl = 'world.openfoodfacts.org';
  static const _timeout = Duration(seconds: 5);

  Future<OffProduct?> fetchByBarcode(String barcode) async {
    Map<String, dynamic>? data;
    try {
      data = await _getJson(
        Uri.https(_baseUrl, '/api/v0/product/$barcode.json'),
      );
    } catch (_) {
      // retry once
      try {
        data = await _getJson(
          Uri.https(_baseUrl, '/api/v0/product/$barcode.json'),
        );
      } catch (_) {
        return null;
      }
    }
    if (data == null) return null;
    if ((data['status'] as int?) != 1) return null;
    final product = data['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    return _parseProduct(product, barcode, 'open_food_facts');
  }

  Future<List<OffProduct>> search(String query) async {
    try {
      final uri = Uri.https(_baseUrl, '/cgi/search.pl', {
        'search_terms': query,
        'json': '1',
        'page_size': '5',
        'lc': 'ro',
      });
      final data = await _getJson(uri);
      if (data == null) return [];
      final products = data['products'] as List<dynamic>? ?? [];
      return products
          .cast<Map<String, dynamic>>()
          .map((p) => _parseProduct(p, p['code'] as String?, 'open_food_facts_search'))
          .whereType<OffProduct>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    return json.decode(response.body) as Map<String, dynamic>;
  }

  OffProduct? _parseProduct(
    Map<String, dynamic> p,
    String? barcode,
    String source,
  ) {
    final name = (p['product_name_ro'] as String?)?.trim() ??
        (p['product_name'] as String?)?.trim() ??
        '';
    if (name.isEmpty) return null;

    final nutriments = p['nutriments'] as Map<String, dynamic>?;
    final nutriGrade = (p['nutrition_grades'] as String?)?.toLowerCase();

    return OffProduct(
      name: name,
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      quantity: p['quantity'] as String?,
      nutriscoreGrade: nutriGrade,
      novaGroup: (p['nova_group'] as num?)?.toInt(),
      ingredientsText: (p['ingredients_text_ro'] as String?)?.trim() ??
          (p['ingredients_text'] as String?)?.trim(),
      allergens: (p['allergens_tags'] as List<dynamic>?)?.cast<String>(),
      imageUrl: p['image_front_url'] as String?,
      barcode: barcode,
      category: _guessCategory(p),
      calories: (nutriments?['energy-kcal_100g'] as num?)?.toDouble(),
      sugar: (nutriments?['sugars_100g'] as num?)?.toDouble(),
      fat: (nutriments?['fat_100g'] as num?)?.toDouble(),
      source: source,
    );
  }

  String _guessCategory(Map<String, dynamic> p) {
    final tags = (p['categories_tags'] as List<dynamic>?)
            ?.cast<String>()
            .join(' ')
            .toLowerCase() ??
        '';
    if (tags.contains('dairy') ||
        tags.contains('milk') ||
        tags.contains('cheese') ||
        tags.contains('egg') ||
        tags.contains('yogurt')) {
      return 'lactate_oua';
    }
    if (tags.contains('meat') ||
        tags.contains('poultry') ||
        tags.contains('charcuterie')) {
      return 'carne_mezeluri';
    }
    if (tags.contains('fish') || tags.contains('seafood')) {
      return 'peste';
    }
    if (tags.contains('fresh-fruit') ||
        tags.contains('fresh-vegetable') ||
        tags.contains('en:fruits') ||
        tags.contains('en:vegetables')) {
      return 'fructe_legume';
    }
    if (tags.contains('bread') ||
        tags.contains('pastry') ||
        tags.contains('bakery')) {
      return 'panificatie';
    }
    if (tags.contains('cereal') ||
        tags.contains('pasta') ||
        tags.contains('legume')) {
      return 'cereale_paste';
    }
    if (tags.contains('canned') ||
        tags.contains('preserved') ||
        tags.contains('pickle')) {
      return 'conserve';
    }
    if (tags.contains('snack') ||
        tags.contains('chocolate') ||
        tags.contains('candy') ||
        tags.contains('sweet') ||
        tags.contains('biscuit')) {
      return 'snacks';
    }
    if (tags.contains('beverage') ||
        tags.contains('drink') ||
        tags.contains('juice') ||
        tags.contains('water') ||
        tags.contains('soda')) {
      return 'bauturi';
    }
    if (tags.contains('condiment') ||
        tags.contains('sauce') ||
        tags.contains('oil') ||
        tags.contains('spice') ||
        tags.contains('seasoning')) {
      return 'condimente';
    }
    if (tags.contains('frozen')) {
      return 'congelate';
    }
    return 'altele';
  }
}
