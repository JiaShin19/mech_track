import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/secure_storage_service.dart';

class ManageStaffPage extends StatefulWidget {
  const ManageStaffPage({super.key});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  final CollectionReference staffRef =
  FirebaseFirestore.instance.collection('users');

  late SecureStorageService storage;
  String? adminEmail;
  String? adminPassword;

  @override
  void initState() {
    super.initState();
    storage = SecureStorageService();
    _loadAdminCreds();
  }

  Future<void> _loadAdminCreds() async {
    final creds = await storage.getAdminCredentials();
    setState(() {
      adminEmail = creds['email'];
      adminPassword = creds['password'];
    });

    if (adminEmail == null || adminPassword == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin credentials missing. Please re-login."),
          ),
        );
      }
    }
  }

  void showStaffForm({Map<String, dynamic>? staff, String? docId}) {
    final nameController = TextEditingController(text: staff?["name"] ?? "");
    final emailController = TextEditingController(text: staff?["email"] ?? "");
    final phoneController = TextEditingController(text: staff?["phone"] ?? "");
    final addressController =
    TextEditingController(text: staff?["address"] ?? "");
    final imageController = TextEditingController(text: staff?["image"] ?? "");
    final passwordController = TextEditingController(); // only for new staff

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(staff == null ? "Add Staff" : "Edit Staff"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name")),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email")),
              if (staff == null)
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                      labelText: "Password (for login)"),
                  obscureText: true,
                ),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: "Phone")),
              TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: "Address")),
              TextField(
                controller: TextEditingController(text: "staff"),
                decoration: const InputDecoration(labelText: "Role"),
                enabled: false,
              ),
              TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                      labelText: "Image URL (optional)")),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final address = addressController.text.trim();
              final image = imageController.text.trim().isNotEmpty
                  ? imageController.text.trim()
                  : null;

              if (staff == null) {
                // Add staff
                final password = passwordController.text.trim();
                if (email.isEmpty || password.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                        Text("Name, email, and password are required.")),
                  );
                  return;
                }
                try {
                  // Step 1: create staff
                  UserCredential userCred = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                  String uid = userCred.user!.uid;

                  // Step 2: sign out staff
                  await FirebaseAuth.instance.signOut();

                  // Step 3: re-login as admin
                  if (adminEmail != null && adminPassword != null) {
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: adminEmail!,
                      password: adminPassword!,
                    );
                  }

                  // Step 4: save staff info in Firestore
                  final newStaff = {
                    "id": uid,
                    "name": name,
                    "email": email,
                    "phone": phone,
                    "address": address,
                    "role": "staff",
                    "image": image,
                  };
                  await staffRef.doc(uid).set(newStaff);

                  if (mounted) Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Staff added successfully!")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              } else {
                // Edit staff
                final updatedStaff = {
                  "name": name,
                  "email": email,
                  "phone": phone,
                  "address": address,
                  "role": "staff",
                  "image": image,
                };
                await staffRef.doc(docId!).update(updatedStaff);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Staff")),
      body: StreamBuilder<QuerySnapshot>(
        stream: staffRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading staff: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final staffDocs = snapshot.data!.docs
              .where((doc) =>
          (doc.data() as Map<String, dynamic>)["role"] == "staff")
              .toList();

          if (staffDocs.isEmpty) {
            return const Center(child: Text("No staff found."));
          }
          return ListView.builder(
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final staff = staffDocs[index].data() as Map<String, dynamic>;
              final docId = staffDocs[index].id;
              return Card(
                child: ListTile(
                  leading: staff["image"] != null &&
                      (staff["image"] as String).isNotEmpty
                      ? CircleAvatar(
                      backgroundImage: NetworkImage(staff["image"]))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(staff["name"] ?? ""),
                  subtitle: Text(
                    "Role: ${staff["role"] ?? "staff"}\nEmail: ${staff["email"] ?? ""}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            showStaffForm(staff: staff, docId: docId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await staffRef.doc(docId).delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showStaffForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
