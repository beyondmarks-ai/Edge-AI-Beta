import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../config/edge_ai_config.dart';

class AuthService {
  AuthService(this.config);

  final EdgeAiConfig config;
  bool _configured = false;

  bool get enabled => config.cloudConfigured;

  Future<void> configure() async {
    if (!enabled || _configured) return;
    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(config.amplifyConfiguration);
      _configured = true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
    }
  }

  Future<bool> isSignedIn() async {
    if (!enabled) return true;
    return (await Amplify.Auth.fetchAuthSession()).isSignedIn;
  }

  Future<void> signIn(String username, String password) async {
    final result = await Amplify.Auth.signIn(
      username: username.trim(),
      password: password,
    );
    if (!result.isSignedIn) {
      throw StateError('Additional sign-in action is required.');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await Amplify.Auth.signUp(
      username: email.trim(),
      password: password,
      options: SignUpOptions(
        userAttributes: {
          AuthUserAttributeKey.email: email.trim(),
          AuthUserAttributeKey.name: name.trim(),
        },
      ),
    );
    return result.isSignUpComplete;
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final result = await Amplify.Auth.confirmSignUp(
      username: email.trim(),
      confirmationCode: code.trim(),
    );
    if (!result.isSignUpComplete) {
      throw StateError('Account confirmation is not complete.');
    }
  }

  Future<void> resendConfirmationCode(String email) async {
    await Amplify.Auth.resendSignUpCode(username: email.trim());
  }

  Future<void> signOut() async {
    if (enabled) await Amplify.Auth.signOut();
  }

  Future<String?> accessToken() async {
    if (!enabled) return null;
    final session = await Amplify.Auth.fetchAuthSession(
      options: const FetchAuthSessionOptions(forceRefresh: false),
    );
    if (session is! CognitoAuthSession) return null;
    return session.userPoolTokensResult.value.idToken.raw;
  }
}
