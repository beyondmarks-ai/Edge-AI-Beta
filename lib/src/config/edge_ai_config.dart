import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EdgeAiConfig {
  const EdgeAiConfig({
    required this.apiBaseUrl,
    required this.awsRegion,
    required this.cognitoUserPoolId,
    required this.cognitoClientId,
  });

  factory EdgeAiConfig.fromEnvironment() => const EdgeAiConfig(
    apiBaseUrl: String.fromEnvironment('EDGE_AI_API_URL'),
    awsRegion: String.fromEnvironment(
      'EDGE_AI_AWS_REGION',
      defaultValue: 'us-east-1',
    ),
    cognitoUserPoolId: String.fromEnvironment('EDGE_AI_COGNITO_USER_POOL_ID'),
    cognitoClientId: String.fromEnvironment('EDGE_AI_COGNITO_CLIENT_ID'),
  );

  factory EdgeAiConfig.fromJson(Map<String, dynamic> json) => EdgeAiConfig(
    apiBaseUrl: (json['apiBaseUrl'] ?? json['apiUrl'] ?? '').toString().trim(),
    awsRegion: (json['awsRegion'] ?? 'us-east-1').toString().trim(),
    cognitoUserPoolId: (json['cognitoUserPoolId'] ?? '').toString().trim(),
    cognitoClientId: (json['cognitoClientId'] ?? '').toString().trim(),
  );

  factory EdgeAiConfig.fromConnectionJson(String source) =>
      EdgeAiConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(source) as Map),
      );

  static const empty = EdgeAiConfig(
    apiBaseUrl: '',
    awsRegion: 'us-east-1',
    cognitoUserPoolId: '',
    cognitoClientId: '',
  );

  static const _storageKey = 'edge_ai_cloud_connection_v1';

  static Future<EdgeAiConfig?> loadStored() async {
    final source = (await SharedPreferences.getInstance()).getString(
      _storageKey,
    );
    if (source == null || source.isEmpty) return null;
    try {
      final config = EdgeAiConfig.fromConnectionJson(source).normalized();
      return config.validationError == null ? config : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save() async {
    final config = normalized();
    final error = config.validationError;
    if (error != null) throw FormatException(error);
    await (await SharedPreferences.getInstance()).setString(
      _storageKey,
      jsonEncode(config.toJson()),
    );
  }

  static Future<void> clearStored() async =>
      (await SharedPreferences.getInstance()).remove(_storageKey);

  final String apiBaseUrl;
  final String awsRegion;
  final String cognitoUserPoolId;
  final String cognitoClientId;

  bool get cloudConfigured =>
      apiBaseUrl.isNotEmpty &&
      cognitoUserPoolId.isNotEmpty &&
      cognitoClientId.isNotEmpty;

  EdgeAiConfig normalized() => EdgeAiConfig(
    apiBaseUrl: apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
    awsRegion: awsRegion.trim(),
    cognitoUserPoolId: cognitoUserPoolId.trim(),
    cognitoClientId: cognitoClientId.trim(),
  );

  String? get validationError {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'API URL must be a valid HTTPS address.';
    }
    if (!RegExp(r'^[a-z]{2}(-gov)?-[a-z]+-\d$').hasMatch(awsRegion)) {
      return 'Enter a valid AWS region, for example us-east-1.';
    }
    if (!RegExp(
      r'^[a-z]{2}(-gov)?-[a-z]+-\d_[A-Za-z0-9]+$',
    ).hasMatch(cognitoUserPoolId)) {
      return 'Enter a valid Cognito User Pool ID.';
    }
    if (!RegExp(r'^[a-z0-9]{20,128}$').hasMatch(cognitoClientId)) {
      return 'Enter a valid Cognito App Client ID.';
    }
    return null;
  }

  Map<String, String> toJson() => {
    'apiBaseUrl': normalized().apiBaseUrl,
    'awsRegion': awsRegion,
    'cognitoUserPoolId': cognitoUserPoolId,
    'cognitoClientId': cognitoClientId,
  };

  String get amplifyConfiguration => jsonEncode({
    'UserAgent': 'aws-amplify-cli/2.0',
    'Version': '1.0',
    'auth': {
      'plugins': {
        'awsCognitoAuthPlugin': {
          'CognitoUserPool': {
            'Default': {
              'PoolId': cognitoUserPoolId,
              'AppClientId': cognitoClientId,
              'Region': awsRegion,
            },
          },
          'Auth': {
            'Default': {'authenticationFlowType': 'USER_SRP_AUTH'},
          },
        },
      },
    },
  });
}
