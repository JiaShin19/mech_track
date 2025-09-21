// main.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mech_track/profile.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'notes_list_page.dart';
import 'change_password_page.dart';
import 'splash_screen.dart';

// New imports for role-based dashboards
import 'staff_main.dart';
import 'admin/admin_main.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B384C)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        }),
      ),
      home: const AuthGate(),
      routes: {
        LoginPage.route: (_) => const LoginPage(),
        NotesListPage.route: (_) => const NotesListPage(),
        ChangePasswordPage.route: (_) => const ChangePasswordPage(),
        ProfilePage.route: (_) => const ProfilePage(),
        SettingsPage.route: (_) => const SettingsPage(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final ready = snap.connectionState != ConnectionState.waiting;
        if (ready && !_splashDone) {
          _splashDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FlutterNativeSplash.remove();
          });
        }

        if (!ready) return const SizedBox.shrink();

        if (snap.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snap.data!.uid)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDoc = snapshot.data!;
              if (!userDoc.exists) {
                // Show a helpful message or auto-create the user profile (see below)
                return const Center(child: Text("Account not found. Please contact admin."));
              }

              final role = userDoc['role'] ?? 'staff';

              if (role == 'admin') {
                return const AdminMainScreen();
              } else {
                return const StaffMainScreen();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}