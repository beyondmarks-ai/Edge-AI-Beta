import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/config/edge_ai_config.dart';
import 'src/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EdgeAiConfig.fromEnvironment();
  final auth = AuthService(config);
  await auth.configure();
  runApp(EdgeAiApp(config: config, auth: auth));
}
