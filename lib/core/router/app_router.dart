import 'dart:math' show max;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/preferences_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/cart/presentation/cart_scanner_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/meal_planner/domain/weekly_plan.dart';
import '../../features/meal_planner/presentation/chat_screen.dart';
import '../../features/meal_planner/presentation/meal_recipe_detail_screen.dart';
import '../../features/shopping_list/presentation/shopping_list_screen.dart';
import '../../features/pantry/presentation/add_item_screen.dart';
import '../../features/pantry/presentation/pantry_screen.dart';
import '../../features/pantry/presentation/scanner_screen.dart';
import '../../features/products/presentation/product_not_found_screen.dart';
import '../../features/products/presentation/product_search_screen.dart';
import '../../features/recipes/presentation/recipe_detail_screen.dart';
import '../../features/recipes/presentation/recipes_screen.dart';

// ─── Auth change notifier (refreshes router on login/logout) ─────────────────

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

Future<bool> _hasOnboarded(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
    return doc.exists && doc.data()?['householdSize'] != null;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasCompletedPrefs(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
    return doc.data()?['manualPrefs']?['completedOnboarding'] == true;
  } catch (_) {
    return true;
  }
}

// ─── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier();
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;

      if (user == null) {
        return loc == '/login' ? null : '/login';
      }

      if (loc == '/login') {
        final onboarded = await _hasOnboarded(user.uid);
        if (!onboarded) return '/onboarding';
        final prefsCompleted = await _hasCompletedPrefs(user.uid);
        if (!prefsCompleted) return '/preferences?onboarding=true';
        return '/pantry';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(
        path: '/preferences',
        builder: (c, s) => PreferencesScreen(
          showOnboardingBanner:
              s.uri.queryParameters['onboarding'] == 'true',
        ),
      ),
      GoRoute(
        path: '/shopping-list',
        builder: (c, s) => const ShoppingListScreen(),
      ),
      GoRoute(
        path: '/meal-plan/recipe',
        builder: (c, s) =>
            MealRecipeDetailScreen(recipe: s.extra as MealRecipe),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ShellScreen(shell),
        branches: [
          // 0 — Frigider
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pantry',
              builder: (c, s) => const PantryScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (c, s) => AddItemScreen(
                    prefill: s.extra as Map<String, dynamic>?,
                  ),
                ),
                GoRoute(
                  path: 'product-not-found',
                  builder: (c, s) {
                    final extra =
                        s.extra as Map<String, String>?;
                    return ProductNotFoundScreen(
                        barcode: extra?['barcode']);
                  },
                ),
                GoRoute(
                  path: 'search',
                  builder: (c, s) => const ProductSearchScreen(),
                ),
                GoRoute(
                  path: 'scanner',
                  builder: (c, s) => const ScannerScreen(),
                ),
              ],
            ),
          ]),
          // 1 — Rețete
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/recipes',
              builder: (c, s) => const RecipesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (c, s) => RecipeDetailScreen(
                    recipeId: s.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),
          // 2 — AI Chat
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (c, s) => const ChatScreen(),
            ),
          ]),
          // 3 — Coș
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (c, s) => const CartScreen(),
              routes: [
                GoRoute(
                  path: 'scanner',
                  builder: (c, s) => const CartScannerScreen(),
                ),
              ],
            ),
          ]),
          // 4 — Profil
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

// ─── Shell with bottom nav ────────────────────────────────────────────────────

class _ShellScreen extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ShellScreen(this.shell);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _BottomNav(
        currentIndex: shell.currentIndex,
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

// ─── Custom bottom nav ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  // index 2 (AI) is rendered separately as _AiNavItem
  static const _tabs = [
    (Icons.kitchen_outlined,          Icons.kitchen,           'Frigider'),
    (Icons.menu_book_outlined,        Icons.menu_book,         'Rețete'),
    (Icons.auto_awesome_outlined,     Icons.auto_awesome,      ''),      // AI — special
    (Icons.shopping_cart_outlined,    Icons.shopping_cart,     'Coș'),
    (Icons.person_outline,            Icons.person,            'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: Color(0x12073B3A), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) {
                  if (i == 2) {
                    return _AiNavItem(
                      isActive: i == currentIndex,
                      onTap: () => onTap(i),
                    );
                  }
                  return _NavItem(
                    inactiveIcon: _tabs[i].$1,
                    activeIcon: _tabs[i].$2,
                    label: _tabs[i].$3,
                    isActive: i == currentIndex,
                    onTap: () => onTap(i),
                  );
                },
              ),
            ),
          ),
          // iOS PWA: MediaQuery.padding.bottom may return 0 in standalone mode even
          // when the home indicator is present, so enforce a 20px minimum.
          SizedBox(height: max(MediaQuery.of(context).padding.bottom, 20.0)),
        ],
      ),
    );
  }
}

// ─── AI center tab (gradient, no label) ──────────────────────────────────────

class _AiNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _AiNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.darkTeal, AppColors.darkEmerald],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.darkTeal.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.darkTeal.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              isActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Regular nav item ─────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: isActive ? AppColors.jungle : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? activeIcon : inactiveIcon,
                    size: 22,
                    color: isActive ? AppColors.darkTeal : AppColors.textMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isActive ? AppColors.darkTeal : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
