import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/auth_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

@immutable
class _LoginState {
  final bool isLoading;
  final String? error;
  final bool isRegisterMode;
  final bool obscurePassword;
  final bool rememberMe;

  const _LoginState({
    this.isLoading = false,
    this.error,
    this.isRegisterMode = false,
    this.obscurePassword = true,
    this.rememberMe = true,
  });

  _LoginState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isRegisterMode,
    bool? obscurePassword,
    bool? rememberMe,
  }) =>
      _LoginState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        isRegisterMode: isRegisterMode ?? this.isRegisterMode,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        rememberMe: rememberMe ?? this.rememberMe,
      );
}

class _LoginNotifier extends StateNotifier<_LoginState> {
  _LoginNotifier(this._repo) : super(const _LoginState());
  final AuthRepository _repo;

  void toggleMode() =>
      state = state.copyWith(isRegisterMode: !state.isRegisterMode, clearError: true);

  void togglePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void toggleRememberMe() =>
      state = state.copyWith(rememberMe: !state.rememberMe);

  Future<String?> submit(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final UserCredential cred;
      if (state.isRegisterMode) {
        cred = await _repo.registerWithEmail(email.trim(), password);
      } else {
        cred = await _repo.signInWithEmail(email.trim(), password, rememberMe: state.rememberMe);
      }
      // New registrations always need onboarding
      final hasProfile = state.isRegisterMode
          ? false
          : await _repo.hasCompletedOnboarding(cred.user!.uid);
      state = state.copyWith(isLoading: false);
      return hasProfile ? '/pantry' : '/onboarding';
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e.code));
      return null;
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'A apărut o eroare. Încearcă din nou.');
      return null;
    }
  }

  String _mapError(String code) => switch (code) {
        'user-not-found' => 'Nu există un cont cu acest email.',
        'wrong-password' ||
        'invalid-credential' =>
          'Email sau parolă incorecte.',
        'email-already-in-use' => 'Email-ul este deja folosit.',
        'weak-password' => 'Parola trebuie să aibă cel puțin 6 caractere.',
        'invalid-email' => 'Adresa de email nu este validă.',
        'too-many-requests' => 'Prea multe încercări. Mai încearcă mai târziu.',
        'network-request-failed' =>
          'Eroare de rețea. Verifică conexiunea la internet.',
        _ => 'A apărut o eroare. Încearcă din nou.',
      };
}

final _loginProvider =
    StateNotifierProvider.autoDispose<_LoginNotifier, _LoginState>(
  (ref) => _LoginNotifier(ref.watch(authRepositoryProvider)),
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final route = await ref
        .read(_loginProvider.notifier)
        .submit(_emailCtrl.text, _passwordCtrl.text);
    if (route != null && mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_loginProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Hero area — green for login, dark gradient for register
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                gradient: state.isRegisterMode
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.darkEmerald, AppColors.darkTeal],
                      )
                    : null,
                color: state.isRegisterMode ? null : AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(48),
                  bottomRight: Radius.circular(48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    _buildLogo(),
                    const SizedBox(height: 40),
                    _buildCard(context, state, theme),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : ref.read(_loginProvider.notifier).toggleMode,
                      child: Text(
                        state.isRegisterMode
                            ? 'Ai deja un cont? Intră în cont'
                            : 'Nu ai cont? Înregistrează-te',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          if (state.isLoading)
            const ModalBarrier(color: Colors.black26),
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        String? dialogError;
        bool sent = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Resetare parolă'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Introdu adresa de email și îți trimitem un link de resetare.'),
                const SizedBox(height: 16),
                if (!sent)
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                if (sent)
                  const Text(
                    'Email trimis! Verifică căsuța poștală.',
                    style: TextStyle(color: AppColors.primary),
                  ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!,
                      style: const TextStyle(color: AppColors.expiredRed)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Închide'),
              ),
              if (!sent)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: emailCtrl.text.trim(),
                      );
                      setDialogState(() {
                        sent = true;
                        dialogError = null;
                      });
                    } on FirebaseAuthException catch (e) {
                      setDialogState(() => dialogError = e.code == 'user-not-found'
                          ? 'Nu există un cont cu acest email.'
                          : 'A apărut o eroare. Încearcă din nou.');
                    }
                  },
                  child: const Text('Trimite'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo+name.png',
      width: 180,
      fit: BoxFit.contain,
    );
  }

  Widget _buildCard(
      BuildContext context, _LoginState state, ThemeData theme) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.isRegisterMode ? 'Creează cont' : 'Intră în cont',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Introdu adresa de email';
                  if (!v.contains('@')) return 'Email invalid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: state.obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Parolă',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      state.obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed:
                        ref.read(_loginProvider.notifier).togglePassword,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Introdu parola';
                  if (state.isRegisterMode && v.length < 6) {
                    return 'Minim 6 caractere';
                  }
                  return null;
                },
              ),
              if (!state.isRegisterMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: state.rememberMe,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) =>
                          ref.read(_loginProvider.notifier).toggleRememberMe(),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(_loginProvider.notifier).toggleRememberMe(),
                      child: Text(
                        'Ține-mă conectat',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => _showForgotPasswordDialog(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Ai uitat parola?',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(state.error!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  child: Text(
                    state.isRegisterMode ? 'Creează cont' : 'Intră în cont',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expiredRed.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expiredRed.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.expiredRed, size: 16),
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

