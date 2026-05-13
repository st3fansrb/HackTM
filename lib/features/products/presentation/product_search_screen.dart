import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../data/open_food_facts_service.dart';

final _offServiceProvider =
    Provider<OpenFoodFactsService>((_) => OpenFoodFactsService());

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState
    extends ConsumerState<ProductSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final service = ref.read(_offServiceProvider);
      final products = await service.search(query.trim());
      if (mounted) {
        setState(() {
          _results = products.map((p) => p.toPrefillMap()).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  void _selectResult(Map<String, dynamic> prefill) {
    context.pushReplacement('/pantry/add', extra: prefill);
  }

  void _addManually() {
    context.pushReplacement('/pantry/add');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caută produs'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Ex: lapte, ouă, broccoli…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : !_hasSearched
                    ? _EmptyHint(onManual: _addManually)
                    : _results.isEmpty
                        ? _NoResults(onManual: _addManually)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _results.length,
                            itemBuilder: (context, i) => _ResultTile(
                              item: _results[i],
                              onTap: () => _selectResult(_results[i]),
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _addManually,
            icon: const Icon(Icons.add),
            label: const Text('Adaugă fără căutare'),
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final brand = item['brand'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    final nutriGrade = item['nutriscoreGrade'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PlaceholderIcon(),
                ),
              )
            : const _PlaceholderIcon(),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: brand != null
            ? Text(brand, style: const TextStyle(fontSize: 12))
            : null,
        trailing: nutriGrade != null
            ? _NutriChip(grade: nutriGrade)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NutriChip extends StatelessWidget {
  final String grade;
  const _NutriChip({required this.grade});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'a': Color(0xFF27AE60),
      'b': Color(0xFF2ECC71),
      'c': Color(0xFFF39C12),
      'd': Color(0xFFE74C3C),
      'e': Color(0xFF922B21),
    };
    final color = colors[grade.toLowerCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade.toUpperCase(),
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('📦', style: TextStyle(fontSize: 22)),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onManual;
  const _EmptyHint({required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔎', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            'Caută un produs din baza de date\nglobală Open Food Facts',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final VoidCallback onManual;
  const _NoResults({required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            'Niciun rezultat găsit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Poți adăuga produsul manual',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onManual,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('Adaugă manual'),
          ),
        ],
      ),
    );
  }
}
