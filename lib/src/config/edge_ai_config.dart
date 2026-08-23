import 'dart:convert';

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

  final String apiBaseUrl;
  final String awsRegion;
  final String cognitoUserPoolId;
  final String cognitoClientId;

  bool get cloudConfigured =>
      apiBaseUrl.isNotEmpty &&
      cognitoUserPoolId.isNotEmpty &&
      cognitoClientId.isNotEmpty;

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
