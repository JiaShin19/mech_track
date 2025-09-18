// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/auth_service.dart';
//
// class SignUpPage extends StatefulWidget {
//   static const route = '/signup';
//   const SignUpPage({super.key});
//
//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }
//
// class _SignUpPageState extends State<SignUpPage> {
//   final _form = GlobalKey<FormState>();
//   final _email = TextEditingController();
//   final _password = TextEditingController();
//   bool _obscure = true;
//   bool _loading = false;
//
//   final _auth = AuthService();
//
//   Future<void> _signup() async {
//     if (!_form.currentState!.validate()) return;
//     setState(() => _loading = true);
//     try {
//       await _auth.signUpWithEmail(_email.text.trim(), _password.text);
//       if (!mounted) return;
//       Navigator.pop(context);
//     } on FirebaseAuthException catch (e) {
//       _snack(e.message ?? 'Sign-up failed');
//     } catch (e) {
//       _snack('Sign-up failed');
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }
//
//   void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Create account')),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 420),
//             child: Form(
//               key: _form,
//               child: Column(
//                 children: [
//                   TextFormField(
//                     controller: _email,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: const InputDecoration(labelText: 'Email'),
//                     validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: _password,
//                     decoration: InputDecoration(
//                       labelText: 'Password',
//                       suffixIcon: IconButton(
//                         icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
//                         onPressed: () => setState(() => _obscure = !_obscure),
//                       ),
//                     ),
//                     obscureText: _obscure,
//                     validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
//                   ),
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     child: FilledButton(
//                       onPressed: _loading ? null : _signup,
//                       child: _loading ? const CircularProgressIndicator() : const Text('Sign up'),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
