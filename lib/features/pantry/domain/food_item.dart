import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final String? brand;
  final String category;
  final double quantity;
  final String unit;
  final DateTime expiryDate;    // always set; for fresh items = estimatedExpiration
  final bool expirySkipped;     // true when user opted out of expiry (sentinel date stored)
  final String? barcode;
  final double? calories;
  final double? sugar;
  final double? fat;
  final String? nutriScore;
  final DateTime addedAt;

  // Extended fields
  final String storageLocation;  // 'temperatura_camerei' | 'frigider' | 'congelator'
  final String? source;          // 'open_food_facts' | 'frigo_db' | 'fresh_item' | ...
  final String? imageUrl;

  // Fresh produce fields
  final bool isFreshItem;
  final bool isBio;
  final int? initialRipeness;    // 0–4
  final int? baseShelfLifeDays;
  final DateTime? estimatedExpiration;
  final List<Map<String, dynamic>>? ripenessUpdates;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    this.expirySkipped = false,
    this.barcode,
    this.calories,
    this.sugar,
    this.fat,
    this.nutriScore,
    required this.addedAt,
    this.storageLocation = 'frigider',
    this.source,
    this.imageUrl,
    this.isFreshItem = false,
    this.isBio = false,
    this.initialRipeness,
    this.baseShelfLifeDays,
    this.estimatedExpiration,
    this.ripenessUpdates,
  });

  int get daysUntilExpiry {
    if (expirySkipped) return 9999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  static String _migrateCategory(String? raw) {
    switch (raw) {
      case 'dairy':
        return 'lactate_oua';
      case 'meat':
        return 'carne_mezeluri';
      case 'vegetables':
        return 'fructe_legume';
      case 'fruits':
        return 'fructe_legume';
      case 'grains':
        return 'cereale_paste';
      case 'other':
        return 'altele';
      case null:
        return 'altele';
      default:
        return raw;
    }
  }

  factory FoodItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FoodItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      brand: data['brand'] as String?,
      category: _migrateCategory(data['category'] as String?),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'] as String? ?? 'buc',
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 3650)),
      expirySkipped: data['expirySkipped'] as bool? ?? false,
      barcode: data['barcode'] as String?,
      calories: (data['calories'] as num?)?.toDouble(),
      sugar: (data['sugar'] as num?)?.toDouble(),
      fat: (data['fat'] as num?)?.toDouble(),
      nutriScore: data['nutriScore'] as String?,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storageLocation: data['storageLocation'] as String? ?? 'frigider',
      source: data['source'] as String?,
      imageUrl: data['imageUrl'] as String?,
      isFreshItem: data['isFreshItem'] as bool? ?? false,
      isBio: data['isBio'] as bool? ?? false,
      initialRipeness: (data['initialRipeness'] as num?)?.toInt(),
      baseShelfLifeDays: (data['baseShelfLifeDays'] as num?)?.toInt(),
      estimatedExpiration:
          (data['estimatedExpiration'] as Timestamp?)?.toDate(),
      ripenessUpdates: (data['ripenessUpdates'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        if (brand != null) 'brand': brand,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'expirySkipped': expirySkipped,
        if (barcode != null) 'barcode': barcode,
        if (calories != null) 'calories': calories,
        if (sugar != null) 'sugar': sugar,
        if (fat != null) 'fat': fat,
        if (nutriScore != null) 'nutriScore': nutriScore,
        'addedAt': FieldValue.serverTimestamp(),
        'storageLocation': storageLocation,
        if (source != null) 'source': source,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'isFreshItem': isFreshItem,
        'isBio': isBio,
        if (initialRipeness != null) 'initialRipeness': initialRipeness,
        if (baseShelfLifeDays != null) 'baseShelfLifeDays': baseShelfLifeDays,
        if (estimatedExpiration != null)
          'estimatedExpiration': Timestamp.fromDate(estimatedExpiration!),
        if (ripenessUpdates != null) 'ripenessUpdates': ripenessUpdates,
      };
}
