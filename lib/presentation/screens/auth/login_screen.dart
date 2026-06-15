import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showSnack(context, 'Anmeldung fehlgeschlagen: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text('🗡️', style: const TextStyle(fontSize: 64))
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  Text(
                    'MÖRDERSPIEL',
                    style: GoogleFonts.rajdhani(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      letterSpacing: 4,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Wer wird der letzte Überlebende?',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 48),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'E-Mail',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || !v.contains('@') ? 'Ungültige E-Mail' : null,
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passCtrl,
                    label: 'Passwort',
                    prefixIcon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) => v == null || v.length < 6 ? 'Mindestens 6 Zeichen' : null,
                    onChanged: (_) {},
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Anmelden',
                    onPressed: _submit,
                    isLoading: _loading,
                    icon: Icons.login,
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/register'),
                    child: const Text('Noch kein Konto? Jetzt registrieren'),
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
