import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/edge_ai_config.dart';
import 'screens/cloud_setup_screen.dart';
import 'services/auth_service.dart';

class EdgeAiBootstrap extends StatefulWidget {
  const EdgeAiBootstrap({
    super.key,
    required this.initialConfig,
    required this.configurationCanChange,
  });

  final EdgeAiConfig initialConfig;
  final bool configurationCanChange;

  @override
  State<EdgeAiBootstrap> createState() => _EdgeAiBootstrapState();
}

class _EdgeAiBootstrapState extends State<EdgeAiBootstrap> {
  EdgeAiConfig? config;
  AuthService? auth;
  String? error;
  bool loading = false;
  late bool configurationCanChange;

  @override
  void initState() {
    super.initState();
    configurationCanChange = widget.configurationCanChange;
    if (widget.initialConfig.cloudConfigured) {
      _activate(widget.initialConfig, persist: false);
    }
  }

  Future<void> _activate(EdgeAiConfig value, {bool persist = true}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final normalized = value.normalized();
      final validationError = normalized.validationError;
      if (validationError != null) throw FormatException(validationError);
      if (persist) await normalized.save();
      final service = AuthService(normalized);
      await service.configure();
      if (!mounted) return;
      setState(() {
        config = normalized;
        auth = service;
        if (persist) configurationCanChange = true;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _demo() {
    final demoConfig = EdgeAiConfig.empty;
    setState(() {
      config = demoConfig;
      auth = AuthService(demoConfig);
      error = null;
    });
  }

  Future<void> _reset() async {
    await auth?.signOut();
    await EdgeAiConfig.clearStored();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (config != null && auth != null) {
      return EdgeAiApp(
        config: config!,
        auth: auth!,
        onResetConfiguration: config!.cloudConfigured && configurationCanChange
            ? _reset
            : null,
      );
    }
    return CloudSetupScreen(
      loading: loading,
      error: error,
      onConfigure: _activate,
      onDemo: _demo,
    );
  }
}
