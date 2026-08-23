import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onSignedIn});
  final AuthService auth;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final code = TextEditingController();
  bool loading = false;
  bool createAccount = false;
  bool awaitingCode = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (awaitingCode) {
        await widget.auth.confirmSignUp(email: username.text, code: code.text);
        await widget.auth.signIn(username.text, password.text);
        widget.onSignedIn();
      } else if (createAccount) {
        if (name.text.trim().isEmpty) {
          throw StateError('Enter your full name.');
        }
        final complete = await widget.auth.signUp(
          email: username.text,
          password: password.text,
          name: name.text,
        );
        if (complete) {
          await widget.auth.signIn(username.text, password.text);
          widget.onSignedIn();
        } else {
          setState(() => awaitingCode = true);
        }
      } else {
        await widget.auth.signIn(username.text, password.text);
        widget.onSignedIn();
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/branding/edge_ai_logo.png',
                height: 112,
                semanticLabel: 'Edge AI logo',
              ),
              const SizedBox(height: 16),
              Text(
                'Edge AI',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Secure classroom attendance and movement timeline',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!awaitingCode)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in')),
                    ButtonSegment(value: true, label: Text('Student sign up')),
                  ],
                  selected: {createAccount},
                  onSelectionChanged: loading
                      ? null
                      : (value) => setState(() {
                          createAccount = value.first;
                          error = null;
                        }),
                ),
              if (!awaitingCode) const SizedBox(height: 16),
              if (createAccount && !awaitingCode) ...[
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: username,
                enabled: !awaitingCode,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!awaitingCode)
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: createAccount
                        ? '12+ characters with upper, lower, number and symbol'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (awaitingCode) ...[
                const Text('Enter the verification code sent to your email.'),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        awaitingCode
                            ? 'Verify and continue'
                            : createAccount
                            ? 'Create student account'
                            : 'Sign in',
                      ),
              ),
              if (awaitingCode)
                TextButton(
                  onPressed: loading
                      ? null
                      : () => widget.auth.resendConfirmationCode(username.text),
                  child: const Text('Resend code'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
