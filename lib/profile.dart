// profile.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';

import 'update_profile.dart';

class ProfilePage extends StatelessWidget {
  static const route = '/profile';
  const ProfilePage({super.key});

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Future<void> _ensureUserProfileDoc(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'role': 'staff',
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'phone': '',
        'address': '',
        'imageB64': '',
        'id': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _pickAndSaveAvatar(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> docRef,
      String uid,
      ) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported image file')),
        );
        return;
      }

      final resized = img.copyResize(decoded, width: 512);
      final jpg = img.encodeJpg(resized, quality: 85);
      final b64 = base64Encode(jpg);

      final payload = {
        'imageB64': b64,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final box = await Hive.openBox('profileCache');
      await box.put(uid, payload);

      try {
        await docRef.set({
          'imageB64': b64,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated (offline/online)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update picture: $e')),
        );
      }
    }
  }

  String _initialFromName(String? name, String? fallback) {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n.characters.first.toUpperCase();
    final f = (fallback ?? '').trim();
    if (f.isNotEmpty) return f.characters.first.toUpperCase();
    return 'U';
  }

  static Future<void> syncPendingProfile() async {
    final box = await Hive.openBox('profileCache');
    final keys = box.keys.toList();
    for (final uid in keys) {
      final data = Map<String, dynamic>.from(box.get(uid));
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'imageB64': data['imageB64'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await box.delete(uid);
      } catch (e) {
        print("Profile sync failed for $uid: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final docRef = _users.doc(user.uid);

    return FutureBuilder<void>(
      future: _ensureUserProfileDoc(user),
      builder: (context, initSnap) {
        if (initSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.grey[50],
                foregroundColor: Colors.black87,
                shape: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                titleSpacing: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Row(
                  children: const [
                    SizedBox(width: 8),
                    Icon(Icons.person_outline, color: Color(0xFF2B384C), size: 22),
                    SizedBox(width: 12),
                    Text('Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: docRef.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return FutureBuilder<Box>(
                        future: Hive.openBox('profileCache'),
                        builder: (context, boxSnap) {
                          if (!boxSnap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final box = boxSnap.data!;
                          final cached = box.get(user.uid) as Map?;
                          if (cached == null) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('Profile not available offline')),
                            );
                          }
                          return _buildProfileView(context, user, cached, docRef);
                        },
                      );
                    }

                    final data = snap.data!.data()!;
                    return _buildProfileView(context, user, data, docRef);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileView(BuildContext context, User user, Map data,
      DocumentReference<Map<String, dynamic>> docRef) {
    final name    = (data['name']    ?? '').toString();
    final email   = (data['email']   ?? '').toString();
    final phone   = (data['phone']   ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final staffId = (data['id']      ?? '').toString();
    final imageB64 = (data['imageB64'] as String?) ?? '';

    ImageProvider? avatarImage;
    if (imageB64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(imageB64));
      } catch (_) {
        avatarImage = null;
      }
    }

    final initial = _initialFromName(name, user.displayName);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey[200],
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
              initial,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B384C),
              ),
            )
                : null,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _pickAndSaveAvatar(context, docRef, user.uid),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Change photo'),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.badge),
            title: Text(staffId.isEmpty ? 'No Staff ID' : staffId),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(name.isEmpty ? 'Unnamed' : name),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(email.isNotEmpty ? email : (user.email ?? 'No email')),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(phone.isEmpty ? 'No phone' : phone),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpdateProfilePage(
                    fieldName: 'Phone',
                    currentValue: phone,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(address.isEmpty ? 'No address' : address),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpdateProfilePage(
                    fieldName: 'Address',
                    currentValue: address,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
