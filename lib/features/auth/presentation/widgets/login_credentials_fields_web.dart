// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class LoginCredentialsFields extends StatefulWidget {
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

  static final Set<_LoginCredentialsFieldsState> _instances = {};

  static void syncAutofillValues() {
    for (final instance in _instances) {
      instance._syncFromNativeInputs();
    }
  }

  @override
  State<LoginCredentialsFields> createState() => _LoginCredentialsFieldsState();
}

class _LoginCredentialsFieldsState extends State<LoginCredentialsFields> {
  late final String _viewType;
  late final html.FormElement _form;
  late final html.InputElement _emailInput;
  late final html.InputElement _passwordInput;
  late final html.ButtonElement _toggleButton;
  late final html.DivElement _emailError;
  late final html.DivElement _passwordError;
  Timer? _autofillPoller;
  bool _syncingFromNative = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'diary-login-credentials-${identityHashCode(this)}';
    _createNativeForm();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _form);
    LoginCredentialsFields._instances.add(this);
    widget.emailController.addListener(_syncEmailToNativeInput);
    widget.passwordController.addListener(_syncPasswordToNativeInput);
    _autofillPoller = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncFromNativeInputs(),
    );
  }

  @override
  void didUpdateWidget(LoginCredentialsFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emailController != widget.emailController) {
      oldWidget.emailController.removeListener(_syncEmailToNativeInput);
      widget.emailController.addListener(_syncEmailToNativeInput);
      _syncEmailToNativeInput();
    }
    if (oldWidget.passwordController != widget.passwordController) {
      oldWidget.passwordController.removeListener(_syncPasswordToNativeInput);
      widget.passwordController.addListener(_syncPasswordToNativeInput);
      _syncPasswordToNativeInput();
    }
    _passwordInput.type = widget.obscurePassword ? 'password' : 'text';
    _toggleButton.text = widget.obscurePassword ? 'Show' : 'Hide';
    _renderErrors();
  }

  @override
  void dispose() {
    LoginCredentialsFields._instances.remove(this);
    _autofillPoller?.cancel();
    widget.emailController.removeListener(_syncEmailToNativeInput);
    widget.passwordController.removeListener(_syncPasswordToNativeInput);
    super.dispose();
  }

  void _createNativeForm() {
    _emailInput = html.InputElement(type: 'email')
      ..id = 'diary-login-email'
      ..name = 'username'
      ..autocomplete = 'username'
      ..placeholder = 'Email'
      ..required = true
      ..value = widget.emailController.text;

    _passwordInput = html.InputElement(type: 'password')
      ..id = 'diary-login-password'
      ..name = 'password'
      ..autocomplete = 'current-password'
      ..placeholder = 'Password'
      ..required = true
      ..value = widget.passwordController.text;

    _toggleButton = html.ButtonElement()
      ..type = 'button'
      ..text = widget.obscurePassword ? 'Show' : 'Hide';

    _emailError = html.DivElement()..classes.add('diary-login-field-error');
    _passwordError = html.DivElement()..classes.add('diary-login-field-error');

    final emailLabel = _buildField(_emailInput, _emailError);
    final passwordLabel = _buildField(
      _passwordInput,
      _passwordError,
      trailing: _toggleButton,
    );

    _form = html.FormElement()
      ..classes.add('diary-login-native-form')
      ..autocomplete = 'on'
      ..append(emailLabel)
      ..append(passwordLabel);

    _applyStyles();
    _wireEvents();
    _renderErrors();
  }

  html.Element _buildField(
    html.InputElement input,
    html.DivElement error, {
    html.Element? trailing,
  }) {
    final field = html.DivElement()..classes.add('diary-login-field');
    final icon = html.DivElement()
      ..classes.add('diary-login-icon')
      ..text = input.type == 'password' ? 'lock' : 'email';
    field
      ..append(icon)
      ..append(input);
    if (trailing != null) field.append(trailing);
    return html.DivElement()
      ..classes.add('diary-login-field-wrap')
      ..append(field)
      ..append(error);
  }

  void _applyStyles() {
    _form.style
      ..width = '100%'
      ..display = 'flex'
      ..flexDirection = 'column'
      ..gap = '16px';

    for (final wrapper in _form.querySelectorAll('.diary-login-field-wrap')) {
      (wrapper as html.HtmlElement).style
        ..width = '100%'
        ..display = 'flex'
        ..flexDirection = 'column'
        ..gap = '6px';
    }

    for (final field in _form.querySelectorAll('.diary-login-field')) {
      (field as html.HtmlElement).style
        ..boxSizing = 'border-box'
        ..height = '56px'
        ..width = '100%'
        ..display = 'flex'
        ..alignItems = 'center'
        ..border = '1px solid rgba(120, 120, 120, 0.65)'
        ..borderRadius = '4px'
        ..backgroundColor = 'transparent'
        ..overflow = 'hidden';
    }

    for (final icon in _form.querySelectorAll('.diary-login-icon')) {
      (icon as html.HtmlElement).style
        ..width = '48px'
        ..fontSize = '0'
        ..flex = '0 0 48px';
    }

    for (final input in [_emailInput, _passwordInput]) {
      input.style
        ..boxSizing = 'border-box'
        ..height = '54px'
        ..minWidth = '0'
        ..width = '100%'
        ..border = '0'
        ..outline = '0'
        ..backgroundColor = 'transparent'
        ..color = 'inherit'
        ..font = 'inherit'
        ..fontSize = '16px';
    }

    _toggleButton.style
      ..height = '54px'
      ..padding = '0 12px'
      ..border = '0'
      ..backgroundColor = 'transparent'
      ..color = 'inherit'
      ..font = 'inherit'
      ..cursor = 'pointer';

    for (final error in [_emailError, _passwordError]) {
      error.style
        ..paddingLeft = '12px'
        ..color = '#BA1A1A'
        ..fontSize = '12px'
        ..lineHeight = '18px';
    }
  }

  void _wireEvents() {
    _form.onSubmit.listen((event) {
      event.preventDefault();
      _syncFromNativeInputs();
      widget.onPasswordSubmitted();
    });
    _emailInput.onInput.listen((_) => _syncFromNativeInputs());
    _emailInput.onChange.listen((_) => _syncFromNativeInputs());
    _passwordInput.onInput.listen((_) => _syncFromNativeInputs());
    _passwordInput.onChange.listen((_) => _syncFromNativeInputs());
    _emailInput.onFocus.listen((_) => widget.emailFocusNode.requestFocus());
    _passwordInput.onFocus.listen(
      (_) => widget.passwordFocusNode.requestFocus(),
    );
    _toggleButton.onClick.listen((_) => widget.onTogglePasswordVisibility());
  }

  void _syncFromNativeInputs() {
    if (!mounted) return;
    _syncingFromNative = true;
    try {
      final emailValue = _emailInput.value ?? '';
      if (widget.emailController.text != emailValue) {
        widget.emailController.text = emailValue;
      }
      final passwordValue = _passwordInput.value ?? '';
      if (widget.passwordController.text != passwordValue) {
        widget.passwordController.text = passwordValue;
      }
    } finally {
      _syncingFromNative = false;
    }
  }

  void _syncEmailToNativeInput() {
    if (_syncingFromNative) return;
    if (_emailInput.value != widget.emailController.text) {
      _emailInput.value = widget.emailController.text;
    }
  }

  void _syncPasswordToNativeInput() {
    if (_syncingFromNative) return;
    if (_passwordInput.value != widget.passwordController.text) {
      _passwordInput.value = widget.passwordController.text;
    }
  }

  void _renderErrors() {
    _emailError.text = widget.emailErrorText ?? '';
    _passwordError.text = widget.passwordErrorText ?? '';
    _emailError.style.display = widget.emailErrorText == null
        ? 'none'
        : 'block';
    _passwordError.style.display = widget.passwordErrorText == null
        ? 'none'
        : 'block';
  }

  void _applyTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final textColor = _toCssColor(scheme.onSurface);
    final backgroundColor = _toCssColor(scheme.surface);
    final borderColor = _toCssColor(scheme.outline);
    final errorColor = _toCssColor(scheme.error);

    _form.style
      ..color = textColor
      ..fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'sans-serif';
    for (final field in _form.querySelectorAll('.diary-login-field')) {
      (field as html.HtmlElement).style
        ..borderColor = borderColor
        ..backgroundColor = backgroundColor;
    }
    for (final input in [_emailInput, _passwordInput]) {
      input.style
        ..color = textColor
        ..setProperty(
          'color-scheme',
          theme.brightness == Brightness.dark ? 'dark' : 'light',
        );
    }
    _toggleButton.style.color = textColor;
    for (final error in [_emailError, _passwordError]) {
      error.style.color = errorColor;
    }
  }

  String _toCssColor(Color color) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    return 'rgba($red, $green, $blue, ${color.a})';
  }

  @override
  Widget build(BuildContext context) {
    _applyTheme(Theme.of(context));
    final needsErrorSpace =
        widget.emailErrorText != null || widget.passwordErrorText != null;
    return SizedBox(
      height: needsErrorSpace ? 176 : 128,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
