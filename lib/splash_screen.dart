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
            // const Icon(Icons.build_circle, size: 96, color: Colors.white),
            // const SizedBox(height: 16),
            // const Text(
            //   'MechTrack',
            //   style: TextStyle(
            //     fontSize: 28,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.white,
            //   ),
            // ),
            const SizedBox(height: 16),
            // const CircularProgressIndicator(color: Colors.white),
            const CircularProgressIndicator(color: Color(0xFF2B384C)),
          ],
        ),
      ),
    );
  }
}

// void main() {
//   runApp(MechTrackApp());
// }
//
// class MechTrackApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'MechTrack',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(primarySwatch: Colors.indigo),
//       home: SplashScreen(),
//     );
//   }
// }

// class SplashScreen extends StatefulWidget {
//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     Timer(Duration(seconds: 3), () {
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => HomePage()),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset('assets/logo.png', height: 120),
//             SizedBox(height: 20),
//             Text(
//               'MechTrack',
//               style: TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.indigo,
//               ),
//             ),
//             SizedBox(height: 20),
//             CircularProgressIndicator(),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class HomePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Mechanic Dashboard')),
//       body: Center(child: Text('Welcome to MechTrack!')),
//     );
//   }
// }
