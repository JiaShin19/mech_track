import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mech_track/splash_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:mech_track/login_page.dart';
import 'package:mech_track/change_password_page.dart';
import 'package:mech_track/settings_page.dart';
import 'package:mech_track/notes_list_page.dart';

import 'firebase_options.dart';
import 'job_model.dart';
import 'job_detail.dart';
import 'service_history.dart';
import 'summary.dart';
import 'data_service.dart';
import 'profile.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // WidgetsFlutterBinding.ensureInitialized();
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
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
        SettingsPage.route: (_) => const SettingsPage(),
        ProfilePage.route: (_) => const ProfilePage(),
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

  // @override
  // void initState() {
  //   super.initState();
  //   // Guarantee the splash is visible briefly
  //   Future.delayed(const Duration(milliseconds: 3000), () {
  //     if (mounted) setState(() => _splashDone = true);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // late final Widget child;
        // Show splash until the minimum delay is done OR while the stream is still connecting
        // if (!_splashDone || snap.connectionState == ConnectionState.waiting) {
        //   child = const SplashScreen(key: ValueKey('splash'));
        //   // return const SplashScreen();
        // } else if (snap.hasData) {
        //   child = const MainNavigationScreen(key: ValueKey('main'));
        //   // return const MainNavigationScreen();
        // } else {
        //   child = const LoginPage(key: ValueKey('login'));
        //   // return const LoginPage();
        // }

        // When we have something meaningful to show (not waiting), remove native splash exactly once
        final ready = snap.connectionState != ConnectionState.waiting;
        if (ready && !_splashDone) {
          _splashDone = true;
          // Remove AFTER first frame to ensure smooth handoff
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // FlutterNativeSplash.remove();
            FlutterNativeSplash.remove();
          });
        }

        if (!ready) {
          // While native splash is up, we keep returning an empty widget (no Flutter splash).
          // If for any reason native splash already removed (e.g., hot restart), show a tiny loader.
          return const SizedBox.shrink();
        }

        if (snap.hasData) {
          return const MainNavigationScreen();
        } else {
          return const LoginPage();
        }

        // // Smooth Shared-Axis transition between Splash/Login/Main
        // return PageTransitionSwitcher(
        //   transitionBuilder: (Widget child, Animation<double> primary, Animation<double> secondary) {
        //     return SharedAxisTransition(
        //       animation: primary,
        //       secondaryAnimation: secondary,
        //       transitionType: SharedAxisTransitionType.scaled, // nice for auth→app
        //       child: child,
        //     );
        //   },
        //   duration: const Duration(milliseconds: 450),
        //   reverse: !snap.hasData, // reverse when signing out
        //   child: child,
        // );

        // return AnimatedSwitcher(
        //   duration: const Duration(milliseconds: 280),
        //   switchInCurve: Curves.easeOutCubic,
        //   switchOutCurve: Curves.easeInCubic,
        //   child: child,
        // );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _prevIndex = 0;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..value = 1.0; // first tab shows immediately

  // Keep your tab widgets here. Using const constructors where possible is fine.
  final List<Widget> _screens = const [
    DashboardScreen(),
    NotesListPage(),
    ServiceHistoryScreen(),
    SummaryScreen(),
  ];

  void _onTap(int index) {
    if (index == _currentIndex) return;         // no-op if same tab
    setState(() {
      _prevIndex = _currentIndex;               // remember previous
      _currentIndex = index;
      _fadeCtrl
        ..value = 0.0                           // start from 0
        ..forward();                            // fade new tab in
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
      /* FOR sliding-through-tabs navigation transition */
      // body: PageView(
      //   controller: _controller,
      //   physics: const BouncingScrollPhysics(),
      //   onPageChanged: (i) => setState(() => _currentIndex = i),
      //   children: _screens,
      // ),
      // Both stacks keep tabs mounted (no reload). Only the top one is animated.
      body: Stack(
        children: [
          // Underlay: previous tab (fully visible, no animation)
          IndexedStack(index: _prevIndex, children: _screens),

          // Overlay: current tab (fades in)
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
        // selectedItemColor: Colors.indigo,
        selectedItemColor: const Color(0xFF2B384C),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  static const _brand = Color(0xFF2B384C);

  const DashboardScreen({super.key});

  static Widget _statusCard(String title, String count, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            // Icon(icon, color: Colors.indigo),
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
        // leading: const Icon(Icons.build, color: Colors.indigo),
        leading: const Icon(Icons.build, color: Color(0xFF2B384C),),
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
    // int assignedCount = jobs.where((job) => job.status == "Assigned").length;
    // int inProgressCount = jobs.where((job) => job.status == "In Progress").length;
    // int completedCount = jobs.where((job) => job.status == "Completed").length;

    final assignedCount = jobs.where((j) => j.status == "Assigned").length;
    final inProgressCount = jobs.where((j) => j.status == "In Progress").length;
    final completedCount = jobs.where((j) => j.status == "Completed").length;

    final user = FirebaseAuth.instance.currentUser;

    final name  = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'User';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("MECHTRACK"),
        // backgroundColor: Colors.indigo,
        backgroundColor: Color(0xFF2B384C),
        foregroundColor: const Color(0xFFF0F4F3),
        // actions: [
        //   IconButton(
        //     tooltip: 'Sign Out',
        //     icon: const Icon(Icons.logout),
        //     onPressed: () async {
        //       await FirebaseAuth.instance.signOut();
        //     },
        //   ),
        // ],
      ),
      drawer: Builder(
        builder: (context) {
          final authUser = FirebaseAuth.instance.currentUser;
          if (authUser == null) {
            return const Drawer(child: SafeArea(child: ListTile(title: Text('Not signed in'))));
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
                  final data = (snap.hasData && snap.data!.exists) ? (snap.data!.data() ?? {}) : {};
                  final name    = (data['name'] as String?) ?? authUser.displayName ?? 'User';
                  final imageB64= (data['imageB64'] as String?) ?? '';

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

                      // ... keep the rest of your ListView items ...
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
                                  Navigator.pop(context); // close drawer AFTER confirmed
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
            // Status Summary Row
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
            // _jobCard("JOB-001", "Customer Name: Tan Hui Ling", "Status: In Progress"),
            // _jobCard("JOB-002", "Customer Name: Lee Hui Teng", "Status: Completed"),

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
                          fontWeight: FontWeight.w500,
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

  Widget _drawerHeader(
      BuildContext context, {
        required String name,
        required ImageProvider? avatarImage,
        required String initial,
      }) {
    final cs = Theme.of(context).colorScheme;

    // Feel free to tweak these two colors or swap to cs.primaryContainer etc.
    final Color left = const Color(0xFF2B384C);        // deep slate
    final Color right = const Color(0xFF4A5D77);       // blue-gray

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
          // white ring around avatar
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
    final color = isDestructive ? Colors.red.shade700 : _brand;
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
              child: const Text('Cancel')
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ) ?? false;

    if (ok) {
      await FirebaseAuth.instance.signOut();
    }

    return ok;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF2B384C)),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }

  // Widget for Status Summary Cards
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

  // Widget for Job Cards
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
}

// @override
// Widget build(BuildContext context) {
//   // This method is rerun every time setState is called, for instance as done
//   // by the _incrementCounter method above.
//   //
//   // The Flutter framework has been optimized to make rerunning build methods
//   // fast, so that you can just rebuild anything that needs updating rather
//   // than having to individually change instances of widgets.
//   return Scaffold(
//     appBar: AppBar(
//       // TRY THIS: Try changing the color here to a specific color (to
//       // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//       // change color while the other colors stay the same.
//       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       // Here we take the value from the MyHomePage object that was created by
//       // the App.build method, and use it to set our appbar title.
//       title: Text(widget.title),
//     ),
//     body: Center(
//       // Center is a layout widget. It takes a single child and positions it
//       // in the middle of the parent.
//       child: Column(
//         // Column is also a layout widget. It takes a list of children and
//         // arranges them vertically. By default, it sizes itself to fit its
//         // children horizontally, and tries to be as tall as its parent.
//         //
//         // Column has various properties to control how it sizes itself and
//         // how it positions its children. Here we use mainAxisAlignment to
//         // center the children vertically; the main axis here is the vertical
//         // axis because Columns are vertical (the cross axis would be
//         // horizontal).
//         //
//         // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//         // action in the IDE, or press "p" in the console), to see the
//         // wireframe for each widget.
//         mainAxisAlignment: MainAxisAlignment.center,
//         // children: <Widget>[
//         //   const Text('You have pushed the button this many times:'),
//         //   Text(
//         //     '$_counter',
//         //     style: Theme.of(context).textTheme.headlineMedium,
//         //   ),
//         // ],
//       ),
//     ),
//     // floatingActionButton: FloatingActionButton(
//     //   onPressed: _incrementCounter,
//     //   tooltip: 'Increment',
//     //   child: const Icon(Icons.add),
//     // ), // This trailing comma makes auto-formatting nicer for build methods.
//   );
// }