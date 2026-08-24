import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/edge_ai_config.dart';

class CloudSetupScreen extends StatefulWidget {
  const CloudSetupScreen({
    super.key,
    required this.loading,
    required this.onConfigure,
    required this.onDemo,
    this.error,
  });

  final bool loading;
  final String? error;
  final Future<void> Function(EdgeAiConfig config) onConfigure;
  final VoidCallback onDemo;

  @override
  State<CloudSetupScreen> createState() => _CloudSetupScreenState();
}

class _CloudSetupScreenState extends State<CloudSetupScreen> {
  final apiUrl = TextEditingController();
  final region = TextEditingController(text: 'us-east-1');
  final userPoolId = TextEditingController();
  final clientId = TextEditingController();
  String? localError;

  @override
  void dispose() {
    apiUrl.dispose();
    region.dispose();
    userPoolId.dispose();
    clientId.dispose();
    super.dispose();
  }

  EdgeAiConfig get value => EdgeAiConfig(
    apiBaseUrl: apiUrl.text,
    awsRegion: region.text,
    cognitoUserPoolId: userPoolId.text,
    cognitoClientId: clientId.text,
  ).normalized();

  Future<void> configure() async {
    final error = value.validationError;
    setState(() => localError = error);
    if (error == null) await widget.onConfigure(value);
  }

  Future<void> importConnection() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked.isEmpty || picked.single.path == null) return;
      final config = EdgeAiConfig.fromConnectionJson(
        await File(picked.single.path!).readAsString(),
      ).normalized();
      final error = config.validationError;
      if (error != null) throw FormatException(error);
      setState(() {
        apiUrl.text = config.apiBaseUrl;
        region.text = config.awsRegion;
        userPoolId.text = config.cognitoUserPoolId;
        clientId.text = config.cognitoClientId;
        localError = null;
      });
    } catch (exception) {
      setState(
        () => localError = 'Could not import connection file: $exception',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5FEF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Set up Edge AI',
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFF0C1020),
        cardTheme: const CardThemeData(color: Color(0xFF151B2F)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/branding/edge_ai_logo.png',
                      height: 116,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connect Edge AI',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Import the public connection file from your GitHub deployment. API keys and AWS credentials must never be entered here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: widget.loading ? null : importConnection,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Import edge-ai-connection.json'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or enter public values'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    _field(
                      apiUrl,
                      'API base URL',
                      'https://example.execute-api.us-east-1.amazonaws.com',
                    ),
                    const SizedBox(height: 12),
                    _field(region, 'AWS region', 'us-east-1'),
                    const SizedBox(height: 12),
                    _field(
                      userPoolId,
                      'Cognito User Pool ID',
                      'us-east-1_Example',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      clientId,
                      'Cognito App Client ID',
                      'Public client identifier',
                    ),
                    if ((localError ?? widget.error) != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        (localError ?? widget.error)!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: widget.loading ? null : configure,
                      icon: widget.loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done_outlined),
                      label: Text(
                        widget.loading ? 'Connecting...' : 'Save and connect',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.loading ? null : widget.onDemo,
                      child: const Text('Explore demo without cloud'),
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

  Widget _field(TextEditingController controller, String label, String hint) =>
      TextField(
        controller: controller,
        enabled: !widget.loading,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      );
}
