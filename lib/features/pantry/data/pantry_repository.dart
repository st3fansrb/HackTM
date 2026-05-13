import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/fresh_produce_data.dart';
import '../domain/food_item.dart';

class PantryRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users/$uid/pantry');

  Stream<List<FoodItem>> watchPantry(String uid) => _col(uid)
      .orderBy('expiryDate')
      .snapshots()
      .map((snap) => snap.docs.map((d) => FoodItem.fromFirestore(d)).toList());

  Future<void> addItem(String uid, FoodItem item) async {
    try {
      await _col(uid).add(item.toFirestore());
      await _db.doc('users/$uid').set(
        {'totalKgAdded': FieldValue.increment(_toKg(item.quantity, item.unit))},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[PantryRepository] addItem failed — code: ${e.code}, msg: ${e.message}',
      );
      rethrow;
    }
  }

  Future<void> deleteItemWithTracking(
    String uid,
    FoodItem item,
    bool wasConsumed,
  ) async {
    final isWaste = !item.expirySkipped &&
        (item.daysUntilExpiry < 0 ||
            (item.daysUntilExpiry == 0 && !wasConsumed));

    if (isWaste) {
      final kgEquivalent = _toKg(item.quantity, item.unit);
      final batch = _db.batch();
      batch.set(
        _db.doc('users/$uid/wasteHistory/${item.id}'),
        {
          'name': item.name,
          'kgWasted': kgEquivalent,
          'deletedAt': FieldValue.serverTimestamp(),
          'wasExpired': item.daysUntilExpiry <= 0,
        },
      );
      batch.set(
        _db.doc('users/$uid'),
        {'kgWasted': FieldValue.increment(kgEquivalent)},
        SetOptions(merge: true),
      );
      batch.delete(_col(uid).doc(item.id));
      await batch.commit();
    } else {
      await _col(uid).doc(item.id).delete();
    }
  }

  Future<void> updateItemQuantity(String uid, String itemId, double newQty) =>
      _col(uid).doc(itemId).update({'quantity': newQty});

  Future<void> updateRipeness(
    String uid,
    FoodItem item,
    int newRipeness,
  ) async {
    assert(item.isFreshItem && item.baseShelfLifeDays != null);
    final entry = lookupFreshProduce(item.name);
    final storageMult = getStorageMultiplier(entry, item.storageLocation);
    final ripMult = kRipenessMultipliers[newRipeness];
    final bioMult = item.isBio ? 0.72 : 1.0;
    final consumed = (1 - newRipeness / 4).clamp(0.0, 1.0);
    final remainingDays =
        item.baseShelfLifeDays! * ripMult * bioMult * storageMult * consumed;
    final hours = (remainingDays * 24).round().clamp(1, 365 * 24);
    final newExpiration = DateTime.now().add(Duration(hours: hours));

    final update = {
      'ripeness': newRipeness,
      'updatedAt': Timestamp.now(),
      'newEstimatedExpiration': Timestamp.fromDate(newExpiration),
    };

    await _col(uid).doc(item.id).update({
      'expiryDate': Timestamp.fromDate(newExpiration),
      'estimatedExpiration': Timestamp.fromDate(newExpiration),
      'ripenessUpdates': FieldValue.arrayUnion([update]),
    });
  }

  Future<void> updateStorageLocation(
    String uid,
    FoodItem item,
    String newStorage,
  ) async {
    if (!item.isFreshItem || item.baseShelfLifeDays == null) {
      await _col(uid).doc(item.id).update({'storageLocation': newStorage});
      return;
    }
    final entry = lookupFreshProduce(item.name);
    final currentRipeness = calcCurrentRipeness(
      initialRipeness: item.initialRipeness ?? 2,
      baseShelfLifeDays: item.baseShelfLifeDays!,
      addedAt: item.addedAt,
      storageLocation: newStorage,
      entry: entry,
    );
    final newExpiry = calcEstimatedExpiry(
      baseShelfLifeDays: item.baseShelfLifeDays!,
      storageMultiplier: getStorageMultiplier(entry, newStorage),
      ripenessLevel: currentRipeness.round().clamp(0, 4),
      isBio: item.isBio,
    );
    await _col(uid).doc(item.id).update({
      'storageLocation': newStorage,
      'expiryDate': Timestamp.fromDate(newExpiry),
      'estimatedExpiration': Timestamp.fromDate(newExpiry),
    });
  }

  double _toKg(double quantity, String unit) {
    switch (unit.toLowerCase()) {
      case 'g':
      case 'ml':
        return quantity / 1000;
      case 'kg':
      case 'l':
        return quantity;
      default:
        return quantity * 0.3;
    }
  }
}
