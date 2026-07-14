import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateWebBaseUrl(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, e.g. https://diary.example.com';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final trimmed = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    await ref.read(profileNotifierProvider.notifier).updateWebBaseUrl(trimmed);
    if (!mounted) return;
    final result = ref.read(profileNotifierProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.hasError ? 'Failed to save settings' : 'Settings saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Text('Could not load settings'),
              data: (profile) {
                if (!_initialized && profile != null) {
                  _initialized = true;
                  _controller.text = profile.webBaseUrl;
                }
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Web viewer URL',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you deploy the web viewer yourself, set its base '
                        'URL here so share links point at it instead of the '
                        'raw API.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _controller,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Web viewer base URL',
                          hintText: 'https://diary.example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateWebBaseUrl,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: profileAsync.isLoading ? null : _save,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
