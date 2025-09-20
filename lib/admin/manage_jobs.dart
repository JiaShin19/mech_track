import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageJobsPage extends StatefulWidget {
  const ManageJobsPage({super.key});

  @override
  State<ManageJobsPage> createState() => _ManageJobsPageState();
}

class _ManageJobsPageState extends State<ManageJobsPage> {
  final CollectionReference jobsRef = FirebaseFirestore.instance.collection('jobs');
  final CollectionReference staffRef = FirebaseFirestore.instance.collection('users');
  final CollectionReference customersRef = FirebaseFirestore.instance.collection('customers');

  // Helper for parts
  List<Map<String, dynamic>> partsToList(Map<String, dynamic>? partsMap) {
    if (partsMap == null) return [];
    return partsMap.values.map((p) => p as Map<String, dynamic>).toList();
  }

  // Helper for services
  List<String> servicesToList(dynamic servicesArr) {
    if (servicesArr == null) return [];
    if (servicesArr is List) return servicesArr.cast<String>();
    return [];
  }

  /// Show Add/Edit Job form
  void showJobForm({Map<String, dynamic>? job, String? docId}) async {
    // Fetch staff and customers for dropdowns
    final staffSnap = await staffRef.get();
    final customerSnap = await customersRef.get();

    List<Map<String, dynamic>> staffList = staffSnap.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    List<Map<String, dynamic>> customerList = customerSnap.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();

    // Initial form values
    String selectedStaffEmail = job?["assignedToEmail"] ?? "";
    String selectedCustomerEmail = job?["customer"]?["email"] ?? "";
    Map<String, dynamic>? selectedCustomer = customerList.firstWhere(
          (c) => c["email"] == selectedCustomerEmail,
      orElse: () => customerList.isNotEmpty ? customerList.first : {},
    );
    final jobIdController = TextEditingController(text: job?["id"] ?? "");
    final descController = TextEditingController(text: job?["jobDescription"] ?? "");
    final dateController = TextEditingController(text: job?["createdDate"] ?? "");
    String status = job?["status"] ?? "Assigned";
    List<String> services = servicesToList(job?["services"]);
    List<Map<String, dynamic>> parts = partsToList(job?["parts"]);

    // For adding new part
    String newPartName = "";
    String newPartUnit = "";
    String newPartQuantity = "";
    String newPartCost = "";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(job == null ? "Assign Job" : "Edit Job"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: jobIdController, decoration: const InputDecoration(labelText: "Job ID")),
                DropdownButtonFormField<String>(
                  value: selectedStaffEmail.isNotEmpty ? selectedStaffEmail : null,
                  items: staffList.map<DropdownMenuItem<String>>((s) {
                    return DropdownMenuItem<String>(
                      value: s["email"],
                      child: Text(s["name"] ?? s["email"]),
                    );
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedStaffEmail = value ?? ""),
                  decoration: const InputDecoration(labelText: "Assign Staff (by Email)"),
                ),
                DropdownButtonFormField<String>(
                  value: selectedCustomerEmail.isNotEmpty ? selectedCustomerEmail : null,
                  items: customerList.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem<String>(
                      value: c["email"],
                      child: Text(c["name"] ?? c["email"]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCustomerEmail = value ?? "";
                      selectedCustomer = customerList.firstWhere(
                            (c) => c["email"] == selectedCustomerEmail,
                        orElse: () => {},
                      );
                    });
                  },
                  decoration: const InputDecoration(labelText: "Assign Customer (by Email)"),
                ),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Job Description")),
                TextField(controller: dateController, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)")),
                DropdownButtonFormField<String>(
                  value: status,
                  items: ["Assigned", "In Progress", "Completed"].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (value) => setDialogState(() => status = value ?? "Assigned"),
                  decoration: const InputDecoration(labelText: "Status"),
                ),
                const SizedBox(height: 16),
                const Text("Services:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 6,
                  children: [
                    ...services.map((s) => Chip(
                      label: Text(s),
                      onDeleted: () {
                        setDialogState(() => services.remove(s));
                      },
                    )),
                    InputChip(
                      label: const Text("+ Add Service"),
                      onPressed: () async {
                        final serviceController = TextEditingController();
                        final result = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Add Service"),
                            content: TextField(
                              controller: serviceController,
                              decoration: const InputDecoration(labelText: "Service Name"),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, serviceController.text),
                                child: const Text("Add"),
                              ),
                            ],
                          ),
                        );
                        if (result != null && result.trim().isNotEmpty) {
                          setDialogState(() => services.add(result.trim()));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Parts:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...parts.asMap().entries.map((entry) {
                  int pIndex = entry.key;
                  var part = entry.value;
                  return ListTile(
                    title: Text(part["name"] ?? ""),
                    subtitle: Text("Unit: ${part["unit"] ?? ""} | Quantity: ${part["quantity"] ?? ""} | Cost: RM${part["cost"] ?? ""}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            // Edit part logic
                            final partNameCtrl = TextEditingController(text: part["name"] ?? "");
                            final partUnitCtrl = TextEditingController(text: part["unit"] ?? "");
                            final partQtyCtrl = TextEditingController(text: part["quantity"] ?? "");
                            final partCostCtrl = TextEditingController(text: part["cost"] ?? "");
                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Edit Part"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: partNameCtrl, decoration: const InputDecoration(labelText: "Name")),
                                    TextField(controller: partUnitCtrl, decoration: const InputDecoration(labelText: "Unit")),
                                    TextField(controller: partQtyCtrl, decoration: const InputDecoration(labelText: "Quantity")),
                                    TextField(controller: partCostCtrl, decoration: const InputDecoration(labelText: "Cost")),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx, {
                                        "name": partNameCtrl.text.trim(),
                                        "unit": partUnitCtrl.text.trim(),
                                        "quantity": partQtyCtrl.text.trim(),
                                        "cost": partCostCtrl.text.trim(),
                                      });
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              ),
                            );
                            if (result != null) {
                              setDialogState(() => parts[pIndex] = result);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setDialogState(() => parts.removeAt(pIndex)),
                        ),
                      ],
                    ),
                  );
                }),
                // Add part form inline
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Part Name"),
                        onChanged: (v) => newPartName = v,
                      )),
                      Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Unit"),
                        onChanged: (v) => newPartUnit = v,
                      )),
                      Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Quantity"),
                        onChanged: (v) => newPartQuantity = v,
                      )),
                      Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Cost"),
                        onChanged: (v) => newPartCost = v,
                      )),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (newPartName.trim().isEmpty) return;
                          setDialogState(() {
                            parts.add({
                              "name": newPartName.trim(),
                              "unit": newPartUnit.trim(),
                              "quantity": newPartQuantity.trim(),
                              "cost": newPartCost.trim(),
                            });
                            newPartName = "";
                            newPartUnit = "";
                            newPartQuantity = "";
                            newPartCost = "";
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // Build parts as map for Firestore
                Map<String, dynamic> partsMap = {
                  for (var part in parts)
                    part["name"] ?? "Unnamed": part
                };
                // Build job doc
                final newJob = {
                  "id": jobIdController.text.trim(),
                  "assignedToEmail": selectedStaffEmail,
                  "createdDate": dateController.text.trim(),
                  "jobDescription": descController.text.trim(),
                  "status": status,
                  "services": services,
                  "parts": partsMap,
                  // Customer info as map (from customers collection)
                  "customer": selectedCustomer ?? {},
                  "customerName": selectedCustomer?["name"] ?? "",
                  // You can add "vehicle" similarly, if needed
                };
                if (job == null) {
                  await jobsRef.add(newJob);
                } else {
                  await jobsRef.doc(docId!).update(newJob);
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Jobs")),
      body: StreamBuilder<QuerySnapshot>(
        stream: jobsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final jobDocs = snapshot.data!.docs;
          if (jobDocs.isEmpty) {
            return const Center(child: Text("No jobs found."));
          }
          return ListView.builder(
            itemCount: jobDocs.length,
            itemBuilder: (context, index) {
              final job = jobDocs[index].data() as Map<String, dynamic>;
              final docId = jobDocs[index].id;
              // Convert parts to list for display
              final partsList = partsToList(job["parts"]);
              final servicesList = servicesToList(job["services"]);
              final customer = job["customer"] ?? {};

              return Card(
                child: ListTile(
                  title: Text("${job["id"] ?? ""} • ${job["customerName"] ?? ""}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Staff: ${job["assignedToEmail"] ?? ""}"),
                      Text("Status: ${job["status"] ?? ""}"),
                      Text("Date: ${job["createdDate"] ?? ""}"),
                      Text("Description: ${job["jobDescription"] ?? ""}"),
                      Text("Services: ${servicesList.join(', ')}"),
                      Text("Parts:"),
                      ...partsList.map((p) => Text("- ${p["name"] ?? ""} (${p["quantity"]} ${p["unit"]}) RM${p["cost"]}")),
                      Text("Customer: ${customer["name"] ?? ""} (${customer["email"] ?? ""})"),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showJobForm(job: job, docId: docId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await jobsRef.doc(docId).delete();
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
        onPressed: () => showJobForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}