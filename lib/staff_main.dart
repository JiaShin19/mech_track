// staff_main.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_model.dart';
import 'job_detail.dart';
import 'service_history.dart';
import 'summary.dart';
import 'notes_list_page.dart';
import 'data_service.dart';
import 'settings_page.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _prevIndex = 0;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..value = 1.0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    NotesListPage(),
    ServiceHistoryScreen(),
    SummaryScreen(),
  ];

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _prevIndex = _currentIndex;
      _currentIndex = index;
      _fadeCtrl
        ..value = 0.0
        ..forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _prevIndex, children: _screens),
          FadeTransition(
            opacity: _fadeCtrl,
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: "Summary"),
        ],
        selectedItemColor: const Color(0xFF2B384C),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static Widget _statusCard(String title, String count, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFF2B384C)),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(count),
          ],
        ),
      ),
    );
  }

  static Widget _jobCard(BuildContext context, Job job) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.build, color: Color(0xFF2B384C)),
        title: Text(job.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer Name: ${job.customerName}"),
            Text("Status: ${job.status}"),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(job: job),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = DataService.currentJobs;
    final assignedCount = jobs.where((j) => j.status == "Assigned").length;
    final inProgressCount = jobs.where((j) => j.status == "In Progress").length;
    final completedCount = jobs.where((j) => j.status == "Completed").length;
    final user = FirebaseAuth.instance.currentUser;

    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'User';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("MECHTRACK"),
        backgroundColor: const Color(0xFF2B384C),
        foregroundColor: const Color(0xFFF0F4F3),
      ),
      drawer: Builder(
        builder: (context) {
          final authUser = FirebaseAuth.instance.currentUser;
          if (authUser == null) {
            return const Drawer(
              child: SafeArea(
                child: ListTile(title: Text('Not signed in')),
              ),
            );
          }

          final docRef = FirebaseFirestore.instance.collection('users').doc(authUser.uid);

          String _initial(String? s, String? fallback) {
            final t = (s ?? '').trim();
            if (t.isNotEmpty) return t.characters.first.toUpperCase();
            final f = (fallback ?? '').trim();
            return f.isNotEmpty ? f.characters.first.toUpperCase() : 'U';
          }

          return Drawer(
            child: SafeArea(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: docRef.snapshots(),
                builder: (context, snap) {
                  final data = (snap.hasData && snap.data!.exists)
                      ? (snap.data!.data() ?? {})
                      : {};
                  final name = (data['name'] as String?) ?? authUser.displayName ?? 'User';
                  final imageB64 = (data['imageB64'] as String?) ?? '';

                  // Prepare avatar (MemoryImage from base64) or letter fallback
                  ImageProvider? avatarImage;
                  if (imageB64.isNotEmpty) {
                    try {
                      avatarImage = MemoryImage(base64Decode(imageB64));
                    } catch (_) {}
                  }
                  final initial = _initial(name, authUser.displayName);

                  return Column(
                    children: [
                      _drawerHeader(
                        context,
                        name: name,
                        avatarImage: avatarImage,
                        initial: initial,
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _sectionLabel('General'),
                            _navTile(
                              context,
                              icon: Icons.person,
                              label: 'Profile',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).pushNamed('/profile');
                              },
                            ),
                            _navTile(
                              context,
                              icon: Icons.settings,
                              label: 'Settings',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).pushNamed('/settings');
                              },
                            ),
                            const Divider(height: 24),
                            _sectionLabel('Account'),
                            _navTile(
                              context,
                              icon: Icons.logout,
                              label: 'Log Out',
                              isDestructive: true,
                              onTap: () async {
                                final ok = await _confirmSignOut(context);
                                if (ok == true) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusCard("Assigned", assignedCount.toString(), Icons.assignment),
                _statusCard("In Progress", inProgressCount.toString(), Icons.sync),
                _statusCard("Completed", completedCount.toString(), Icons.check_circle),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Task Tracker:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...jobs.map((job) => _jobCard(context, job)).toList(),
            if (jobs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No active jobs",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Check back later for new assignments",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Drawer Header
Widget _drawerHeader(
    BuildContext context, {
      required String name,
      required ImageProvider? avatarImage,
      required String initial,
    }) {
  final cs = Theme.of(context).colorScheme;

  final Color left = const Color(0xFF2B384C);
  final Color right = const Color(0xFF4A5D77);

  return Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [left, right],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
              initial,
              style: TextStyle(
                color: cs.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name.isEmpty ? 'User' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF0F4F3),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _sectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    ),
  );
}

Widget _navTile(
    BuildContext context, {
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isDestructive = false,
    }) {
  final color = isDestructive ? Colors.red.shade700 : const Color(0xFF2B384C);

  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      label,
      style: TextStyle(
        color: isDestructive ? Colors.red.shade700 : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    ),
    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    onTap: onTap,
  );
}

Future<bool> _confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You will need to log in again to access MechTrack.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  ) ??
      false;

  if (ok) {
    await FirebaseAuth.instance.signOut();
  }

  return ok;
}

// Status Summary Cards
Widget _statusCard(String title, String count, IconData icon) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(count),
        ],
      ),
    ),
  );
}

// Job Cards
Widget _jobCard(String jobId, String customer, String status) {
  return Card(
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: ListTile(
      leading: const Icon(Icons.build, color: Colors.indigo),
      title: Text(jobId, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(customer),
          Text(status),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    ),
  );
}
