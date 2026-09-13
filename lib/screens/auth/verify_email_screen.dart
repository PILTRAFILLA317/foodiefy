import 'dart:async';
import 'package:flutter/material.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_errors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onUseAnotherEmail,
  });
  final String email;
  final VoidCallback onUseAnotherEmail;
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _resend() async {
    final session = AppRepositories.session;
    if (_busy || session.resendCooldownSeconds > 0) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await session.resendConfirmation(widget.email);
      if (mounted) {
        setState(
          () =>
              _message = 'Correo reenviado. Revisa también la carpeta de spam.',
        );
      }
    } catch (error, stack) {
      logAuthError(error, stack);
      if (mounted) setState(() => _message = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = AppRepositories.session.resendCooldownSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(widget.email, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text(
            'Te hemos enviado un correo de confirmación. Abre el enlace en este dispositivo para activar tu cuenta y entrar en Foodiefy. Revisa también la carpeta de spam.',
          ),
          const SizedBox(height: 24),
          if (_message != null) Text(_message!, semanticsLabel: _message),
          ElevatedButton(
            onPressed: _busy || seconds > 0 ? null : _resend,
            child: Text(
              _busy
                  ? 'Enviando…'
                  : seconds > 0
                  ? 'Reenviar correo en ${seconds}s'
                  : 'Reenviar correo',
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          TextButton(
            onPressed: _busy ? null : widget.onUseAnotherEmail,
            child: const Text('Utilizar otro email'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
