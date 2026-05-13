import 'package:cloud_firestore/cloud_firestore.dart';

class ProductInfo {
  final String ean;
  final String name;
  final String category;
  final int? defaultExpiryDays;
  final String? nutriScore;
  final String? brand;
  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final double? sugar;
  final double? salt;
  final String contributedBy;
  final DateTime contributedAt;
  final int verifiedCount;

  const ProductInfo({
    required this.ean,
    required this.name,
    required this.category,
    this.defaultExpiryDays,
    this.nutriScore,
    this.brand,
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.sugar,
    this.salt,
    required this.contributedBy,
    required this.contributedAt,
    required this.verifiedCount,
  });

  factory ProductInfo.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ProductInfo(
      ean: d['ean'] as String? ?? doc.id,
      name: d['name'] as String? ?? '',
      category: d['category'] as String? ?? 'other',
      defaultExpiryDays: d['defaultExpiryDays'] as int?,
      nutriScore: d['nutriScore'] as String?,
      brand: d['brand'] as String?,
      calories: (d['calories'] as num?)?.toDouble(),
      protein: (d['protein'] as num?)?.toDouble(),
      fat: (d['fat'] as num?)?.toDouble(),
      carbs: (d['carbs'] as num?)?.toDouble(),
      sugar: (d['sugar'] as num?)?.toDouble(),
      salt: (d['salt'] as num?)?.toDouble(),
      contributedBy: d['contributedBy'] as String? ?? '',
      contributedAt:
          (d['contributedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedCount: d['verifiedCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ean': ean,
        'name': name,
        'category': category,
        if (defaultExpiryDays != null) 'defaultExpiryDays': defaultExpiryDays,
        if (nutriScore != null) 'nutriScore': nutriScore,
        if (brand != null) 'brand': brand,
        if (calories != null) 'calories': calories,
        if (protein != null) 'protein': protein,
        if (fat != null) 'fat': fat,
        if (carbs != null) 'carbs': carbs,
        if (sugar != null) 'sugar': sugar,
        if (salt != null) 'salt': salt,
        'contributedBy': contributedBy,
        'contributedAt': FieldValue.serverTimestamp(),
        'verifiedCount': verifiedCount,
      };

  factory ProductInfo.fromDemoProduct(
      String ean, Map<String, dynamic> demo) {
    return ProductInfo(
      ean: ean,
      name: demo['name'] as String? ?? '',
      category: demo['category'] as String? ?? 'other',
      calories: (demo['calories'] as num?)?.toDouble(),
      sugar: (demo['sugar'] as num?)?.toDouble(),
      fat: (demo['fat'] as num?)?.toDouble(),
      contributedBy: 'demo',
      contributedAt: DateTime.now(),
      verifiedCount: 1,
    );
  }

  ProductInfo copyWith({
    String? ean,
    String? name,
    String? category,
    int? defaultExpiryDays,
    String? nutriScore,
    String? brand,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? sugar,
    double? salt,
    String? contributedBy,
    DateTime? contributedAt,
    int? verifiedCount,
  }) =>
      ProductInfo(
        ean: ean ?? this.ean,
        name: name ?? this.name,
        category: category ?? this.category,
        defaultExpiryDays: defaultExpiryDays ?? this.defaultExpiryDays,
        nutriScore: nutriScore ?? this.nutriScore,
        brand: brand ?? this.brand,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        fat: fat ?? this.fat,
        carbs: carbs ?? this.carbs,
        sugar: sugar ?? this.sugar,
        salt: salt ?? this.salt,
        contributedBy: contributedBy ?? this.contributedBy,
        contributedAt: contributedAt ?? this.contributedAt,
        verifiedCount: verifiedCount ?? this.verifiedCount,
      );
}
