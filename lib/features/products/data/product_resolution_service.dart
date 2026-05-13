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

  Future<ProductResolution> resolveByBarcode(String barcode) async {
    final steps = <ResolutionStep>[];

    // Step 1: Open Food Facts by barcode
    steps.add(ResolutionStep.offBarcode);
    final offProduct = await _off.fetchByBarcode(barcode);
    if (offProduct != null) {
      final prefill = offProduct.toPrefillMap()..['barcode'] = barcode;
      await _cacheToFirestore(barcode, prefill);
      await _logEvent(
        barcode: barcode,
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

    // Step 2: Frigo local DB
    steps.add(ResolutionStep.frigoDB);
    try {
      final doc = await _db
          .collection('products_ro')
          .doc(barcode)
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['barcode'] = barcode;
        data['source'] = 'frigo_db';
        await _logEvent(
          barcode: barcode,
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
    } catch (_) {}

    // Not found
    await _logEvent(
      barcode: barcode,
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
