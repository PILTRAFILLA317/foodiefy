import 'package:flutter/material.dart';
import 'account_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountForm(mode: AccountMode.login);
}
