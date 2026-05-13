import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItem {
  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final bool checked;
  final String source; // "ai" | "manual" | "meal_plan"
  final String category; // "dairy" | "meat" | "vegetables" | "fruits" | "grains" | "other"
  final DateTime addedAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    required this.checked,
    required this.source,
    this.category = 'other',
    required this.addedAt,
  });

  static String detectCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('lapte') || n.contains('iaurt') || n.contains('brânz') ||
        n.contains('branz') || n.contains('smântân') || n.contains('smant') ||
        n.contains('unt') || n.contains('frișcă') || n.contains('frisca') ||
        n.contains('telemea') || n.contains('cașcaval') || n.contains('cascaval') ||
        n.contains('cheese') || n.contains('cream')) {
      return 'dairy';
    }
    if (n.contains('pui') || n.contains('carne') || n.contains('șuncă') ||
        n.contains('sunca') || n.contains('bacon') || n.contains('cârnați') ||
        n.contains('carnati') || n.contains('porc') || n.contains('vită') ||
        n.contains('vita') || n.contains('miel') || n.contains('salam') ||
        n.contains('piept') || n.contains('mezel')) {
      return 'meat';
    }
    if (n.contains('mere') || n.contains('măr') || n.contains('banana') ||
        n.contains('portocal') || n.contains('struguri') || n.contains('piersic') ||
        n.contains('căpșun') || n.contains('capsun') || n.contains('pepene') ||
        n.contains('kiwi') || n.contains('fruct')) {
      return 'fruits';
    }
    if (n.contains('morcov') || n.contains('roșii') || n.contains('rosii') ||
        n.contains('tomat') || n.contains('salat') || n.contains('castr') ||
        n.contains('ardei') || n.contains('ceap') || n.contains('cartofi') ||
        n.contains('spanac') || n.contains('varz') || n.contains('legum') ||
        n.contains('brocoli') || n.contains('conopid')) {
      return 'vegetables';
    }
    if (n.contains('pâine') || n.contains('paine') || n.contains('paste') ||
        n.contains('orez') || n.contains('făin') || n.contains('fain') ||
        n.contains('mălai') || n.contains('malai') || n.contains('covrigi') ||
        n.contains('biscuiți') || n.contains('biscuiti') || n.contains('cereale')) {
      return 'grains';
    }
    return 'other';
  }

  factory ShoppingItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final name = data['name'] as String;
    final source = data['source'] as String? ?? 'manual';
    final storedCategory = data['category'] as String?;
    final category = storedCategory ??
        (source == 'ai' || source == 'meal_plan'
            ? detectCategory(name)
            : 'other');
    return ShoppingItem(
      id: doc.id,
      name: name,
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
      checked: data['checked'] as bool? ?? false,
      source: source,
      category: category,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        'checked': checked,
        'source': source,
        'category': category,
        'addedAt': FieldValue.serverTimestamp(),
      };

  ShoppingItem copyWith({bool? checked}) => ShoppingItem(
        id: id,
        name: name,
        quantity: quantity,
        unit: unit,
        checked: checked ?? this.checked,
        source: source,
        category: category,
        addedAt: addedAt,
      );
}
