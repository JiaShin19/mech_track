import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'job_model.dart';
import 'job_detail.dart';
import 'service_history.dart';
import 'summary.dart';
import 'data_service.dart';

// void main() {
//  runApp(const MyApp());
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const NotesScreen(),
      const ServiceHistoryScreen(),
      const SummaryScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: "Summary"),
        ],
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

// Placeholder Notes Screen
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, color: Colors.indigo, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    "Notes",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_add, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "Notes feature coming soon!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Create and manage your work notes here",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
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
            Icon(icon, color: Colors.indigo),
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
        leading: const Icon(Icons.build, color: Colors.indigo),
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
    int assignedCount = jobs.where((job) => job.status == "Assigned").length;
    int inProgressCount = jobs.where((job) => job.status == "In Progress").length;
    int completedCount = jobs.where((job) => job.status == "Completed").length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MECHTRACK"),
        backgroundColor: Colors.indigo,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("Muhammad Azman"),
              accountEmail: null,
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(
                  "https://via.placeholder.com/150",
                ),
              ),
              decoration: BoxDecoration(color: Colors.indigo),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log Out"),
              onTap: () {},
            ),
          ],
        ),
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
                // _statusCard("Assigned", "2", Icons.assignment),
                // _statusCard("In Progress", "1", Icons.sync),
                // _statusCard("Completed", "1", Icons.check_circle),
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
}

//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         currentIndex: 0,
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
//           BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
//           BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
//           BottomNavigationBarItem(icon: Icon(Icons.summarize), label: "Summary"),
//         ],
//         selectedItemColor: Colors.indigo,
//         unselectedItemColor: Colors.grey,
//         onTap: (index) {
//           if (index == 0) {
//             Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
//           } else if (index == 2) {
//             Navigator.pushReplacementNamed(context, '/summary');
//           }
//         },
//       ),
//     );
//   }
// }

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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