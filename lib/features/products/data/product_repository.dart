import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/data/barcode_products.dart';
import '../domain/product_info.dart';

class ProductRepository {
  final FirebaseFirestore _db;

  ProductRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  Future<ProductInfo?> lookupEan(String ean) async {
    // 1. Firestore global products/{ean}
    try {
      final doc = await _col
          .doc(ean)
          .get()
          .timeout(const Duration(seconds: 10));
      if (doc.exists) return ProductInfo.fromFirestore(doc);
    } catch (_) {
      // Firestore unavailable or timed out — fall through
    }

    // 2. Local demo fallback
    final demo = kDemoProducts[ean];
    if (demo != null) return ProductInfo.fromDemoProduct(ean, demo);

    // 3. Unknown product
    return null;
  }

  /// Returns true on success. Never throws — callers treat this as best-effort.
  Future<bool> saveProduct(ProductInfo product) async {
    final ref = _col.doc(product.ean);
    try {
      final doc = await ref.get();
      if (doc.exists) {
        await ref.update({'verifiedCount': FieldValue.increment(1)});
      } else {
        await ref.set(product.toFirestore());
      }
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        '[ProductRepository] saveProduct — Firebase error '
        '(code: ${e.code}): ${e.message}',
      );
      return false;
    } catch (e, stack) {
      debugPrint('[ProductRepository] saveProduct — unexpected error: $e\n$stack');
      return false;
    }
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(FirebaseFirestore.instance);
});
