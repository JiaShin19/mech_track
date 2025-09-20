import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'change_password_page.dart';

class SettingsPage extends StatelessWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  DocumentReference<Map<String, dynamic>> _prefsDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('meta').doc('prefs');

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final prefsRef = _prefsDoc(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        foregroundColor: Color(0xFFF0F4F3),
        backgroundColor: const Color(0xFF2B384C),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: prefsRef.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final dark = (data['darkMode'] as bool?) ?? false;
          final notif = (data['notifications'] as bool?) ?? true;
          final wifiOnly = (data['wifiOnly'] as bool?) ?? false;
          final textScale = (data['textScale'] as num?)?.toDouble() ?? 1.0;
          final LocalAuthentication auth = LocalAuthentication();

          Future<void> _set(String field, dynamic value) =>
              prefsRef.set({field: value}, SetOptions(merge: true));

          Future<void> _requestNotif() async {
            final settings = await FirebaseMessaging.instance.requestPermission();
            final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
            await _set('notifications', granted);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(granted ? 'Notifications enabled' : 'Notifications disabled')),
            );
          }

          Future<void> _setupAppLock() async {
            final canCheck = await auth.isDeviceSupported() && await auth.canCheckBiometrics;
            if (!canCheck) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biometrics not available on this device')),
              );
              return;
            }
            final ok = await auth.authenticate(
              localizedReason: 'Enable biometric lock for MechTrack',
              options: const AuthenticationOptions(biometricOnly: true),
            );
            await _set('biometricLock', ok);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? 'Biometric lock enabled' : 'Cancelled')),
            );
          }

          Future<void> _contactSupport() async {
            final uri = Uri(
              scheme: 'mailto',
              path: 'support@mechtrack.example',
              query: Uri(queryParameters: {
                'subject': 'MechTrack Support',
                'body': 'Hi, I need help with ...'
              }).query,
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }

          return ListView(
            children: [
              const _SectionHeader('Account'),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name = data?['name'] ?? 'Unnamed user'; // fallback if still empty
                  final email = user.email ?? '';

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(name),
                    subtitle: Text(email),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Change Password'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
              ),
              const Divider(),

              const _SectionHeader('Security & Privacy'),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('App lock with biometrics'),
                value: (data['biometricLock'] as bool?) ?? false,
                onChanged: (_) => _setupAppLock(),
              ),
              const Divider(),

              const _SectionHeader('Notifications'),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Enable push notifications'),
                value: notif,
                onChanged: (_) => _requestNotif(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.wifi),
                title: const Text('Sync on Wi-Fi only'),
                value: wifiOnly,
                onChanged: (v) => _set('wifiOnly', v),
              ),
              const Divider(),

              const _SectionHeader('App & UI'),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark mode'),
                value: dark,
                onChanged: (v) => _set('darkMode', v),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Text size'),
                subtitle: Slider(
                  min: 0.9,
                  max: 1.3,
                  divisions: 4,
                  label: textScale.toStringAsFixed(2),
                  value: textScale,
                  onChanged: (v) => _set('textScale', v),
                ),
              ),
              const Divider(),

              const _SectionHeader('Data & Storage'),
              SwitchListTile(
                secondary: const Icon(Icons.backup),
                title: const Text('Auto-backup photos to Cloud Storage'),
                value: (data['autoBackup'] as bool?) ?? false,
                onChanged: (v) => _set('autoBackup', v),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Clear cache'),
                onTap: () async {
                  imageCache.clear();
                  imageCache.clearLiveImages();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                  }
                },
              ),
              const Divider(),

              const _SectionHeader('Support & About'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: const Text('MechTrack • v1.0.0'),
                onTap: () {/* show about dialog if you want */},
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contact Support'),
                onTap: _contactSupport,
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}