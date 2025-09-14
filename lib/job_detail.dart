// job_detail.dart
import 'package:flutter/material.dart';
import 'job_model.dart';
import 'customer_detail.dart';
import 'vehicle_detail.dart';
import 'parts_detail.dart';

class JobDetailScreen extends StatelessWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildClickableInfoCard(String title, IconData icon, Widget content, VoidCallback onTap) {
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

  Widget _buildNonClickableInfoCard(String title, IconData icon, Widget content) {
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

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Card
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
                      Text(
                        job.id,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Status indicator with icon
                      if (job.status == 'Assigned')
                        const Icon(Icons.assignment, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(job.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      job.status,
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
                            Text(
                              "Assigned to:",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              job.assignedTo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Created:",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              job.createdDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Total Time Spent:",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    job.totalTimeSpent,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Clickable Customer Card
                  _buildClickableInfoCard(
                    "Customer",
                    Icons.person,
                    Text(job.customer.name),
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDetailScreen(customer: job.customer),
                        ),
                      );
                    },
                  ),
                  // Clickable Vehicle Card
                  _buildClickableInfoCard(
                    "Vehicle",
                    Icons.directions_car,
                    Text(job.vehicleModel),
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleDetailScreen(vehicle: job.vehicle),
                        ),
                      );
                    },
                  ),
                  // Clickable Parts Card
                  _buildClickableInfoCard(
                    "Parts",
                    Icons.inventory,
                    Text("${job.partsCount} items assigned"),
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PartsDetailScreen(parts: job.parts),
                        ),
                      );
                    },
                  ),
                  // Non-clickable Job Description Card
                  _buildNonClickableInfoCard(
                    "Job Description",
                    Icons.description,
                    Text(
                      job.jobDescription,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Non-clickable Services Card
                  _buildNonClickableInfoCard(
                    "Services",
                    Icons.build,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: job.services
                          .map((service) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text("• $service"),
                      ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons based on status
                  if (job.status == "Assigned") ...[
                    _buildActionButton(
                      "Time Track",
                      Icons.access_time,
                          () {
                        // Navigate to Time Track screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Time Track clicked")),
                        );
                      },
                    ),
                    _buildActionButton(
                      "Note...",
                      Icons.note,
                          () {
                        // Navigate to Notes screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Note clicked")),
                        );
                      },
                    ),
                  ] else if (job.status == "In Progress") ...[
                    _buildActionButton(
                      "Time Track",
                      Icons.access_time,
                          () {
                        // Navigate to Time Track screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Time Track clicked")),
                        );
                      },
                    ),
                  ] else if (job.status == "Completed") ...[
                    _buildActionButton(
                      "Sign-Off",
                      Icons.check_circle_outline,
                          () {
                        // Navigate to Sign-Off screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sign-Off clicked")),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: "Summary"),
        ],
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}