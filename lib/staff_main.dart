// staff_main.dart
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("MECHTRACK"),
        backgroundColor: const Color(0xFF2B384C),
        foregroundColor: const Color(0xFFF0F4F3),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? "User"),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage("https://via.placeholder.com/150"),
              ),
              decoration: const BoxDecoration(color: Color(0xFF2B384C)),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(SettingsPage.route);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log Out"),
              onTap: () async {
                FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
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
            const Text("Task Tracker:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      Text("No active jobs",
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text("Check back later for new assignments",
                          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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
