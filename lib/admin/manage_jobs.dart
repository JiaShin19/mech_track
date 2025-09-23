import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class ManageJobsPage extends StatefulWidget {
  const ManageJobsPage({super.key});

  @override
  State<ManageJobsPage> createState() => _ManageJobsPageState();
}

class _ManageJobsPageState extends State<ManageJobsPage> {
  final CollectionReference jobsRef = FirebaseFirestore.instance.collection('jobs');
  final CollectionReference staffRef = FirebaseFirestore.instance.collection('users');
  final CollectionReference customersRef = FirebaseFirestore.instance.collection('Customers');

  List<Map<String, dynamic>> partsToList(Map<String, dynamic>? partsMap) {
    if (partsMap == null) return [];
    return partsMap.values.map((p) => p as Map<String, dynamic>).toList();
  }

  List<String> servicesToList(dynamic servicesArr) {
    if (servicesArr == null) return [];
    if (servicesArr is List) return servicesArr.cast<String>();
    return [];
  }

  Future<bool?> confirmDeleteJob() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Job"),
        content: const Text("Are you sure you want to delete this job? This action cannot be undone."),
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

  void showJobForm({Map<String, dynamic>? job, String? docId}) async {
    final staffSnap = await staffRef.get();
    final customerSnap = await customersRef.get();

    List<Map<String, dynamic>> staffList = staffSnap.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    List<Map<String, dynamic>> customerList = customerSnap.docs.map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    List<Map<String, dynamic>> vehicleList = [];
    Map<String, dynamic>? selectedVehicle = job?["vehicle"];

    String selectedStaffEmail = job?["assignedToEmail"] ?? "";
    String selectedCustomerEmail = job?["customer"]?["email"] ?? "";
    String? selectedVehicleId = selectedVehicle?["id"];

    Map<String, dynamic>? selectedCustomer =
    customerList.firstWhere(
          (c) => c["email"] == selectedCustomerEmail,
      orElse: () => {},
    );

    if (selectedCustomer.isEmpty) {
      selectedCustomer = null; // explicitly null if not found
    }
    final jobIdController = TextEditingController(text: job?["id"] ?? "");
    final descController = TextEditingController(text: job?["jobDescription"] ?? "");
    final dateController = TextEditingController(text: job?["createdDate"] ?? "");
    String status = job?["status"] ?? "Assigned";
    List<String> services = servicesToList(job?["services"]);
    List<Map<String, dynamic>> parts = partsToList(job?["parts"]);

    // helper function to load vehicles dynamically
    Future<void> loadVehicles(String customerId) async {
      final vehicleSnap =
      await customersRef.doc(customerId).collection("vehicle").get();
      vehicleList = vehicleSnap.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    }

    // if editing an existing job, preload vehicles
    if (selectedCustomer != null && selectedCustomer!.isNotEmpty) {
      await loadVehicles(selectedCustomer!["id"]);
      selectedVehicleId = selectedVehicle?["id"]; // preload from saved vehicle if editing
    }

    // For adding new part
    String newPartName = "";
    String newPartUnit = "";
    String newPartQuantity = "";
    String newPartCost = "";

    // For error messages
    Map<String, String?> fieldErrors = {
      'jobId': null,
      'staff': null,
      'customer': null,
      'desc': null,
      'date': null,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(job == null ? "Assign Job" : "Edit Job"),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("General Info", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  TextField(
                    controller: jobIdController,
                    decoration: InputDecoration(
                      labelText: "Job ID",
                      errorText: fieldErrors['jobId'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStaffEmail.isNotEmpty ? selectedStaffEmail : null,
                    items: staffList.map<DropdownMenuItem<String>>((s) {
                      return DropdownMenuItem<String>(
                        value: s["email"],
                        child: Text(s["name"] ?? s["email"]),
                      );
                    }).toList(),
                    onChanged: (value) => setDialogState(() => selectedStaffEmail = value ?? ""),
                    decoration: InputDecoration(
                      labelText: "Assign Staff (by Email)",
                      errorText: fieldErrors['staff'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCustomerEmail.isNotEmpty
                        ? selectedCustomerEmail
                        : null,
                    items: customerList.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c["email"],
                        child: Text(c["name"] ?? c["email"]),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setDialogState(() {
                        selectedCustomerEmail = value ?? "";
                        selectedCustomer = customerList.firstWhere(
                              (c) => c["email"] == selectedCustomerEmail,
                          orElse: () => {},
                        );
                        selectedVehicleId = null; // reset vehicle
                      });

                      // reload vehicles for the new customer
                      if (selectedCustomer != null &&
                          selectedCustomer!.isNotEmpty) {
                        await loadVehicles(selectedCustomer!["id"]);
                        setDialogState(() {});
                      }
                    },
                    decoration: const InputDecoration(labelText: "Assign Customer"),
                  ),
                  const SizedBox(height: 8),

                  // Vehicle dropdown – updates when customer changes
                  DropdownButtonFormField<String>(
                    value: vehicleList.any((v) => v["id"] == selectedVehicleId)
                        ? selectedVehicleId
                        : null,
                    items: vehicleList.map<DropdownMenuItem<String>>((v) {
                      return DropdownMenuItem<String>(
                        value: v["id"],
                        child: Text("${v["licensePlate"]} - ${v["model"]} (${v["year"]})"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedVehicleId = value;
                        selectedVehicle = vehicleList.firstWhere(
                              (v) => v["id"] == value,
                          orElse: () => {},
                        );
                      });
                    },
                    decoration: const InputDecoration(labelText: "Assign Vehicle"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: "Job Description",
                      errorText: fieldErrors['desc'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: "Date (YYYY-MM-DD)",
                      errorText: fieldErrors['date'],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2022),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: ["Assigned", "In Progress", "Completed"].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (value) => setDialogState(() => status = value ?? "Assigned"),
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                  const SizedBox(height: 16),
                  const Text("Services", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Wrap(
                    spacing: 6,
                    children: [
                      ...services.map((s) => Chip(
                        label: Text(s),
                        onDeleted: () {
                          setDialogState(() => services.remove(s));
                        },
                        backgroundColor: Colors.blue.shade100,
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
                        backgroundColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Parts", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...parts.asMap().entries.map((entry) {
                    int pIndex = entry.key;
                    var part = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 1,
                      child: ListTile(
                        title: Text(part["name"] ?? ""),
                        subtitle: Text("Unit: ${part["unit"] ?? ""} | Quantity: ${part["quantity"] ?? ""} | Cost: RM${part["cost"] ?? ""}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () async {
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
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setDialogState(() => parts.removeAt(pIndex)),
                            ),
                          ],
                        ),
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
                          icon: const Icon(Icons.add, color: Colors.green),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final enteredId = jobIdController.text.trim();

                // Validation
                bool hasError = false;
                fieldErrors.updateAll((key, value) => null);
                if (jobIdController.text.trim().isEmpty) {
                  fieldErrors['jobId'] = "Required";
                  hasError = true;
                }
                if (selectedStaffEmail.isEmpty) {
                  fieldErrors['staff'] = "Required";
                  hasError = true;
                }
                if (selectedCustomerEmail.isEmpty) {
                  fieldErrors['customer'] = "Required";
                  hasError = true;
                }
                if (descController.text.trim().isEmpty) {
                  fieldErrors['desc'] = "Required";
                  hasError = true;
                }
                if (dateController.text.trim().isEmpty) {
                  fieldErrors['date'] = "Required";
                  hasError = true;
                }
                setDialogState(() {});

                if (hasError) return;

                if (selectedCustomer == null || selectedCustomer!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a customer")),
                  );
                  return;
                }
                if (selectedVehicle == null || selectedVehicle!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a vehicle")),
                  );
                  return;
                }

                // Build job object
                Map<String, dynamic> partsMap = {
                  for (var part in parts) part["name"] ?? "Unnamed": part
                };
                final newJob = {
                  "id": enteredId,
                  "assignedToEmail": selectedStaffEmail,
                  "createdDate": dateController.text.trim(),
                  "jobDescription": descController.text.trim(),
                  "status": status,
                  "services": services,
                  "parts": partsMap,
                  "customer": selectedCustomer ?? {},
                  "customerName": selectedCustomer?["name"] ?? "",
                  "vehicle": selectedVehicle ?? {},
                  "running": false,
                  "startedAt": null,
                  "aggregatedDurationSeconds": 0,
                  "totalTimeSpent": null,
                  "totalTimeSpentDisplay": null,
                };

                final box = await Hive.openBox('jobsCache');

                if (job == null) {
                  await box.put(enteredId, {"action": "add", "data": newJob});
                } else {
                  await box.put(docId, {"action": "update", "data": newJob});
                }

                if (mounted) Navigator.pop(context);

                // Show feedback immediately
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(job == null
                            ? "Job assigned successfully! (will sync online if possible)."
                            : "Job updated successfully! (will sync online if possible)"),
                      ),
                    );
                  }
                });

                try {
                  if (job == null) {
                    await jobsRef.doc(enteredId).set(newJob);
                    await box.delete(enteredId);
                  } else {
                    await jobsRef.doc(docId!).update(newJob);
                    await box.delete(docId);
                  }
                } catch (_) {
                }
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
              final partsList = partsToList(job["parts"]);
              final servicesList = servicesToList(job["services"]);
              final customer = job["customer"] ?? {};
              final vehicle = job["vehicle"] ?? {};

              // Summary info for the tile header
              final summaryTitle = "${job["id"] ?? ""} • ${job["customerName"] ?? ""}";
              final summarySubtitle = "Status: ${job["status"] ?? ""} | Date: ${job["createdDate"] ?? ""}";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    child: Text((job["customerName"] ?? "C").toString()[0].toUpperCase()),
                    backgroundColor: Colors.blue.shade100,
                  ),
                  title: Text(
                    summaryTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(summarySubtitle),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Chip(
                              label: Text(job["status"] ?? "Assigned"),
                              backgroundColor: job["status"] == "Completed"
                                  ? Colors.green.shade100
                                  : job["status"] == "In Progress"
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Text("Staff: ${job["assignedToEmail"] ?? ""}"),
                          Text("Description: ${job["jobDescription"] ?? ""}"),
                          Text("Services: ${servicesList.join(', ')}"),
                          if (partsList.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            const Text("Parts:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...partsList.map((p) => Text("- ${p["name"] ?? ""} (${p["quantity"]} ${p["unit"]}) RM${p["cost"]}")),
                          ],
                          const SizedBox(height: 5),
                          Text("Customer: ${customer["name"] ?? ""} (${customer["email"] ?? ""})"),
                          const SizedBox(height: 5),
                          Text("Vehicle: ${vehicle["licensePlate"]} - ${vehicle["model"]} (${vehicle["year"]})"),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => showJobForm(job: job, docId: docId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await confirmDeleteJob();
                                  if (confirm == true) {
                                    await jobsRef.doc(docId).delete();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Job deleted.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showJobForm(),
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}