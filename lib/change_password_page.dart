import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  static const route = '/change-password';
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure1 = true, _obscure2 = true, _obscure3 = true;
  bool _loading = false;

  String? _currentError;
  String? _newError;
  String? _confirmError;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
    });

    if (!_form.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _snack('No signed-in user');
      return;
    }

    setState(() => _loading = true);
    try {
      // Reauthenticate with current password
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _current.text,
      );
      await user.reauthenticateWithCredential(cred);

      // Update to new password
      await user.updatePassword(_new.text);

      if (!mounted) return;
      _snack('Password updated');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        setState(() => _currentError = "Current password is incorrect");
      } else {
        _snack(e.message ?? 'Failed to change password');
      }
    } catch (_) {
      _snack('Failed to change password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              // Current password
              TextFormField(
                controller: _current,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  errorText: _currentError,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                obscureText: _obscure1,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // New password
              TextFormField(
                controller: _new,
                decoration: InputDecoration(
                  labelText: 'New password',
                  errorText: _newError,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                obscureText: _obscure2,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Confirm password
              TextFormField(
                controller: _confirm,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  errorText: _confirmError,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure3 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure3 = !_obscure3),
                  ),
                ),
                obscureText: _obscure3,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _new.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save),
                  label: const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
