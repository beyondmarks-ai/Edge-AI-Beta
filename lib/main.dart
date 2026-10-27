import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/bootstrap.dart';
import 'src/config/edge_ai_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Qwen2.5-1.5B-Instruct (Qwen)',
    ], await rootBundle.loadString('assets/licenses/qwen2.5-LICENSE.txt'));
  });
  final stored = await EdgeAiConfig.loadStored();
  final environment = EdgeAiConfig.fromEnvironment().normalized();
  // A tenant-configured build always uses the public connection identifiers
  // embedded at build time. Stored configuration is only for portable builds.
  final initial = environment.cloudConfigured
      ? environment
      : stored ?? environment;
  runApp(
    EdgeAiBootstrap(
      initialConfig: initial,
      configurationCanChange: !environment.cloudConfigured && stored != null,
    ),
  );
}
