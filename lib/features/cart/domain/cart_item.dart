import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String barcode;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final double? calories;
  final double? sugar;
  final double? fat;
  final bool isUnknown;
  final DateTime addedAt;

  const CartItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.calories,
    this.sugar,
    this.fat,
    required this.isUnknown,
    required this.addedAt,
  });

  factory CartItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CartItem(
      id: doc.id,
      barcode: data['barcode'] as String,
      name: data['name'] as String,
      category: data['category'] as String? ?? 'other',
      quantity: (data['quantity'] as num).toDouble(),
      unit: data['unit'] as String? ?? 'buc',
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      calories: (data['calories'] as num?)?.toDouble(),
      sugar: (data['sugar'] as num?)?.toDouble(),
      fat: (data['fat'] as num?)?.toDouble(),
      isUnknown: data['isUnknown'] as bool? ?? false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'barcode': barcode,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
        if (calories != null) 'calories': calories,
        if (sugar != null) 'sugar': sugar,
        if (fat != null) 'fat': fat,
        'isUnknown': isUnknown,
        'addedAt': FieldValue.serverTimestamp(),
      };

  CartItem copyWith({
    String? id,
    String? barcode,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    Object? expiryDate = _sentinel,
    double? calories,
    double? sugar,
    double? fat,
    bool? isUnknown,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate == _sentinel
          ? this.expiryDate
          : expiryDate as DateTime?,
      calories: calories ?? this.calories,
      sugar: sugar ?? this.sugar,
      fat: fat ?? this.fat,
      isUnknown: isUnknown ?? this.isUnknown,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

// Sentinel pentru a distinge null explicit de "nu schimba" în copyWith
const _sentinel = Object();
