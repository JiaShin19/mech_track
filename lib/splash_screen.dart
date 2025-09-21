// pubspec.yaml dependencies needed:
// flutter_native_splash: ^2.3.2
// Then run: flutter pub run flutter_native_splash:create

import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF2B384C),
      backgroundColor: const Color(0xFFF0F4F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 360),
            const SizedBox(height: 16),
            // const CircularProgressIndicator(color: Colors.white),
            const CircularProgressIndicator(color: Color(0xFF2B384C)),
          ],
        ),
      ),
    );
  }
}