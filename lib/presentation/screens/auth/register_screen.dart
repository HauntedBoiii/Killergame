import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/app_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _loading = false;
  bool _usernameAvailable = true;
  bool _checkingUsername = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String value) async {
    if (value.length < 3) return;
    setState(() => _checkingUsername = true);
    try {
      final available = await ref.read(authRepositoryProvider).isUsernameAvailable(value);
      if (mounted) setState(() => _usernameAvailable = available);
    } finally {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_usernameAvailable) {
      showSnack(context, 'Benutzername bereits vergeben', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            username: _usernameCtrl.text.trim(),
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showSnack(context, 'Registrierung fehlgeschlagen: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konto erstellen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wähle deinen Codename',
                  style: GoogleFonts.rajdhani(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Niemand darf wissen, wer du wirklich bist.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  onChanged: _checkUsername,
                  validator: (v) {
                    if (v == null || v.length < 3) return 'Mindestens 3 Zeichen';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Nur Buchstaben, Zahlen, _';
                    if (!_usernameAvailable) return 'Bereits vergeben';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: _checkingUsername
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : _usernameCtrl.text.length >= 3
                            ? Icon(
                                _usernameAvailable ? Icons.check_circle : Icons.cancel,
                                color: _usernameAvailable ? Colors.green : Colors.red,
                              )
                            : null,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'E-Mail',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || !v.contains('@') ? 'Ungültige E-Mail' : null,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passCtrl,
                  label: 'Passwort',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.length < 8 ? 'Mindestens 8 Zeichen' : null,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passConfirmCtrl,
                  label: 'Passwort bestätigen',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _passCtrl.text ? 'Passwörter stimmen nicht überein' : null,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Konto erstellen',
                  onPressed: _submit,
                  isLoading: _loading,
                  icon: Icons.person_add,
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Durch die Registrierung stimmst du unseren Datenschutzrichtlinien zu.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
