import 'package:flutter/material.dart';
import 'account_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountForm(mode: AccountMode.register);
}
