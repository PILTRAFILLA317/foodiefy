import 'package:flutter/material.dart';
import '../../repositories/app_repositories.dart';

enum AccountMode { login, register, recover, newPassword }

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, required this.mode});
  final AccountMode mode;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _message;
  String get _title => switch (widget.mode) {
    AccountMode.login => 'Iniciar sesión',
    AccountMode.register => 'Crear cuenta',
    AccountMode.recover => 'Recuperar contraseña',
    AccountMode.newPassword => 'Nueva contraseña',
  };
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final session = AppRepositories.session;
      switch (widget.mode) {
        case AccountMode.login:
          await session.signIn(_email.text, _password.text);
          if (mounted) Navigator.pop(context, true);
        case AccountMode.register:
          final signedIn = await session.register(_email.text, _password.text);
          if (!mounted) return;
          if (signedIn) {
            Navigator.pop(context, true);
          } else {
            setState(
              () => _message =
                  'Solicitud enviada. Si procede, recibirás un correo de confirmación. Todavía no hay sesión; abre el enlace y vuelve a iniciar sesión.',
            );
          }
        case AccountMode.recover:
          await session.recover(_email.text);
          if (mounted) {
            setState(
              () => _message =
                  'Si la cuenta existe, recibirás un enlace de recuperación. Ábrelo en este dispositivo.',
            );
          }
        case AccountMode.newPassword:
          await session.updatePassword(_password.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'No se pudo completar la solicitud. Revisa los datos y la conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!AppRepositories.session.configured)
            const Text('Autenticación deshabilitada en rescate local.'),
          if (widget.mode != AccountMode.newPassword)
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v != null && v.contains('@')
                  ? null
                  : 'Introduce un email válido.',
            ),
          if (widget.mode != AccountMode.recover)
            TextFormField(
              controller: _password,
              obscureText: true,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (v) =>
                  (v?.length ?? 0) >= 8 ? null : 'Usa al menos 8 caracteres.',
            ),
          if ([
            AccountMode.register,
            AccountMode.newPassword,
          ].contains(widget.mode))
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
              ),
              validator: (v) =>
                  v == _password.text ? null : 'Las contraseñas no coinciden.',
            ),
          const SizedBox(height: 24),
          if (_message != null) Text(_message!, semanticsLabel: _message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy || !AppRepositories.session.configured
                ? null
                : _submit,
            child: Text(_busy ? 'Conectando…' : _title),
          ),
          if (widget.mode == AccountMode.login) ...[
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AccountForm(mode: AccountMode.recover),
                      ),
                    ),
              child: const Text('He olvidado mi contraseña'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AccountForm(mode: AccountMode.register),
                      ),
                    ),
              child: const Text('Crear cuenta'),
            ),
          ],
        ],
      ),
    ),
  );
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }
}
