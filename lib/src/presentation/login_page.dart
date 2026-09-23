import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> go(bool signUp) async {
    setState(() => busy = true);
    try {
      if (signUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (response.session == null) {
          setState(() => message =
              'Check your email to confirm your account, then sign in.');
        } else {
          widget.onSignedIn();
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        widget.onSignedIn();
      }
    } on AuthException catch (e) {
      setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 54,
                      color: Color(0xFF1976D2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MONTHLY BUDGET',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      onSubmitted: (_) => busy ? null : go(false),
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(message!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : () => go(false),
                        child: Text(busy ? 'Please wait...' : 'Sign in'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => go(true),
                      child: const Text('Create account'),
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
}
