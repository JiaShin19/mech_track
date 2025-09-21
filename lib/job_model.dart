import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      name: map['name'] ?? map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      avatarUrl: map['avatarUrl'] ?? map['image'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'avatarUrl': avatarUrl,
    };
  }
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

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      model: map['model'] ?? '',
      year: map['year'] ?? '',
      color: map['color'] ?? '',
      licensePlate: map['licensePlate'] ?? '',
      currentMileage: map['currentMileage'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'currentMileage': currentMileage,
      'imageUrl': imageUrl,
    };
  }
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

  factory Part.fromMap(Map<String, dynamic> map) {
    return Part(
      name: map['name'] ?? '',
      quantity: int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      cost: double.tryParse(map['cost']?.toString() ?? '0.0') ?? 0.0,
      unit: map['unit'] ?? "pcs",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'cost': cost,
      'unit': unit,
    };
  }
}

class Job {
  final String id;
  final Customer customer;
  final String status;
  final String assignedTo;
  final String createdDate;
  final String totalTimeSpent;
  final String totalTimeSpentDisplay;
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
    required this.totalTimeSpentDisplay,
    required this.vehicle,
    required this.jobDescription,
    required this.services,
    required this.parts,
  }) {
    date = DateTime.tryParse(createdDate) ?? DateTime.now();
  }

  factory Job.fromMap(Map<String, dynamic> map, String id) {
    final customerMap = (map['customer'] ?? {}) as Map<String, dynamic>;
    final vehicleMap = (map['vehicle'] ?? {}) as Map<String, dynamic>;
    final partsMap = (map['parts'] ?? {}) as Map<String, dynamic>;

    return Job(
      id: map['id'] ?? '',
      customer: Customer.fromMap(customerMap),
      status: map['status'] ?? '',
      assignedTo: map['assignedTo'] ?? map['assignedToEmail'] ?? '',
      createdDate: map['createdDate'] ?? '',
      totalTimeSpent: map['totalTimeSpent'] ?? '',
      totalTimeSpentDisplay: map['totalTimeSpentDisplay'] ?? '',
      vehicle: Vehicle.fromMap(vehicleMap),
      jobDescription: map['jobDescription'] ?? '',
      services: List<String>.from(map['services'] ?? []),
      parts: partsMap.entries.map((entry) {
        final partData = entry.value as Map<String, dynamic>;
        return Part.fromMap(partData);
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer': customer.toMap(),
      'status': status,
      'assignedTo': assignedTo,
      'createdDate': createdDate,
      'totalTimeSpent': totalTimeSpent,
      'vehicle': vehicle.toMap(),
      'jobDescription': jobDescription,
      'services': services,
      'parts': {for (var p in parts) p.name: p.toMap()},
    };
  }

  String get customerName => customer.name;
  String get vehicleModel => "${vehicle.model}(${vehicle.year})";
  int get partsCount => parts.length;
  double get totalPartsCost =>
      parts.fold(0.0, (sum, part) => sum + (part.cost * part.quantity));
}

// class Customer {
//   final String name;
//   final String phone;
//   final String email;
//   final String address;
//   final String? avatarUrl;
//
//   Customer({
//     required this.name,
//     required this.phone,
//     required this.email,
//     required this.address,
//     this.avatarUrl,
//   });
// }
//
// class Vehicle {
//   final String model;
//   final String year;
//   final String color;
//   final String licensePlate;
//   final String currentMileage;
//   final String? imageUrl;
//
//   Vehicle({
//     required this.model,
//     required this.year,
//     required this.color,
//     required this.licensePlate,
//     required this.currentMileage,
//     this.imageUrl,
//   });
// }
//
// class Part {
//   final String name;
//   final int quantity;
//   final double cost;
//   final String unit;
//
//   Part({
//     required this.name,
//     required this.quantity,
//     required this.cost,
//     this.unit = "pcs",
//   });
// }
//
// class Job {
//   final String id;
//   final Customer customer;
//   final String status;
//   final String assignedTo;
//   final String createdDate;
//   final String totalTimeSpent;
//   final Vehicle vehicle;
//   final String jobDescription;
//   final List<String> services;
//   final List<Part> parts;
//
//   late final DateTime date;
//
//   Job({
//     required this.id,
//     required this.customer,
//     required this.status,
//     required this.assignedTo,
//     required this.createdDate,
//     required this.totalTimeSpent,
//     required this.vehicle,
//     required this.jobDescription,
//     required this.services,
//     required this.parts,
//   }) {
//     date = DateTime.tryParse(createdDate) ?? DateTime.now();
//   }
//
//   String get customerName => customer.name;
//   String get vehicleModel => "${vehicle.model}(${vehicle.year})";
//   int get partsCount => parts.length;
//   double get totalPartsCost =>
//       parts.fold(0.0, (sum, part) => sum + (part.cost * part.quantity));
// }