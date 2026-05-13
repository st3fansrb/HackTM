import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/barcode_service.dart';
import '../../../features/nutrition/presentation/nutri_score_badge.dart';
import '../../../features/pantry/presentation/qr_view_factory.dart';
import '../../../features/products/data/gemini_ocr_service.dart';
import '../../../features/products/data/image_picker_service.dart';
import '../../../features/products/data/product_repository.dart';
import '../../../features/products/domain/nutri_score_calculator.dart';
import '../../../features/products/domain/product_info.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../shared/widgets/expiry_selector.dart';
import '../domain/cart_item.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _cartCategories = [
  ('dairy', 'Lactate', '🥛'),
  ('meat', 'Carne', '🥩'),
  ('produce', 'Legume/Fructe', '🥦'),
  ('canned', 'Conserve', '🥫'),
  ('grains', 'Cereale', '🌾'),
  ('other', 'Altele', '📦'),
];

const _units = ['buc', 'kg', 'g', 'L', 'ml'];

enum _SheetPhase { loading, knownProduct, choice, ocrLoading, form }

// ─── Screen ───────────────────────────────────────────────────────────────────

class CartScannerScreen extends ConsumerStatefulWidget {
  const CartScannerScreen({super.key});

  @override
  ConsumerState<CartScannerScreen> createState() => _CartScannerScreenState();
}

