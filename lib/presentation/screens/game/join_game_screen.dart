import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';

class JoinGameScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  const JoinGameScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends ConsumerState<JoinGameScreen> {
  late final TextEditingController _codeCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      showSnack(context, 'Der Code muss 6 Zeichen haben', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final game = await ref.read(gameRepositoryProvider).joinGame(code);
      ref.invalidate(activeGamesProvider);
      if (mounted) context.pushReplacement('/game/${game.id}/lobby');
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Spiel beitreten')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.group_add_outlined, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Gib den Spielcode ein',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Du bekommst den Code vom Spielleiter',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), letterSpacing: 8),
                  counterText: '',
                ),
                onChanged: (v) {
                  _codeCtrl.value = _codeCtrl.value.copyWith(text: v.toUpperCase());
                },
                onFieldSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Beitreten',
                onPressed: _join,
                isLoading: _loading,
                icon: Icons.login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
