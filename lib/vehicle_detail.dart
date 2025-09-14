// vehicle_detail.dart
import 'package:flutter/material.dart';
import 'job_model.dart';
import 'service_history.dart';

class VehicleDetailScreen extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.directions_car, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text(
                    "Vehicle Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Vehicle Info
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Vehicle Image
                    Container(
                      width: double.infinity,
                      height: 160,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: vehicle.imageUrl != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          vehicle.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        ),
                      )
                          : _buildPlaceholderImage(),
                    ),
                    // Vehicle Details
                    _buildDetailField("Model", vehicle.model),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailField("Year", vehicle.year),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDetailField("Color", vehicle.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailField("License Plate", vehicle.licensePlate),
                    const SizedBox(height: 8),
                    _buildDetailField("Current Mileage", vehicle.currentMileage),
                    const SizedBox(height: 16),
                    // Service History Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceHistoryScreen(vehicle: vehicle),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text("View Service History"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.directions_car,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}