// job_detail.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_model.dart';
import 'customer_detail.dart';
import 'vehicle_detail.dart';
import 'parts_detail.dart';
import 'time_tracking.dart';
import 'digital_signoff.dart';

import '../services/notes_service.dart';
import '../services/note_model.dart';
import '../ui/image_utils.dart';
import 'note_view_page.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job get job => widget.job;
  final _notesSvc = NotesService();

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy HH:mm').format(d);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'signed-off':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // ---------- Reusable tiles ----------
  Widget _clickableInfoCard(
      String title,
      IconData icon,
      Widget content,
      VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: content,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _nonClickableInfoCard(
      String title,
      IconData icon,
      Widget content,
      ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: content,
      ),
    );
  }

  // ---------- NEW: Notes section (shows ONLY when there are notes) ----------
  Widget _notesSection() {
    final stream =
      _notesSvc.streamNotesFiltered(newestFirst: true, jobId: job.id);

    return StreamBuilder<List<NoteModel>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final notes = snap.data!;
        if (notes.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.sticky_note_2, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Notes',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final n = notes[i];
                    final first = n.imagesB64.isNotEmpty ? n.imagesB64.first : null;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoteViewPage(noteId: n.id),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: first == null
                                ? SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: placeholderThumb(),
                                  )
                                : smartThumb(
                                    first,
                                    w: 56,
                                    h: 56,
                                    fit: BoxFit.cover,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 70,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title.isEmpty ? "(Untitled)" : n.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.text.isEmpty ? '(No text)' : n.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(height: 1.25),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        _fmt(n.createdAt),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
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
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If you keep jobs in a local data store and want freshest status:
    final current = job;
    final mechanicId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("jobs")
              .doc(job.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final current = Job.fromMap(data, snapshot.data!.id);

            return Column(
              children: [
                // ---------- Header ----------
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(current.id,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (current.status == 'Assigned')
                            const Icon(Icons.assignment,
                                color: Colors.grey, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(current.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          current.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Assigned to:",
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12)),
                                Text(current.assignedTo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Created:",
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12)),
                                Text(current.createdDate,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Total Time Spent:",
                          style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(current.totalTimeSpent,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                    ],
                  ),
                ),

                // ---------- Body ----------
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _clickableInfoCard(
                        "Customer",
                        Icons.person,
                        Text(current.customer.name),
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDetailScreen(customer: current.customer)),
                          );
                        },
                      ),
                      _clickableInfoCard(
                        "Vehicle",
                        Icons.directions_car,
                        Text("${current.vehicle.model} (${current.vehicle.year})"),
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    VehicleDetailScreen(vehicle: current.vehicle)),
                          );
                        },
                      ),
                      _clickableInfoCard(
                        "Parts",
                        Icons.inventory,
                        Text("${current.partsCount} items assigned"),
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    PartsDetailScreen(parts: current.parts)),
                          );
                        },
                      ),
                      _nonClickableInfoCard(
                        "Job Description",
                        Icons.description,
                        Text(
                          current.jobDescription,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _nonClickableInfoCard(
                        "Services",
                        Icons.build,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: current.services
                              .map((s) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text("• $s"),
                          ))
                              .toList(),
                        ),
                      ),
                      TimeTrackingPanel(
                        jobId: current.id,
                        mechanicId: mechanicId,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        showStatus: true,
                      ),
                      if (job.status == "Completed")
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("jobs")
                              .doc(job.id)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const SizedBox.shrink();
                            final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                            final sig = data["signatureB64"] as String?;

                            if (sig != null && sig.isNotEmpty) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.edit_document, color: Colors.indigo),
                                          SizedBox(width: 8),
                                          Text(
                                            "Digital Sign-Off",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Center(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            base64Decode(sig.split(",").last),
                                            height: 120,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.verified, color: Colors.green),
                                            SizedBox(width: 6),
                                            Text(
                                              "Signed Off",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text("Sign Off"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  onPressed: () async {
                                    final ok = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DigitalSignoffScreen(
                                          jobId: job.id,
                                          mechanicId: mechanicId,
                                        ),
                                      ),
                                    );
                                    if (ok == true) setState(() {});
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      _notesSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}