import 'package:flutter/material.dart';

class LoginCredentialsFields extends StatelessWidget {
  const LoginCredentialsFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.onPasswordSubmitted,
    required this.onTogglePasswordVisibility,
    this.emailErrorText,
    this.passwordErrorText,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final String? emailErrorText;
  final String? passwordErrorText;
  final VoidCallback onPasswordSubmitted;
  final VoidCallback onTogglePasswordVisibility;

  static void syncAutofillValues() {}

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            focusNode: emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              errorText: emailErrorText,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            onFieldSubmitted: (_) => onPasswordSubmitted(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: passwordErrorText,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onTogglePasswordVisibility,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
