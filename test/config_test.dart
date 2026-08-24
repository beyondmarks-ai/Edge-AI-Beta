import 'package:edge_alpha/src/config/edge_ai_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports the public deployment connection file', () {
    final config = EdgeAiConfig.fromConnectionJson('''
      {
        "apiBaseUrl": "https://example.execute-api.us-east-1.amazonaws.com/",
        "awsRegion": "us-east-1",
        "cognitoUserPoolId": "us-east-1_Example123",
        "cognitoClientId": "1234567890abcdefghijklmnop"
      }
    ''').normalized();

    expect(config.validationError, isNull);
    expect(
      config.apiBaseUrl,
      'https://example.execute-api.us-east-1.amazonaws.com',
    );
  });

  test('rejects malformed or insecure connection values', () {
    const config = EdgeAiConfig(
      apiBaseUrl: 'http://insecure.example.com',
      awsRegion: 'not-a-region',
      cognitoUserPoolId: 'bad',
      cognitoClientId: 'short',
    );

    expect(config.validationError, contains('HTTPS'));
  });
}
