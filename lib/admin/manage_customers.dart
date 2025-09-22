import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class ManageCustomersPage extends StatefulWidget {
  const ManageCustomersPage({super.key});

  @override
  State<ManageCustomersPage> createState() => _ManageCustomersPageState();
}

class _ManageCustomersPageState extends State<ManageCustomersPage> {
  final CollectionReference customersRef =
  FirebaseFirestore.instance.collection('Customers');

  Future<void> _cacheCustomer(
      {required String action, String? docId, required Map<String, dynamic> data}) async {
    final box = await Hive.openBox('customersCache');
    final key = docId ?? DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, {"action": action, "data": data});
  }

  Future<void> _cacheVehicle({
    required String customerId,
    required String action,
    String? docId,
    required Map<String, dynamic> data,
  }) async {
    final box = await Hive.openBox('vehiclesCache');
    final key = docId ?? "${customerId}_${DateTime
        .now()
        .millisecondsSinceEpoch}";
    await box.put(key, {
      "customerId": customerId,
      "action": action,
      "data": data,
    });
  }

    void showCustomerForm({Map<String, dynamic>? customer, String? docId}) {
    final nameController = TextEditingController(text: customer?["name"] ?? "");
    final emailController = TextEditingController(text: customer?["email"] ?? "");
    final phoneController = TextEditingController(text: customer?["phone"] ?? "");
    final addressController = TextEditingController(text: customer?["address"] ?? "");
    final avatarController = TextEditingController(text: customer?["avatarUrl"] ?? "");

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(customer == null ? "Add Customer" : "Edit Customer"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: "Address")),
              TextField(controller: avatarController, decoration: const InputDecoration(labelText: "Avatar URL")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newCustomer = {
                "name": nameController.text.trim(),
                "email": emailController.text.trim(),
                "phone": phoneController.text.trim(),
                "address": addressController.text.trim(),
                "avatarUrl": avatarController.text.isNotEmpty
                    ? avatarController.text.trim()
                    : "assets/images/default_avatar.png",
              };

              await _cacheCustomer(
                action: customer == null ? "add" : "update",
                docId: docId,
                data: newCustomer,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Customer saved offline, will sync later.")),
                );
              }

              try {
                if (customer == null) {
                  await customersRef.add(newCustomer);
                } else {
                  await customersRef.doc(docId!).update(newCustomer);
                }
              } catch (_) {}
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void showVehicleForm({
    required String customerId,
    Map<String, dynamic>? vehicle,
    String? docId,
  }) {
    final modelController = TextEditingController(text: vehicle?["model"] ?? "");
    final licensePlateController = TextEditingController(text: vehicle?["licensePlate"] ?? "");
    final yearController = TextEditingController(text: vehicle?["year"]?.toString() ?? "");
    final colorController = TextEditingController(text: vehicle?["color"] ?? "");
    final mileageController = TextEditingController(text: vehicle?["currentMileage"] ?? "");
    final imageController = TextEditingController(text: vehicle?["imageUrl"] ?? "");

    final vehiclesRef = customersRef.doc(customerId).collection('vehicle');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(vehicle == null ? "Add Vehicle" : "Edit Vehicle"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: modelController, decoration: const InputDecoration(labelText: "Model")),
              TextField(controller: licensePlateController, decoration: const InputDecoration(labelText: "License Plate")),
              TextField(controller: yearController, decoration: const InputDecoration(labelText: "Year"), keyboardType: TextInputType.number),
              TextField(controller: colorController, decoration: const InputDecoration(labelText: "Color")),
              TextField(controller: mileageController, decoration: const InputDecoration(labelText: "Current Mileage")),
              TextField(controller: imageController, decoration: const InputDecoration(labelText: "Image URL")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newVehicle = {
                "model": modelController.text.trim(),
                "licensePlate": licensePlateController.text.trim(),
                "year": int.tryParse(yearController.text.trim()) ?? 0,
                "color": colorController.text.trim(),
                "currentMileage": mileageController.text.trim(),
                "imageUrl": imageController.text.trim(),
              };

              await _cacheVehicle(
                customerId: customerId,
                action: vehicle == null ? "add" : "update",
                docId: docId,
                data: newVehicle,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Vehicle saved offline, will sync later.")),
                );
              }

              try {
                if (vehicle == null) {
                  await vehiclesRef.add(newVehicle);
                } else {
                  await vehiclesRef.doc(docId!).update(newVehicle);
                }
              } catch (_) {}
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<bool?> confirmDelete(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
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
      appBar: AppBar(title: const Text("Manage Customers & Vehicles")),
      body: StreamBuilder<QuerySnapshot>(
        stream: customersRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final customerDocs = snapshot.data!.docs;
          if (customerDocs.isEmpty) {
            return const Center(child: Text("No customers found."));
          }
          return ListView.builder(
            itemCount: customerDocs.length,
            itemBuilder: (context, index) {
              final customer = customerDocs[index].data() as Map<String, dynamic>;
              final customerId = customerDocs[index].id;
              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: AssetImage(
                            customer["avatarUrl"] ?? "assets/images/default_avatar.png",
                          ),
                        ),
                        title: Text(customer["name"] ?? ""),
                        subtitle: Text(customer["email"] ?? ""),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => showCustomerForm(customer: customer, docId: customerId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await confirmDelete(
                                  "Delete Customer",
                                  "Are you sure you want to delete this customer? All their vehicles will also be deleted. This action cannot be undone.",
                                );
                                if (confirm == true) {
                                  try {
                                    await customersRef.doc(customerId).delete();
                                  } catch (_) {
                                    await _cacheCustomer(action: "delete", docId: customerId, data: {});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Customer deleted.')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text("Vehicles:", style: TextStyle(fontWeight: FontWeight.bold)),
                      StreamBuilder<QuerySnapshot>(
                        stream: customersRef.doc(customerId).collection('vehicle').snapshots(),
                        builder: (context, vehicleSnapshot) {
                          if (!vehicleSnapshot.hasData) return const Text("Loading vehicles...");
                          final vehicleDocs = vehicleSnapshot.data!.docs;
                          if (vehicleDocs.isEmpty) {
                            return const Text("No vehicles found.");
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vehicleDocs.length,
                            itemBuilder: (context, vIndex) {
                              final vehicle = vehicleDocs[vIndex].data() as Map<String, dynamic>;
                              final vehicleId = vehicleDocs[vIndex].id;
                              return Card(
                                color: Colors.grey[100],
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: ListTile(
                                  leading: (vehicle["imageUrl"] != null && vehicle["imageUrl"].isNotEmpty)
                                      ? CircleAvatar(backgroundImage: AssetImage(vehicle["imageUrl"]))
                                      : const CircleAvatar(child: Icon(Icons.directions_car)),
                                  title: Text(vehicle["model"] ?? ""),
                                  subtitle: Text(
                                    "Plate: ${vehicle["licensePlate"] ?? ""}\n"
                                        "Year: ${vehicle["year"] ?? ""}\n"
                                        "Color: ${vehicle["color"] ?? ""}\n"
                                        "Mileage: ${vehicle["currentMileage"] ?? ""}",
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => showVehicleForm(
                                          customerId: customerId,
                                          vehicle: vehicle,
                                          docId: vehicleId,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () async {
                                          final confirm = await confirmDelete(
                                            "Delete Vehicle",
                                            "Are you sure you want to delete this vehicle? This action cannot be undone.",
                                          );
                                          if (confirm == true) {
                                            try {
                                              await customersRef.doc(customerId).collection('vehicle').doc(vehicleId).delete();
                                            } catch (_) {
                                              await _cacheVehicle(
                                                customerId: customerId,
                                                action: "delete",
                                                docId: vehicleId,
                                                data: {},
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Vehicle deleted.')),
                                                );
                                              }
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Add Vehicle"),
                          onPressed: () => showVehicleForm(customerId: customerId),
                        ),
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
        onPressed: () => showCustomerForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
