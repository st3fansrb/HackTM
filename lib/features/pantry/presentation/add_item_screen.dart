import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/nutrition/domain/nutri_score.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/widgets/ripeness_slider.dart';
import '../../../shared/widgets/storage_toggle.dart';
import '../data/fresh_produce_data.dart';
import '../data/pantry_repository.dart';
import '../domain/food_item.dart';

// ─── Category definitions ─────────────────────────────────────────────────────

class _CatDef {
  final String id;
  final String label;
  final String emoji;
  final String storageDefault;
  final bool storageLocked;
  final String expiryBehavior; // required | optional | fresh | auto3days

  const _CatDef(
    this.id,
    this.label,
    this.emoji,
    this.storageDefault,
    this.storageLocked,
    this.expiryBehavior,
  );
}

const _kCategories = [
  _CatDef('lactate_oua',   'Lactate & Ouă',                '🥛', 'frigider',           false, 'required'),
  _CatDef('carne_mezeluri','Carne & Mezeluri',              '🥩', 'frigider',           false, 'required'),
  _CatDef('peste',         'Pește & Fructe de mare',       '🐟', 'frigider',           false, 'required'),
  _CatDef('fructe_legume', 'Fructe & Legume proaspete',    '🍎', 'temperatura_camerei', false, 'fresh'),
  _CatDef('panificatie',   'Panificație & Patiserie',      '🍞', 'temperatura_camerei', false, 'required'),
  _CatDef('cereale_paste', 'Cereale, Paste & Leguminoase', '🌾', 'temperatura_camerei', false, 'required'),
  _CatDef('conserve',      'Conserve & Murături',          '🫙', 'temperatura_camerei', false, 'required'),
  _CatDef('snacks',        'Snacks & Dulciuri',             '🍫', 'temperatura_camerei', false, 'required'),
  _CatDef('bauturi',       'Băuturi',                      '🥤', 'temperatura_camerei', false, 'optional'),
  _CatDef('condimente',    'Condimente, Sosuri & Uleiuri', '🧂', 'temperatura_camerei', false, 'required'),
  _CatDef('congelate',     'Congelate',                    '🧊', 'congelator',          true,  'required'),
  _CatDef('preparate',     'Preparate & Mâncăruri gătite', '🍲', 'frigider',            false, 'auto3days'),
  _CatDef('altele',        'Altele',                       '📦', 'temperatura_camerei', false, 'optional'),
];

final _kCatMap = {for (final c in _kCategories) c.id: c};

const _kUnits = ['buc', 'kg', 'g', 'L', 'ml', 'pungă'];

