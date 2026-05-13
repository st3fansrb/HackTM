import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/shopping_item.dart';

class ShoppingListRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users/$uid/shopping_list');

  Stream<List<ShoppingItem>> watchShoppingList(String uid) => _col(uid)
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => ShoppingItem.fromFirestore(d)).toList());

  Future<void> addItem(String uid, ShoppingItem item) async {
    final name = item.name.trim();
    final existing = await _col(uid)
        .where('name', isEqualTo: name)
        .where('checked', isEqualTo: false)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final existingQty = (doc.data()['quantity'] as num?)?.toDouble();
      final newQty = item.quantity;
      if (existingQty != null && newQty != null) {
        await doc.reference.update({'quantity': existingQty + newQty});
      }
      return;
    }

    await _col(uid).add(item.toFirestore());
  }

  Future<void> toggleItem(String uid, String itemId, bool checked) =>
      _col(uid).doc(itemId).update({'checked': checked});

  Future<void> deleteItem(String uid, String itemId) =>
      _col(uid).doc(itemId).delete();

  Future<void> clearAll(String uid) async {
    final snap = await _col(uid).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
