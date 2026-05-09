import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/server_config.dart';
import 'auth_providers.dart';
import 'widgets/login_credentials_fields.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _domainFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _showServerConfig = false;
  String? _emailErrorText;
  String? _passwordErrorText;

  @override
  void initState() {
    super.initState();
    final config = ref.read(serverConfigProvider);
    _domainCtrl.text = config.serverInput;
    _showServerConfig = !config.isConfigured;
    _emailCtrl.addListener(_clearCredentialErrors);
    _passwordCtrl.addListener(_clearCredentialErrors);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_clearCredentialErrors);
    _passwordCtrl.removeListener(_clearCredentialErrors);
    _domainFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  void _clearCredentialErrors() {
    if (_emailErrorText == null && _passwordErrorText == null) return;
    final nextEmailError = _emailCtrl.text.trim().isEmpty
        ? _emailErrorText
        : null;
    final nextPasswordError = _passwordCtrl.text.isEmpty
        ? _passwordErrorText
        : null;
    if (nextEmailError == _emailErrorText &&
        nextPasswordError == _passwordErrorText) {
      return;
    }
    setState(() {
      _emailErrorText = nextEmailError;
      _passwordErrorText = nextPasswordError;
    });
  }

  bool _validateCredentials() {
    final emailError = _emailCtrl.text.trim().isEmpty
        ? 'Email is required'
        : null;
    final passwordError = _passwordCtrl.text.isEmpty
        ? 'Password is required'
        : null;
    setState(() {
      _emailErrorText = emailError;
      _passwordErrorText = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<bool> _saveServerConfig() async {
    final serverInput = _domainCtrl.text.trim();
    if (serverInput.isEmpty) return false;

    await ref.read(serverConfigProvider).saveFromInput(serverInput);
    ref.invalidate(serverConfigProvider);
    return true;
  }

  Future<void> _submit() async {
    LoginCredentialsFields.syncAutofillValues();
    FocusManager.instance.primaryFocus?.unfocus();
    final isFormValid = _formKey.currentState!.validate();
    final areCredentialsValid = _validateCredentials();
    if (!isFormValid || !areCredentialsValid) return;
    final savedServerConfig = await _saveServerConfig();
    if (savedServerConfig && mounted && _showServerConfig) {
      setState(() => _showServerConfig = false);
    }
    await ref
        .read(authNotifierProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (mounted) {
      final state = ref.read(authNotifierProvider);
      if (state.hasValue && state.value == true) {
        TextInput.finishAutofillContext();
        context.go('/home');
      } else if (state.hasError) {
        _showError(state.error.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final isLoading = auth.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Diary',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back. Sign in to continue.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Server config toggle
                    InkWell(
                      onTap: () => setState(
                        () => _showServerConfig = !_showServerConfig,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dns_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Server Configuration',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showServerConfig
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),

                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildServerConfig(),
                      crossFadeState: _showServerConfig
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),

                    const SizedBox(height: 24),

                    LoginCredentialsFields(
                      emailController: _emailCtrl,
                      passwordController: _passwordCtrl,
                      emailFocusNode: _emailFocus,
                      passwordFocusNode: _passwordFocus,
                      obscurePassword: _obscurePassword,
                      emailErrorText: _emailErrorText,
                      passwordErrorText: _passwordErrorText,
                      onPasswordSubmitted: _submit,
                      onTogglePasswordVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text("Don't have an account? Register"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerConfig() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _domainCtrl,
            focusNode: _domainFocus,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
            decoration: const InputDecoration(
              labelText: 'Server URL or Domain',
              hintText: 'e.g. https://api.example.com or api.example.com',
              prefixIcon: Icon(Icons.language_outlined),
            ),
            validator: (v) {
              if (!_showServerConfig) return null;
              if (ServerConfig.parseServerInput(v ?? '') == null) {
                return 'Enter a valid domain or URL';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