class _CartScannerScreenState extends ConsumerState<CartScannerScreen> {
  late final BarcodeService _service;
  StreamSubscription<String>? _sub;
  bool _isScanning = false;
  bool _navigated = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    registerQrViewFactory();
    _service = BarcodeService();
    _sub = _service.barcodeStream.listen(_onBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  void _startScanning() {
    if (!mounted || _isScanning) return;
    _navigated = false;
    _service.startScanner();
    setState(() => _isScanning = true);
  }

  void _stopScanning() {
    _service.stopScanner();
    if (mounted) setState(() => _isScanning = false);
  }

  void _resumeScanning() {
    _navigated = false;
    _startScanning();
  }

  void _toggleTorch() {
    _service.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onBarcode(String barcode) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _stopScanning();
    _showProductSheet(barcode);
  }

  Future<void> _showProductSheet(String barcode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductSheet(
        barcode: barcode,
        onAdded: (name) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name adăugat în coș'),
                backgroundColor: AppColors.darkEmerald,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onCancel: () {},
      ),
    );
    _resumeScanning();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.stopScanner();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Scanează pentru coș'),
        actions: [
          TextButton(
            onPressed: _toggleTorch,
            child: Text(
              '🔦 Lanternă',
              style: TextStyle(
                color: _torchOn ? Colors.yellow : Colors.white70,
                fontWeight:
                    _torchOn ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb)
            const HtmlElementView(viewType: 'qr-reader-view')
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Scanner disponibil doar în browser (PWA)',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (_isScanning && kIsWeb)
            const IgnorePointer(child: _ScanFrame()),

          if (!_isScanning)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 80, color: Colors.white38),
                    const SizedBox(height: 24),
                    const Text(
                      'Scanner oprit',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Apasă butonul pentru a scana din nou',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Pornește scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isScanning)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Scanează produsul cumpărat',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Product bottom sheet ─────────────────────────────────────────────────────

class _ProductSheet extends ConsumerStatefulWidget {
  final String barcode;
  final void Function(String name) onAdded;
  final VoidCallback onCancel;

  const _ProductSheet({
    required this.barcode,
    required this.onAdded,
    required this.onCancel,
  });

  @override
  ConsumerState<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<_ProductSheet> {
  _SheetPhase _phase = _SheetPhase.loading;
  ProductInfo? _product;
  NutritionalData? _ocrData;
  String? _ocrError;
  String _ocrStatusMsg = 'Se deschide camera...';

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _saltCtrl = TextEditingController();

  String _category = 'other';
  String _unit = 'buc';
  DateTime? _expiryDate;
  bool _isSaving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _lookupProduct();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _sugarCtrl.dispose();
    _saltCtrl.dispose();
    super.dispose();
  }

  // ── Lookup ─────────────────────────────────────────────────────────

  Future<void> _lookupProduct() async {
    try {
      final p = await ref
          .read(productRepositoryProvider)
          .lookupEan(widget.barcode);
      if (!mounted) return;

      if (p != null) {
        _product = p;
        _nameCtrl.text = p.name;
        _brandCtrl.text = p.brand ?? '';
        _category = p.category;
        _qtyCtrl.text = '1';
        if (p.calories != null) _calCtrl.text = p.calories!.toString();
        if (p.protein != null) _proteinCtrl.text = p.protein!.toString();
        if (p.fat != null) _fatCtrl.text = p.fat!.toString();
        if (p.carbs != null) _carbsCtrl.text = p.carbs!.toString();
        if (p.sugar != null) _sugarCtrl.text = p.sugar!.toString();
        if (p.salt != null) _saltCtrl.text = p.salt!.toString();
        setState(() => _phase = _SheetPhase.knownProduct);
      } else {
        setState(() => _phase = _SheetPhase.choice);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _SheetPhase.choice);
    }
  }

  // ── OCR flow ───────────────────────────────────────────────────────

  Future<void> _startOcr() async {
    setState(() {
      _phase = _SheetPhase.ocrLoading;
      _ocrStatusMsg = 'Se deschide camera...';
      _ocrError = null;
    });

    try {
      final bytes = await pickCameraImage();
      if (!mounted) return;

      if (bytes == null) {
        setState(() => _phase = _SheetPhase.choice);
        return;
      }

      setState(() => _ocrStatusMsg = 'Se analizează eticheta...');

      final data = await GeminiOcrService().extractFromImage(bytes);
      if (!mounted) return;

      if (data != null) {
        _ocrData = data;
        if (data.name?.isNotEmpty == true) _nameCtrl.text = data.name!;
        if (data.brand?.isNotEmpty == true) _brandCtrl.text = data.brand!;
        if (data.calories != null) {
          _calCtrl.text = data.calories!.toStringAsFixed(1);
        }
        if (data.protein != null) {
          _proteinCtrl.text = data.protein!.toStringAsFixed(1);
        }
        if (data.fat != null) _fatCtrl.text = data.fat!.toStringAsFixed(1);
        if (data.carbs != null) {
          _carbsCtrl.text = data.carbs!.toStringAsFixed(1);
        }
        if (data.sugar != null) {
          _sugarCtrl.text = data.sugar!.toStringAsFixed(1);
        }
        if (data.salt != null) _saltCtrl.text = data.salt!.toStringAsFixed(1);
        setState(() => _phase = _SheetPhase.form);
      } else {
        setState(() {
          _phase = _SheetPhase.form;
          _ocrError = 'Nu am putut citi eticheta. Completează manual.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _SheetPhase.form;
          _ocrError = 'Nu am putut citi eticheta. Completează manual.';
        });
      }
    }
  }

  void _startManual() {
    setState(() {
      _phase = _SheetPhase.form;
      _ocrData = null;
      _ocrError = null;
    });
  }

  // ── Add to cart ────────────────────────────────────────────────────

  Future<void> _addToCart() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Introdu numele produsului');
      return;
    }
    final qty =
        double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _formError = 'Cantitate invalidă');
      return;
    }
    if (_expiryDate == null) {
      setState(() => _formError = 'Selectează data de expirare');
      return;
    }

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final calories =
          double.tryParse(_calCtrl.text.replaceAll(',', '.')) ??
              _product?.calories;
      final protein =
          double.tryParse(_proteinCtrl.text.replaceAll(',', '.')) ??
              _product?.protein;
      final fat =
          double.tryParse(_fatCtrl.text.replaceAll(',', '.')) ??
              _product?.fat;
      final carbs =
          double.tryParse(_carbsCtrl.text.replaceAll(',', '.')) ??
              _product?.carbs;
      final sugar =
          double.tryParse(_sugarCtrl.text.replaceAll(',', '.')) ??
              _product?.sugar;
      final salt =
          double.tryParse(_saltCtrl.text.replaceAll(',', '.')) ??
              _product?.salt;

      // NutriScore: use stored for known products, calculate for new ones
      String? nutriScore = _product?.nutriScore;
      if (nutriScore == null || _phase != _SheetPhase.knownProduct) {
        final nd = NutritionalData(
          calories: calories,
          protein: protein,
          fat: fat,
          carbs: carbs,
          sugar: sugar,
          salt: salt,
        );
        final computed = calculateNutriScore(nd);
        nutriScore = computed == 'N/A' ? null : computed;
      }

      // Build ProductInfo for global DB
      final productToSave = _product != null
          ? _product!.copyWith(
              // Re-attribute demo products to the first real user
              contributedBy: _product!.contributedBy == 'demo'
                  ? uid
                  : _product!.contributedBy,
              nutriScore: nutriScore ?? _product!.nutriScore,
            )
          : ProductInfo(
              ean: widget.barcode,
              name: name,
              category: _category,
              brand: _brandCtrl.text.trim().isNotEmpty
                  ? _brandCtrl.text.trim()
                  : null,
              nutriScore: nutriScore,
              calories: calories,
              protein: protein,
              fat: fat,
              carbs: carbs,
              sugar: sugar,
              salt: salt,
              contributedBy: uid,
              contributedAt: DateTime.now(),
              verifiedCount: 1,
            );

      // Save to global products DB (best effort — failure doesn't block cart add)
      final saved = await ref
          .read(productRepositoryProvider)
          .saveProduct(productToSave);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Produsul nu a putut fi salvat în baza globală.'),
                ),
              ],
            ),
            backgroundColor: AppColors.fawn,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Add to user's cart
      final item = CartItem(
        id: '',
        barcode: widget.barcode,
        name: name,
        category: _category,
        quantity: qty,
        unit: _unit,
        expiryDate: _expiryDate,
        calories: calories,
        sugar: sugar,
        fat: fat,
        isUnknown: _product == null,
        addedAt: DateTime.now(),
      );

      await ref.read(cartRepositoryProvider).addItem(uid, item);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAdded(name);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _formError = 'Nu s-a putut adăuga. Încearcă din nou.';
        });
      }
    }
  }

  // ── NutriScore helper ──────────────────────────────────────────────

  String? _computeNutriScore() {
    // For known products, prefer stored value; fall back to calculation
    if (_phase == _SheetPhase.knownProduct && _product != null) {
      if (_product!.nutriScore != null) return _product!.nutriScore;
      final nd = NutritionalData(
        calories: _product!.calories,
        protein: _product!.protein,
        fat: _product!.fat,
        carbs: _product!.carbs,
        sugar: _product!.sugar,
        salt: _product!.salt,
      );
      final s = calculateNutriScore(nd);
      return s == 'N/A' ? null : s;
    }
    // For form phase, calculate from current controllers
    final nd = NutritionalData(
      calories: double.tryParse(_calCtrl.text.replaceAll(',', '.')),
      protein: double.tryParse(_proteinCtrl.text.replaceAll(',', '.')),
      fat: double.tryParse(_fatCtrl.text.replaceAll(',', '.')),
      carbs: double.tryParse(_carbsCtrl.text.replaceAll(',', '.')),
      sugar: double.tryParse(_sugarCtrl.text.replaceAll(',', '.')),
      salt: double.tryParse(_saltCtrl.text.replaceAll(',', '.')),
    );
    final s = calculateNutriScore(nd);
    return s == 'N/A' ? null : s;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            switch (_phase) {
              _SheetPhase.loading => _buildLoading(
                  'Se caută produsul...'),
              _SheetPhase.knownProduct => _buildKnownProduct(context),
              _SheetPhase.choice => _buildChoice(context),
              _SheetPhase.ocrLoading =>
                _buildLoading(_ocrStatusMsg),
              _SheetPhase.form => _buildForm(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ── Loading ────────────────────────────────────────────────────────

  Widget _buildLoading(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  // ── Known product ──────────────────────────────────────────────────

  Widget _buildKnownProduct(BuildContext context) {
    final theme = Theme.of(context);
    final score = _computeNutriScore();
    final p = _product!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + NutriScore
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      'EAN: ${widget.barcode}',
                      if (p.brand != null) p.brand!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 12),
              NutriScoreBadge(score: score),
            ],
          ],
        ),

        // Category chip
        const SizedBox(height: 10),
        _CategoryChip(category: p.category),

        const SizedBox(height: 16),

        // Qty + unit
        _buildQtyUnit(),
        const SizedBox(height: 20),

        // Expiry
        Text('Data de expirare', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ExpirySelector(
          category: _category,
          selected: _expiryDate,
          onChanged: (d) => setState(() => _expiryDate = d),
        ),

        _buildError(),
        const SizedBox(height: 24),
        _buildActions(),
      ],
    );
  }

  // ── Choice ─────────────────────────────────────────────────────────

  Widget _buildChoice(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.help_outline_rounded,
            size: 52, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          'Produs necunoscut',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'EAN: ${widget.barcode}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Photo button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startOcr,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Fotografiază eticheta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Manual button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _startManual,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Introduc manual'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkEmerald,
              side: const BorderSide(color: AppColors.darkEmerald),
              padding:
                  const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onCancel();
          },
          child: const Text('Anulează',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }

  // ── Form (manual / OCR-prefilled) ──────────────────────────────────

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final score = _computeNutriScore();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OCR success or error indicator
        if (_ocrData != null)
          _InfoBanner(
            icon: Icons.check_circle_outline,
            color: AppColors.freshGreen,
            message: 'Etichetă analizată — verifică și corectează dacă e necesar',
          )
        else if (_ocrError != null)
          _InfoBanner(
            icon: Icons.info_outline,
            color: AppColors.useSoonYellow,
            message: _ocrError!,
          ),

        if (_ocrData != null || _ocrError != null)
          const SizedBox(height: 16),

        // Name
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nume produs *',
            prefixIcon: Icon(Icons.fastfood_outlined),
          ),
        ),
        const SizedBox(height: 12),

        // Brand
        TextField(
          controller: _brandCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Brand',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),

        // Category
        InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_outlined),
            labelText: 'Categorie *',
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              isDense: true,
              items: _cartCategories
                  .map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text('${c.$3} ${c.$2}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Qty + unit
        _buildQtyUnit(),
        const SizedBox(height: 20),

        // Expiry
        Text('Data de expirare *',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ExpirySelector(
          category: _category,
          selected: _expiryDate,
          onChanged: (d) => setState(() => _expiryDate = d),
        ),
        const SizedBox(height: 20),

        // Nutrition section
        Row(
          children: [
            Text('Informații nutriționale',
                style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('(per 100g, opțional)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted)),
            if (score != null) ...[
              const Spacer(),
              NutriScoreBadge(score: score),
            ],
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _NutrField(
                  ctrl: _calCtrl,
                  label: 'Calorii',
                  suffix: 'kcal'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutrField(
                  ctrl: _proteinCtrl,
                  label: 'Proteine',
                  suffix: 'g'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NutrField(
                  ctrl: _fatCtrl,
                  label: 'Grăsimi',
                  suffix: 'g'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutrField(
                  ctrl: _carbsCtrl,
                  label: 'Carbohidrați',
                  suffix: 'g'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NutrField(
                  ctrl: _sugarCtrl,
                  label: 'Zahăr',
                  suffix: 'g'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutrField(
                  ctrl: _saltCtrl,
                  label: 'Sare',
                  suffix: 'g'),
            ),
          ],
        ),

        _buildError(),
        const SizedBox(height: 24),
        _buildActions(),
      ],
    );
  }

  // ── Shared sub-widgets ─────────────────────────────────────────────

  Widget _buildQtyUnit() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cantitate',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: InputDecorator(
              decoration:
                  const InputDecoration(labelText: 'Unitate'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _unit,
                  isExpanded: true,
                  isDense: true,
                  items: _units
                      .map((u) => DropdownMenuItem(
                          value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _unit = v);
                  },
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildError() {
    if (_formError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.expiredRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.expiredRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 16, color: AppColors.expiredRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formError!,
                style: const TextStyle(
                    color: AppColors.expiredRed, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onCancel();
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(
                    color: AppColors.textMuted),
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Anulează'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addToCart,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : const Icon(Icons.add_shopping_cart),
              label: const Text('Adaugă în coș'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
}

// ─── Small helper widgets ─────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final match = _cartCategories
        .where((c) => c.$1 == category)
        .firstOrNull;
    final label =
        match != null ? '${match.$3} ${match.$2}' : category;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.darkEmerald.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.darkEmerald,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      color.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String suffix;

  const _NutrField({
    required this.ctrl,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ─── Scan frame overlay ───────────────────────────────────────────────────────

class _ScanFrame extends StatefulWidget {
  const _ScanFrame();

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _line;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _line = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _line,
      builder: (_, _) => Stack(
        children: [
          CustomPaint(
            painter: _ScanOverlayPainter(lineProgress: _line.value),
            child: const SizedBox.expand(),
          ),
          const Align(
            alignment: Alignment(0, 0.15),
            child: Text(
              'Ține codul drept și la 10-15cm distanță',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final double lineProgress;
  const _ScanOverlayPainter({required this.lineProgress});

  static const _primary     = Color(0xFF2ECC71);
  static const _bracketLen  = 28.0;
  static const _bracketW    = 3.5;
  static const _cornerR     = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Frame rectangle — slightly above centre to leave room for the hint below
    final frameW = size.width * 0.76;
    final frameH = frameW * 0.52;
    final left   = (size.width  - frameW) / 2;
    final top    = (size.height - frameH) / 2 - size.height * 0.05;
    final rect   = Rect.fromLTWH(left, top, frameW, frameH);

    // ── Semi-transparent dark overlay with a clear hole ──────────────────
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_cornerR)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // ── Corner brackets ───────────────────────────────────────────────────
    final bp = Paint()
      ..color       = _primary
      ..strokeWidth = _bracketW
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    const r = _cornerR;
    const l = _bracketLen;

    // Top-left
    canvas.drawArc(Rect.fromLTWH(left, top, r * 2, r * 2),
        math.pi, -math.pi / 2, false, bp);
    canvas.drawLine(Offset(left + r, top), Offset(left + r + l, top), bp);
    canvas.drawLine(Offset(left, top + r), Offset(left, top + r + l), bp);

    // Top-right
    canvas.drawArc(Rect.fromLTWH(left + frameW - r * 2, top, r * 2, r * 2),
        -math.pi / 2, -math.pi / 2, false, bp);
    canvas.drawLine(Offset(left + frameW - r - l, top), Offset(left + frameW - r, top), bp);
    canvas.drawLine(Offset(left + frameW, top + r), Offset(left + frameW, top + r + l), bp);

    // Bottom-left
    canvas.drawArc(Rect.fromLTWH(left, top + frameH - r * 2, r * 2, r * 2),
        math.pi, math.pi / 2, false, bp);
    canvas.drawLine(Offset(left + r, top + frameH), Offset(left + r + l, top + frameH), bp);
    canvas.drawLine(Offset(left, top + frameH - r - l), Offset(left, top + frameH - r), bp);

    // Bottom-right
    canvas.drawArc(Rect.fromLTWH(left + frameW - r * 2, top + frameH - r * 2, r * 2, r * 2),
        0, math.pi / 2, false, bp);
    canvas.drawLine(Offset(left + frameW - r - l, top + frameH), Offset(left + frameW - r, top + frameH), bp);
    canvas.drawLine(Offset(left + frameW, top + frameH - r - l), Offset(left + frameW, top + frameH - r), bp);

    // ── Animated scan line (clipped to frame rect) ────────────────────────
    canvas.save();
    canvas.clipRect(rect.deflate(2));

    final scanY = top + lineProgress * frameH;

    final glowPaint = Paint()
      ..color       = _primary.withValues(alpha: 0.25)
      ..strokeWidth = 10.0
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(Offset(left + 6, scanY), Offset(left + frameW - 6, scanY), glowPaint);

    final linePaint = Paint()
      ..color       = _primary.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(Offset(left + 6, scanY), Offset(left + frameW - 6, scanY), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.lineProgress != lineProgress;
}
