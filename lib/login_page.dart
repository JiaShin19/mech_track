import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

class LoginPage extends StatefulWidget {
  static const route = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  final _auth = AuthService();

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _signinEmail() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signInWithEmail(_email.text.trim(), _password.text);

      final storage = SecureStorageService();
      await storage.saveAdminCredentials(
        email: _email.text.trim(),
        password: _password.text,
      );

    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Sign-in failed');
    } catch (_) {
      _snack('Sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter a valid email to reset');
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      _snack('Password reset email sent');
    } catch (_) {
      _snack('Could not send reset email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                    Icons.verified_user, size: 72, color: Color(0xFF2B384C)),
                const SizedBox(height: 12),
                const Text('Welcome back', style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                      (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons
                              .visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      validator: (v) =>
                      (v == null || v.length < 6)
                          ? 'Min 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _loading ? null : _signinEmail,
                          child: _loading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2,))
                              : const Text('Sign in'),
                      ),
                    )
                  ]),
                ),
                const SizedBox(height: 12),
                // OutlinedButton.icon(
                //   onPressed: _loading ? null : _signinGoogle,
                //   icon: const Icon(Icons.login),
                //   label: const Text('Continue with Google'),
                // ),
                // const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}