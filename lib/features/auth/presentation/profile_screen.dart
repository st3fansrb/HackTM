import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/condiments_picker.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../domain/user_profile.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _roMonths = [
  'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
  'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie',
];

// ─── Local edit state ─────────────────────────────────────────────────────────

class _EditNotifier extends StateNotifier<UserProfile?> {
  _EditNotifier() : super(null);

  void sync(UserProfile p) => state = p;

  Future<void> _write(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set(fields, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> setHouseholdSize(int v) async {
    state = state?.copyWith(householdSize: v);
    await _write({'householdSize': v});
  }

  Future<void> toggleNotification(String key, bool val) async {
    final map = Map<String, bool>.from(state?.notifications ?? {});
    map[key] = val;
    state = state?.copyWith(notifications: map);
    await _write({'notifications': map});
  }

  Future<void> setCondiments(List<String> val) async {
    state = state?.copyWith(ownedCondiments: val);
    await _write({'ownedCondiments': val});
  }

  Future<void> setDisplayName(String name) async {
    state = state?.copyWith(displayName: name);
    await _write({'displayName': name});
  }
}

final _editProvider =
    StateNotifierProvider.autoDispose<_EditNotifier, UserProfile?>(
  (ref) {
    final notifier = _EditNotifier();
    // Pre-populate immediately if profileProvider already has a cached value
    ref.read(profileProvider).whenData((p) {
      if (p != null) notifier.sync(p);
    });
    return notifier;
  },
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _statsSynced = false;

  Future<void> _writeComputedStats(UserProfile p) async {
    if (_statsSynced) return;
    _statsSynced = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.doc('users/$uid').set(
        {'kgSaved': p.kgSaved, 'activeDays': p.activeDays},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void _showEditNameDialog(UserProfile profile) {
    final ctrl = TextEditingController(text: profile.displayName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editează numele'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Numele tău'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(_editProvider.notifier).setDisplayName(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (_, next) {
      next.whenData((p) {
        if (p != null) {
          ref.read(_editProvider.notifier).sync(p);
          _writeComputedStats(p);
        }
      });
    });

    final global = ref.watch(profileProvider);
    final profile = ref.watch(_editProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FrigoHeader(title: 'Profil'),
      body: global.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _LoadError(
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (_) {
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  profile: profile,
                  onEditName: () => _showEditNameDialog(profile),
                ),
                const SizedBox(height: 16),
                _ImpactCard(profile: profile),
                const SizedBox(height: 16),
                _HouseholdCard(
                  profile: profile,
                  onSizeChanged: (v) =>
                      ref.read(_editProvider.notifier).setHouseholdSize(v),
                ),
                const SizedBox(height: 16),
                _CondimentsCard(
                  profile: profile,
                  onChanged: (val) =>
                      ref.read(_editProvider.notifier).setCondiments(val),
                ),
                const SizedBox(height: 16),
                _NotificationsCard(
                  profile: profile,
                  onToggle: (key, val) => ref
                      .read(_editProvider.notifier)
                      .toggleNotification(key, val),
                ),
                const SizedBox(height: 16),
                _PreferencesCard(
                  onTap: () => context.push('/preferences'),
                ),
                const SizedBox(height: 24),
                _LogoutButton(
                  onLogout: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onEditName;
  const _Header({required this.profile, this.onEditName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        profile.displayName.isEmpty ? 'Utilizator' : profile.displayName;
    final initials = _initials(profile.displayName);
    final since = profile.createdAt != null
        ? '${_roMonths[profile.createdAt!.month - 1]} ${profile.createdAt!.year}'
        : null;

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primary.withValues(alpha:0.15),
          child: Text(
            initials,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onEditName,
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          since != null
              ? 'Membru din $since · ${profile.activeDays} zile active'
              : '${profile.activeDays} zile active',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '👤';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─── Impact Card ──────────────────────────────────────────────────────────────

class _ImpactCard extends StatelessWidget {
  final UserProfile profile;
  const _ImpactCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final kg = profile.kgSaved.toStringAsFixed(1);
    final lei = (profile.kgSaved * 15).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66DDB771)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌍', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Impactul tău',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ImpactStat(value: '$kg kg', label: 'risipă evitată'),
              _ImpactStat(value: '$lei lei', label: 'economisiți'),
              _ImpactStat(
                  value: '${profile.activeDays}', label: 'zile active'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String value;
  final String label;
  const _ImpactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Household Card ───────────────────────────────────────────────────────────

class _HouseholdCard extends StatelessWidget {
  final UserProfile profile;
  final void Function(int) onSizeChanged;

  const _HouseholdCard({
    required this.profile,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'Gospodărie',
      child: Row(
        children: [
          Expanded(
            child:
                Text('Persoane în casă', style: theme.textTheme.bodyMedium),
          ),
          _Stepper(
            value: profile.householdSize,
            min: 1,
            max: 8,
            onChanged: onSizeChanged,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.divider,
          ),
          color: enabled
              ? AppColors.primary.withValues(alpha:0.08)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Condiments Card ─────────────────────────────────────────────────────────

class _CondimentsCard extends StatelessWidget {
  final UserProfile profile;
  final void Function(List<String>) onChanged;

  const _CondimentsCard({required this.profile, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '🧂 Condimente & Bază',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selectate automat excluse din lista de cumpărături',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          CondimentsPicker(
            selected: profile.ownedCondiments,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Notifications Card ───────────────────────────────────────────────────────

class _NotificationsCard extends StatelessWidget {
  final UserProfile profile;
  final void Function(String key, bool val) onToggle;

  const _NotificationsCard({
    required this.profile,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final n = profile.notifications;
    return _SectionCard(
      title: 'Notificări',
      child: Column(
        children: [
          _NotifRow(
            label: 'Alerte expirare',
            value: n['expiry_alerts'] ?? true,
            onChanged: (v) => onToggle('expiry_alerts', v),
          ),
          _NotifRow(
            label: 'Sugestii zilnice AI',
            value: n['daily_suggestions'] ?? true,
            onChanged: (v) => onToggle('daily_suggestions', v),
          ),
          _NotifRow(
            label: 'Rezumat săptămânal',
            value: n['weekly_summary'] ?? false,
            onChanged: (v) => onToggle('weekly_summary', v),
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}

// ─── Shared section card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Preferences card ────────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PreferencesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: const Icon(Icons.tune_outlined, color: AppColors.primary),
        title: const Text(
          'Preferințe alimentare',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Alergii, restricții, ingrediente evitate',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

// ─── Logout button ────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onLogout,
      icon: const Icon(Icons.logout, color: AppColors.expiredRed),
      label: const Text(
        'Deconectare',
        style: TextStyle(color: AppColors.expiredRed, fontSize: 16),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.expiredRed),
        minimumSize: const Size(double.infinity, 54),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.expiredRed, size: 48),
          const SizedBox(height: 12),
          Text(
            'Nu am putut încărca profilul.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Încearcă din nou'),
          ),
        ],
      ),
    );
  }
}
