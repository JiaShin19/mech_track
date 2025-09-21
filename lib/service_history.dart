// service_history.dart
import 'package:flutter/material.dart';
import 'job_model.dart';
import 'data_service.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const ServiceHistoryScreen({super.key, this.vehicle});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  List<Job> _serviceHistory = [];
  bool _isLoading = true;
  String _currentMechanicName = "";

  @override
  void initState() {
    super.initState();
    _loadServiceHistory();
  }

  Future<void> _loadServiceHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure current mechanic is loaded first
      await DataService.getCurrentMechanic();
      _currentMechanicName = DataService.currentMechanicName;

      List<Job> history;
      if (widget.vehicle != null) {
        history = await DataService.getVehicleServiceHistory(widget.vehicle!.licensePlate);
      } else {
        history = await DataService.getCurrentMechanicJobs();
      }

      setState(() {
        _serviceHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _serviceHistory = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                  if (widget.vehicle != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (widget.vehicle != null) const SizedBox(width: 8),
                  const Icon(Icons.history, color: Colors.indigo, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Service History",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.vehicle != null
                              ? "${widget.vehicle!.model} (${widget.vehicle!.licensePlate})" // 车辆特定历史
                              : "My Work History - $_currentMechanicName", // 技师工作历史
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: _loadServiceHistory,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text(
                      "Loading service history...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : _serviceHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      widget.vehicle != null
                          ? "No service history found for this vehicle"
                          : "No work history found",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadServiceHistory,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadServiceHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _serviceHistory.length,
                  itemBuilder: (context, index) {
                    final job = _serviceHistory[index];
                    return _buildServiceCard(job);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Job job) {
    bool isCurrentMechanicWork = job.assignedTo == _currentMechanicName ||
        job.assignedTo == DataService.currentMechanicName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isCurrentMechanicWork ? Colors.indigo.withOpacity(0.3) : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  job.id.isNotEmpty ? job.id : "No Job ID",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[700],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(job.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(job.status).withOpacity(0.3)),
                ),
                child: Text(
                  job.status.isNotEmpty ? job.status : "Unknown",
                  style: TextStyle(
                    fontSize: 10,
                    color: _getStatusColor(job.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer Info
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.customer.name.isNotEmpty ? job.customer.name : "Unknown Customer",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Icon(
                Icons.build,
                size: 16,
                color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      "Mechanic: ",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      job.assignedTo.isNotEmpty ? job.assignedTo : "Unassigned",
                      style: TextStyle(
                        fontSize: 13,
                        color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[600],
                        fontWeight: isCurrentMechanicWork ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (isCurrentMechanicWork) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "YOU",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.vehicle == null) ...[
                Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  job.vehicle.licensePlate.isNotEmpty ? job.vehicle.licensePlate : "No Plate",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Services
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Services:",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                job.services.isEmpty
                    ? Text(
                  "No services listed",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                )
                    : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: job.services.map((service) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCurrentMechanicWork
                              ? Colors.indigo.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          service,
                          style: TextStyle(
                            fontSize: 9,
                            color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[700],
                          ),
                        ),
                      ),
                  ).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Job Description (if available)
          if (job.jobDescription.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Description:",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.jobDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Date and Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    job.createdDate.isNotEmpty ? job.createdDate : "No Date",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (job.totalTimeSpent != "-" && job.totalTimeSpent.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      job.totalTimeSpent,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Parts info (if available)
          if (job.parts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Parts Used:",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${job.parts.length} part(s) - RM ${job.totalPartsCost.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
}