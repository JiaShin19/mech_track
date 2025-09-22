import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'manage_staff.dart';
import 'manage_customers.dart';
import 'manage_jobs.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final staffRef = FirebaseFirestore.instance.collection('users');
    final customersRef = FirebaseFirestore.instance.collection('customers');

    List<Widget> _pages() => [
      ManageStaffPage(),
      ManageCustomersPage(),
      ManageJobsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF2B384C),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? "Admin"),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: AssetImage("assets/images/default_avatar.png"),
              ),
              decoration: const BoxDecoration(color: Color(0xFF2B384C)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log Out"),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      body: _pages()[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Staff"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Customers"),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: "Jobs"),
        ],
      ),
    );
  }
}