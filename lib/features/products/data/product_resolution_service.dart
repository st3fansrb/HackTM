import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_food_facts_service.dart';

enum ResolutionStep { offBarcode, frigoDB, offSearch, manual }

class ProductResolution {
  final Map<String, dynamic>? product;
  final List<ResolutionStep> stepsTried;
  final ResolutionStep? resolvedAtStep;

  const ProductResolution({
    this.product,
    required this.stepsTried,
    this.resolvedAtStep,
  });

  bool get isResolved => product != null;
}

class ProductResolutionService {
  final OpenFoodFactsService _off = OpenFoodFactsService();
  final _db = FirebaseFirestore.instance;

  String _normalizeBarcode(String raw) {
    // Strip whitespace and any non-digit characters.
    final cleaned = raw.trim().replaceAll(RegExp(r'\D'), '');
    // EAN-13: pad to 13 digits if shorter (e.g. EAN-8 / UPC-A 12).
    if (cleaned.length < 13) return cleaned.padLeft(13, '0');
    // EAN-13: truncate to last 13 digits if longer (scan glitch).
    if (cleaned.length > 13) return cleaned.substring(cleaned.length - 13);
    return cleaned;
  }

  Future<ProductResolution> resolveByBarcode(String barcode) async {
    final steps = <ResolutionStep>[];
    final normalizedBarcode = _normalizeBarcode(barcode);

    // TEMP DIAGNOSTIC — remove after barcode debug
    print('[BARCODE] Raw value from scanner: "$barcode"');
    print('[BARCODE] Length: ${barcode.length}');
    print('[BARCODE] Normalized: "$normalizedBarcode"');

    // Step 1: Open Food Facts by barcode
    steps.add(ResolutionStep.offBarcode);
    final offProduct = await _off.fetchByBarcode(normalizedBarcode);
    print('[BARCODE] OFF result: ${offProduct != null ? "found" : "null"}');
    if (offProduct != null) {
      final prefill =
          offProduct.toPrefillMap()..['barcode'] = normalizedBarcode;
      await _cacheToFirestore(normalizedBarcode, prefill);
      await _logEvent(
        barcode: normalizedBarcode,
        stepsTried: steps,
        resolvedAtStep: 'off_barcode',
        source: 'open_food_facts',
        category: prefill['category'] as String? ?? 'altele',
      );
      return ProductResolution(
        product: prefill,
        stepsTried: steps,
        resolvedAtStep: ResolutionStep.offBarcode,
      );
    }

    // Step 2: Frigo local DB — try normalized, then leading-zero-stripped,
    // then the original cleaned value (Firestore imports often drop the
    // leading zero when barcodes were stored as numbers).
    steps.add(ResolutionStep.frigoDB);
    try {
      final withoutLeadingZeros =
          normalizedBarcode.replaceAll(RegExp(r'^0+'), '');
      final candidates = <String>{
        normalizedBarcode,
        withoutLeadingZeros,
        barcode.trim(),
      }..removeWhere((c) => c.isEmpty);

      for (final candidate in candidates) {
        print('[BARCODE] Firestore doc ID queried: "$candidate"');
        final doc = await _db
            .collection('products_ro')
            .doc(candidate)
            .get()
            .timeout(const Duration(seconds: 3));
        print('[BARCODE] Firestore doc exists: ${doc.exists}');
        if (doc.exists) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['barcode'] = normalizedBarcode;
          data['source'] = 'frigo_db';
          await _logEvent(
            barcode: normalizedBarcode,
            stepsTried: steps,
            resolvedAtStep: 'frigo_db',
            source: 'frigo_db',
            category: data['category'] as String? ?? 'altele',
          );
          return ProductResolution(
            product: data,
            stepsTried: steps,
            resolvedAtStep: ResolutionStep.frigoDB,
          );
        }
      }
    } catch (_) {}

    // Not found
    await _logEvent(
      barcode: normalizedBarcode,
      stepsTried: steps,
      resolvedAtStep: null,
      source: null,
      category: 'altele',
    );
    return ProductResolution(
      product: null,
      stepsTried: steps,
      resolvedAtStep: null,
    );
  }

  Future<List<Map<String, dynamic>>> searchByName(String query) async {
    final results = await _off.search(query);
    return results.map((p) => p.toPrefillMap()).toList();
  }

  Future<void> _cacheToFirestore(
    String barcode,
    Map<String, dynamic> prefill,
  ) async {
    try {
      await _db.collection('products_ro').doc(barcode).set({
        ...prefill,
        'source': 'off_cached',
        'cachedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _logEvent({
    String? barcode,
    String? searchQuery,
    required List<ResolutionStep> stepsTried,
    required String? resolvedAtStep,
    required String? source,
    required String category,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _db.collection('product_lookup_events').add({
        'barcode': ?barcode,
        'searchQuery': ?searchQuery,
        'stepsTried': stepsTried.map((s) => s.name).toList(),
        'resolvedAtStep': resolvedAtStep ?? 'not_resolved',
        'source': ?source,
        'category': category,
        'userId': ?uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

final productResolutionServiceProvider =
    Provider<ProductResolutionService>((_) => ProductResolutionService());
