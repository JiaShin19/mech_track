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

    // Validation error messages
    final Map<String, String?> fieldErrors = {
      'name': null,
      'email': null,
      'password': null,
      'phone': null,
      'address': null,
      'image': null,
      'form': null,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(staff == null ? "Add Staff" : "Edit Staff"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Name",
                    errorText: fieldErrors['name'],
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    errorText: fieldErrors['email'],
                  ),
                ),
                if (staff == null)
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: "Password (for login)",
                      errorText: fieldErrors['password'],
                    ),
                    obscureText: true,
                  ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone",
                    errorText: fieldErrors['phone'],
                  ),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: "Address",
                    errorText: fieldErrors['address'],
                  ),
                ),
                TextField(
                  controller: TextEditingController(text: "staff"),
                  decoration: const InputDecoration(labelText: "Role"),
                  enabled: false,
                ),
                TextField(
                  controller: imageController,
                  decoration: InputDecoration(
                    labelText: "Image URL (optional)",
                    errorText: fieldErrors['image'],
                  ),
                ),
                if (fieldErrors['form'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      fieldErrors['form']!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // Clear previous errors
                fieldErrors.updateAll((key, value) => null);

                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();
                final address = addressController.text.trim();
                final image = imageController.text.trim().isNotEmpty
                    ? imageController.text.trim()
                    : null;
                final password = passwordController.text.trim();

                bool hasError = false;

                // Validate each field
                if (name.isEmpty) {
                  fieldErrors['name'] = "Name is required.";
                  hasError = true;
                }
                if (email.isEmpty) {
                  fieldErrors['email'] = "Email is required.";
                  hasError = true;
                }
                if (staff == null && password.isEmpty) {
                  fieldErrors['password'] = "Password is required.";
                  hasError = true;
                }

                setDialogState(() {});

                if (hasError) return;

                if (staff == null) {
                  // Add staff
                  try {
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
                    setDialogState(() {
                      fieldErrors['form'] = "Error: ${e.toString()}";
                    });
                  }
                } else {
                  // Edit staff
                  try {
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Staff updated successfully!")),
                    );
                  } catch (e) {
                    setDialogState(() {
                      fieldErrors['form'] = "Error: ${e.toString()}";
                    });
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> confirmDeleteStaff() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Staff"),
        content: const Text(
            "Are you sure you want to delete this staff member? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
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
                          final confirm = await confirmDeleteStaff();
                          if (confirm == true) {
                            await staffRef.doc(docId).delete();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Staff deleted.')),
                              );
                            }
                          }
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