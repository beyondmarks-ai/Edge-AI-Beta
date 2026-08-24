import 'package:flutter/material.dart';

import 'src/bootstrap.dart';
import 'src/config/edge_ai_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stored = await EdgeAiConfig.loadStored();
  final environment = EdgeAiConfig.fromEnvironment().normalized();
  final initial = stored ?? environment;
  runApp(
    EdgeAiBootstrap(
      initialConfig: initial,
      configurationCanChange: stored != null || !environment.cloudConfigured,
    ),
  );
}
