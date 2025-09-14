class Customer {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String? avatarUrl;

  Customer({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.avatarUrl,
  });
}

class Vehicle {
  final String model;
  final String year;
  final String color;
  final String licensePlate;
  final String currentMileage;
  final String? imageUrl;

  Vehicle({
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    required this.currentMileage,
    this.imageUrl,
  });
}

class Part {
  final String name;
  final int quantity;
  final double cost;
  final String unit;

  Part({
    required this.name,
    required this.quantity,
    required this.cost,
    this.unit = "pcs",
  });
}

class Job {
  final String id;
  final Customer customer;
  final String status;
  final String assignedTo;
  final String createdDate;
  final String totalTimeSpent;
  final Vehicle vehicle;
  final String jobDescription;
  final List<String> services;
  final List<Part> parts;

  late final DateTime date;

  Job({
    required this.id,
    required this.customer,
    required this.status,
    required this.assignedTo,
    required this.createdDate,
    required this.totalTimeSpent,
    required this.vehicle,
    required this.jobDescription,
    required this.services,
    required this.parts,
  }) {
    date = DateTime.tryParse(createdDate) ?? DateTime.now();
  }

  String get customerName => customer.name;
  String get vehicleModel => "${vehicle.model}(${vehicle.year})";
  int get partsCount => parts.length;
  double get totalPartsCost =>
      parts.fold(0.0, (sum, part) => sum + (part.cost * part.quantity));
}
