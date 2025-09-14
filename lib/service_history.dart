// service_history.dart
import 'package:flutter/material.dart';
import 'job_model.dart';
import 'data_service.dart';

class ServiceHistoryScreen extends StatelessWidget {
  final Vehicle? vehicle;

  const ServiceHistoryScreen({super.key, this.vehicle});

  List<Job> get _serviceHistory {
    if (vehicle != null) {
      // 从Vehicle详情进入：返回该车辆的所有服务历史（所有技师的工作）
      return DataService.getVehicleServiceHistory(vehicle!.licensePlate);
    } else {
      // 从底部导航进入：返回当前技师的所有工作历史
      return DataService.getCurrentMechanicJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceHistory = _serviceHistory;

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
                  if (vehicle != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (vehicle != null) const SizedBox(width: 8),
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
                          vehicle != null
                              ? "${vehicle!.model} (${vehicle!.licensePlate})" // 车辆特定历史
                              : "My Work History - ${DataService.currentMechanic}", // 技师工作历史
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Service History List
            Expanded(
              child: serviceHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      vehicle != null
                          ? "No service history found for this vehicle"
                          : "No work history found",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: serviceHistory.length,
                itemBuilder: (context, index) {
                  final job = serviceHistory[index];
                  return _buildServiceCard(job);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Job job) {
    // 检查是否是当前技师的工作
    bool isCurrentMechanicWork = job.assignedTo == DataService.currentMechanic;

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
                  job.id,
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
                  job.status,
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
                  job.customer.name,
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

          // Mechanic Info（对于车辆历史很重要，显示是谁做的服务）
          Row(
            children: [
              Icon(
                Icons.build,
                size: 16,
                color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Mechanic: ${job.assignedTo}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isCurrentMechanicWork ? Colors.indigo : Colors.grey[600],
                    fontWeight: isCurrentMechanicWork ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              // 如果是从技师历史查看，显示车牌号
              if (vehicle == null) ...[
                Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  job.vehicle.licensePlate,
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
                Wrap(
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

          // Date and Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    job.createdDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (job.totalTimeSpent != "-")
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