String _mapLegacyCategory(String? raw) {
  switch (raw) {
    case 'dairy':      return 'lactate_oua';
    case 'meat':       return 'carne_mezeluri';
    case 'vegetables': return 'fructe_legume';
    case 'fruits':     return 'fructe_legume';
    case 'grains':     return 'cereale_paste';
    case 'other':      return 'altele';
    case null:         return 'altele';
    default:           return _kCatMap.containsKey(raw) ? raw : 'altele';
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

@immutable
class _AddState {
  final String category;
  final String storageLocation;
  final bool storageLocked;
  final String unit;
  final DateTime? expiryDate;
  final bool expirySkipped;
  final int ripenessLevel;
  final bool isBio;
  final int baseShelfLifeDays;
  final double fridgeMultiplier;
  final double freezerMultiplier;
  final String? barcode;
  final String? imageUrl;
  final String? source;
  final bool isLoading;
  final String? error;

  const _AddState({
    this.category = 'altele',
    this.storageLocation = 'temperatura_camerei',
    this.storageLocked = false,
    this.unit = 'buc',
    this.expiryDate,
    this.expirySkipped = false,
    this.ripenessLevel = 2,
    this.isBio = false,
    this.baseShelfLifeDays = 5,
    this.fridgeMultiplier = 2.5,
    this.freezerMultiplier = 6.0,
    this.barcode,
    this.imageUrl,
    this.source,
    this.isLoading = false,
    this.error,
  });

  bool get isFreshMode => category == 'fructe_legume';

  String get expiryBehavior =>
      _kCatMap[category]?.expiryBehavior ?? 'required';

  DateTime? get estimatedExpiration {
    if (!isFreshMode) return null;
    final storeMult = storageLocation == 'frigider'
        ? fridgeMultiplier
        : storageLocation == 'congelator'
            ? freezerMultiplier
            : 1.0;
    return calcEstimatedExpiry(
      baseShelfLifeDays: baseShelfLifeDays,
      storageMultiplier: storeMult,
      ripenessLevel: ripenessLevel,
      isBio: isBio,
    );
  }

  _AddState copyWith({
    String? category,
    String? storageLocation,
    bool? storageLocked,
    String? unit,
    Object? expiryDate = _kKeep,
    bool? expirySkipped,
    int? ripenessLevel,
    bool? isBio,
    int? baseShelfLifeDays,
    double? fridgeMultiplier,
    double? freezerMultiplier,
    String? barcode,
    String? imageUrl,
    String? source,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      _AddState(
        category: category ?? this.category,
        storageLocation: storageLocation ?? this.storageLocation,
        storageLocked: storageLocked ?? this.storageLocked,
        unit: unit ?? this.unit,
        expiryDate: expiryDate == _kKeep
            ? this.expiryDate
            : expiryDate as DateTime?,
        expirySkipped: expirySkipped ?? this.expirySkipped,
        ripenessLevel: ripenessLevel ?? this.ripenessLevel,
        isBio: isBio ?? this.isBio,
        baseShelfLifeDays: baseShelfLifeDays ?? this.baseShelfLifeDays,
        fridgeMultiplier: fridgeMultiplier ?? this.fridgeMultiplier,
        freezerMultiplier: freezerMultiplier ?? this.freezerMultiplier,
        barcode: barcode ?? this.barcode,
        imageUrl: imageUrl ?? this.imageUrl,
        source: source ?? this.source,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

const _kKeep = Object();

String _firestoreMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'Acces refuzat. Verifică conexiunea sau autentificarea.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Serverul nu răspunde. Verifică conexiunea la internet.';
    case 'not-found':
      return 'Documentul nu a fost găsit în baza de date.';
    case 'already-exists':
      return 'Produsul există deja.';
    case 'resource-exhausted':
      return 'Limită de scrieri atinsă. Încearcă din nou mai târziu.';
    default:
      return 'Eroare Firestore ($code). Încearcă din nou.';
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class _AddNotifier extends StateNotifier<_AddState> {
  _AddNotifier(this._repo, this._uid) : super(const _AddState());

  final PantryRepository _repo;
  final String _uid;

  void setCategory(String catId) {
    final cat = _kCatMap[catId]!;
    DateTime? autoDate;
    if (catId == 'preparate') {
      autoDate = DateTime.now().add(const Duration(days: 3));
    }
    state = state.copyWith(
      category: catId,
      storageLocation: cat.storageDefault,
      storageLocked: cat.storageLocked,
      expiryDate: autoDate,
      expirySkipped: false,
      clearError: true,
    );
  }

  void setStorage(String loc) {
    if (state.storageLocked) return;
    state = state.copyWith(storageLocation: loc);
  }

  void setUnit(String u) => state = state.copyWith(unit: u);

  void setDate(DateTime d) =>
      state = state.copyWith(expiryDate: d, expirySkipped: false);

  void skipExpiry() =>
      state = state.copyWith(expirySkipped: true, expiryDate: null);

  void setRipeness(int level) =>
      state = state.copyWith(ripenessLevel: level);

  void setBio(bool val) => state = state.copyWith(isBio: val);

  void setBarcode(String b) => state = state.copyWith(barcode: b);

  void setImageUrl(String url) => state = state.copyWith(imageUrl: url);

  void setSource(String s) => state = state.copyWith(source: s);

  void updateFreshLookup(String name) {
    if (!state.isFreshMode) return;
    final entry = lookupFreshProduce(name);
    state = state.copyWith(
      baseShelfLifeDays: entry.baseShelfLifeDays,
      fridgeMultiplier: entry.fridgeMultiplier,
      freezerMultiplier: entry.freezerMultiplier,
    );
  }

  Future<bool> save({
    required String name,
    required String quantityStr,
    String? brand,
    String? caloriesStr,
    String? sugarStr,
    String? fatStr,
  }) async {
    if (name.trim().isEmpty) {
      state = state.copyWith(error: 'Introdu numele produsului');
      return false;
    }

    if (!state.isFreshMode && !state.expirySkipped && state.expiryDate == null
        && state.expiryBehavior == 'required') {
      state = state.copyWith(error: 'Selectează data de expirare');
      return false;
    }

    final qty = quantityStr.trim().isEmpty
        ? 1.0
        : (double.tryParse(quantityStr.replaceAll(',', '.')) ?? 1.0)
            .clamp(0.001, 99999.0);

    final calories = double.tryParse((caloriesStr ?? '').replaceAll(',', '.'));
    final sugar = double.tryParse((sugarStr ?? '').replaceAll(',', '.'));
    final fat = double.tryParse((fatStr ?? '').replaceAll(',', '.'));
    final nutriScore =
        state.isFreshMode ? null : calculateNutriScore(calories, sugar, fat);

    final estimatedExp = state.estimatedExpiration;

    DateTime expiryToStore;
    if (state.isFreshMode && estimatedExp != null) {
      expiryToStore = estimatedExp;
    } else if (state.expirySkipped || state.expiryDate == null) {
      expiryToStore = DateTime.now().add(const Duration(days: 3650));
    } else {
      expiryToStore = state.expiryDate!;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final item = FoodItem(
        id: '',
        name: name.trim(),
        brand: (brand?.trim().isEmpty ?? true) ? null : brand!.trim(),
        category: state.category,
        quantity: qty,
        unit: state.unit,
        expiryDate: expiryToStore,
        expirySkipped: state.expirySkipped,
        barcode: state.barcode,
        calories: state.isFreshMode ? null : calories,
        sugar: state.isFreshMode ? null : sugar,
        fat: state.isFreshMode ? null : fat,
        nutriScore: nutriScore == 'N/A' ? null : nutriScore,
        addedAt: DateTime.now(),
        storageLocation: state.storageLocation,
        source: state.source,
        imageUrl: state.imageUrl,
        isFreshItem: state.isFreshMode,
        isBio: state.isFreshMode ? state.isBio : false,
        initialRipeness: state.isFreshMode ? state.ripenessLevel : null,
        baseShelfLifeDays: state.isFreshMode ? state.baseShelfLifeDays : null,
        estimatedExpiration: state.isFreshMode ? estimatedExp : null,
      );
      await _repo.addItem(_uid, item);
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[AddItem] Firestore error — code: ${e.code}, msg: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: _firestoreMessage(e.code),
      );
      return false;
    } catch (e, stack) {
      debugPrint('[AddItem] unexpected error: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Eroare neașteptată. Încearcă din nou.',
      );
      return false;
    }
  }
}

final _addItemProvider =
    StateNotifierProvider.autoDispose<_AddNotifier, _AddState>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return _AddNotifier(ref.watch(pantryRepositoryProvider), uid);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddItemScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefill;
  const AddItemScreen({super.key, this.prefill});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final n = ref.read(_addItemProvider.notifier);

        if (p['name'] is String) _nameCtrl.text = p['name'] as String;
        if (p['brand'] is String) _brandCtrl.text = p['brand'] as String;
        if (p['quantity'] is double) {
          _qtyCtrl.text = (p['quantity'] as double).toString();
        }
        if (p['calories'] is double) {
          _calCtrl.text = (p['calories'] as double).toString();
        }
        if (p['sugar'] is double) {
          _sugarCtrl.text = (p['sugar'] as double).toString();
        }
        if (p['fat'] is double) {
          _fatCtrl.text = (p['fat'] as double).toString();
        }
        if (p['barcode'] is String) n.setBarcode(p['barcode'] as String);
        if (p['imageUrl'] is String) n.setImageUrl(p['imageUrl'] as String);
        if (p['source'] is String) n.setSource(p['source'] as String);

        final rawCat = p['category'] as String?;
        final cat = _mapLegacyCategory(rawCat);
        n.setCategory(cat);

        if (p['unit'] is String) n.setUnit(p['unit'] as String);

        // After setting category, do fresh lookup for the name
        if (_nameCtrl.text.isNotEmpty) {
          n.updateFreshLookup(_nameCtrl.text);
        }
      });
    }

    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final notifier = ref.read(_addItemProvider.notifier);
    notifier.updateFreshLookup(_nameCtrl.text);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    _calCtrl.dispose();
    _sugarCtrl.dispose();
    _fatCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = ref.read(_addItemProvider).expiryDate ??
        DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      ref.read(_addItemProvider.notifier).setDate(picked);
      _dateCtrl.text = _fmtDate(picked);
    }
  }

  Future<void> _submit() async {
    final ok = await ref.read(_addItemProvider.notifier).save(
          name: _nameCtrl.text,
          quantityStr: _qtyCtrl.text,
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text,
          caloriesStr: _calCtrl.text.isEmpty ? null : _calCtrl.text,
          sugarStr: _sugarCtrl.text.isEmpty ? null : _sugarCtrl.text,
          fatStr: _fatCtrl.text.isEmpty ? null : _fatCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      final error = ref.read(_addItemProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: AppColors.expiredRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_addItemProvider);
    final notifier = ref.read(_addItemProvider.notifier);
    final theme = Theme.of(context);

    // Keep date text controller in sync when state changes (e.g., auto3days)
    if (state.expiryDate != null &&
        !state.expirySkipped &&
        _dateCtrl.text.isEmpty) {
      _dateCtrl.text = _fmtDate(state.expiryDate!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Adaugă produs'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image thumbnail ──
                  if (state.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        state.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Product name ──
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nume produs *',
                      prefixIcon: Icon(Icons.fastfood_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Introdu numele produsului'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Brand ──
                  TextFormField(
                    controller: _brandCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Brand (opțional)',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),

                  // ── Barcode badge ──
                  if (state.barcode != null) ...[
                    const SizedBox(height: 8),
                    _BarcodeBadge(barcode: state.barcode!),
                  ],
                  const SizedBox(height: 20),

                  // ── Category ──
                  Text('Categorie', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  _CategorySelector(
                    value: state.category,
                    onChanged: (cat) {
                      notifier.setCategory(cat);
                      // Reset date field when switching away from auto3days
                      if (cat != 'preparate') _dateCtrl.clear();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Storage ──
                  Text('Unde îl depozitezi?',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  StorageToggle(
                    value: state.storageLocation,
                    onChanged:
                        state.storageLocked ? null : notifier.setStorage,
                  ),
                  if (state.storageLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Produsele congelate se păstrează întotdeauna la congelator',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── Quantity + unit ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Cantitate (opțional)',
                            prefixIcon: Icon(Icons.scale_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: state.unit,
                          decoration:
                              const InputDecoration(labelText: 'Unitate'),
                          items: _kUnits
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) =>
                              v != null ? notifier.setUnit(v) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── FRESH MODE: Ripeness + expiry estimate ──
                  if (state.isFreshMode) ...[
                    Text('Cât de copt este?',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    RipenessSlider(
                      value: state.ripenessLevel,
                      onChanged: notifier.setRipeness,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Produs bio 🌿'),
                      subtitle: const Text(
                          'Produsele bio se alterează mai repede'),
                      value: state.isBio,
                      onChanged: notifier.setBio,
                      activeThumbColor: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    if (state.estimatedExpiration != null)
                      _EstimatedExpiryBanner(
                          date: state.estimatedExpiration!),
                  ] else ...[
                    // ── STANDARD: Expiry date ──
                    _ExpirySection(
                      behavior: state.expiryBehavior,
                      expiryDate: state.expiryDate,
                      expirySkipped: state.expirySkipped,
                      dateCtrl: _dateCtrl,
                      isLoading: state.isLoading,
                      onPickDate: _pickDate,
                      onSkip: notifier.skipExpiry,
                    ),
                    const SizedBox(height: 24),

                    // ── Nutritional info ──
                    Text('Valori nutriționale (opțional)',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Per 100 g/ml • Necesar pentru NutriScore',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _calCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Calorii',
                              hintText: 'kcal',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _sugarCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Zahăr',
                              hintText: 'g',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _fatCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Grăsimi',
                              hintText: 'g',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(state.error!),
                  ],
                ],
              ),
            ),
          ),
          if (state.isLoading) const ModalBarrier(color: Colors.black12),
          if (state.isLoading)
            const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _submit,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvează'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CategorySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _kCategories.map((cat) {
        final selected = value == cat.id;
        return GestureDetector(
          onTap: () => onChanged(cat.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              '${cat.emoji} ${cat.label}',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ExpirySection extends StatelessWidget {
  final String behavior;
  final DateTime? expiryDate;
  final bool expirySkipped;
  final TextEditingController dateCtrl;
  final bool isLoading;
  final VoidCallback onPickDate;
  final VoidCallback onSkip;

  const _ExpirySection({
    required this.behavior,
    required this.expiryDate,
    required this.expirySkipped,
    required this.dateCtrl,
    required this.isLoading,
    required this.onPickDate,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (expirySkipped) {
      return Row(
        children: [
          const Icon(Icons.event_busy_outlined,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('Fără dată de expirare',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted)),
          const Spacer(),
          TextButton(
            onPressed: onPickDate,
            child: const Text('Adaugă dată'),
          ),
        ],
      );
    }

    final isOptional = behavior == 'optional';
    final isAuto = behavior == 'auto3days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: dateCtrl,
          readOnly: true,
          onTap: isLoading ? null : onPickDate,
          decoration: InputDecoration(
            labelText:
                isOptional ? 'Data expirare (opțional)' : 'Data expirare *',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            hintText: 'Selectează data',
            suffixText: isAuto ? 'Auto' : null,
          ),
          validator: (_) {
            if (behavior == 'required' && expiryDate == null && !expirySkipped) {
              return 'Selectează data de expirare';
            }
            return null;
          },
        ),
        if (isOptional && expiryDate == null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onSkip,
            child: Text(
              'Fără dată de expirare →',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EstimatedExpiryBanner extends StatelessWidget {
  final DateTime date;
  const _EstimatedExpiryBanner({required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final days = date.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimăm că expiră pe $formatted',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Aproximativ ${days > 0 ? "$days zile" : "azi sau mâine"} de la adăugare',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeBadge extends StatelessWidget {
  final String barcode;
  const _BarcodeBadge({required this.barcode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Barcode: $barcode',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expiredRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.expiredRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.expiredRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.expiredRed),
            ),
          ),
        ],
      ),
    );
  }
}
