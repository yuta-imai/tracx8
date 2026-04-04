import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';

/// Settings screen for configuring the backend URL.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _testing = false;
  bool? _testResult;

  static const _prefsKey = 'backend_url';
  static const defaultUrl = 'https://tracx8-backend.<your-subdomain>.workers.dev';

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefsKey) ?? '';
    _urlController.text = url;
  }

  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _urlController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backend URL saved')),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final client = ApiClient(baseUrl: url);
    final ok = await client.healthCheck();
    client.dispose();

    setState(() {
      _testing = false;
      _testResult = ok;
    });
  }

  static Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backend URL',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: defaultUrl,
                border: const OutlineInputBorder(),
                suffixIcon: _testing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.network_check),
                        tooltip: 'Test connection',
                        onPressed: _testConnection,
                      ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _testResult! ? Icons.check_circle : Icons.error,
                    color: _testResult! ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _testResult! ? 'Connection successful' : 'Connection failed',
                    style: TextStyle(
                      color: _testResult! ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveUrl,
              child: const Text('Save'),
            ),
            const SizedBox(height: 32),
            Text(
              'Upload',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When a backend URL is configured, data will be uploaded '
              'to the server in real-time alongside local CSV logging. '
              'If the connection is lost, data is buffered and retried automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
