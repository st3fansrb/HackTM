import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/cart_item.dart';

class CartRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users/$uid/cart');

  Stream<List<CartItem>> watchCart(String uid) => _col(uid)
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => CartItem.fromFirestore(d)).toList());

  Future<void> addItem(String uid, CartItem item) =>
      _col(uid).add(item.toFirestore());

  Future<void> updateItem(String uid, CartItem item) =>
      _col(uid).doc(item.id).update(item.toFirestore());

  Future<void> removeItem(String uid, String itemId) =>
      _col(uid).doc(itemId).delete();

  Future<void> clearCart(String uid) async {
    final snap = await _col(uid).get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
