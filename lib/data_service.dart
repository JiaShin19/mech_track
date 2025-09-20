//data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_model.dart';

class Mechanic {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String avatarUrl;

  Mechanic({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.avatarUrl,
  });
}

class DataService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache for current mechanic
  static Mechanic? _currentMechanic;

  /// 獲取當前技師 (示範：名字 = "Muhammad Azman")
  static Future<Mechanic?> getCurrentMechanic() async {
    if (_currentMechanic != null) return _currentMechanic;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;

    _currentMechanic = Mechanic(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      avatarUrl: data['image'] ?? '',
    );

    return _currentMechanic;
  }

  /// 獲取當前技師名稱 (同步方法)
  static String get currentMechanicName => _currentMechanic?.name ?? "Muhammad Azman";

  /// 從 jobs 集合獲取所有工作
  static Future<List<Job>> getAllJobs() async {
    final snapshot = await _db.collection('jobs').get();
    return snapshot.docs.map((doc) => _jobFromFirestore(doc.data())).toList();
  }

  /// 獲取本月的 Job
  static Future<List<Job>> getMonthlyJobs() async {
    final allJobs = await getAllJobs();
    final now = DateTime.now();

    return allJobs.where((job) {
      final jobDate = DateTime.tryParse(job.createdDate);
      return jobDate != null &&
          jobDate.year == now.year &&
          jobDate.month == now.month;
    }).toList()
      ..sort((a, b) => DateTime.parse(b.createdDate)
          .compareTo(DateTime.parse(a.createdDate)));
  }

  /// 獲取年度 Job
  static Future<List<Job>> getYearlyJobs() async {
    final allJobs = await getAllJobs();
    final now = DateTime.now();

    return allJobs.where((job) {
      final jobDate = DateTime.tryParse(job.createdDate);
      return jobDate != null && jobDate.year == now.year;
    }).toList()
      ..sort((a, b) => DateTime.parse(b.createdDate)
          .compareTo(DateTime.parse(a.createdDate)));
  }

  /// 獲取當前技師的工作
  static Future<List<Job>> getCurrentMechanicJobs() async {
    final mechanic = await getCurrentMechanic();
    if (mechanic == null) return [];

    final allJobs = await getAllJobs();
    return allJobs
        .where((job) =>
    job.assignedTo == mechanic.email || job.assignedTo == mechanic.name)
        .toList()
      ..sort((a, b) => DateTime.parse(b.createdDate)
          .compareTo(DateTime.parse(a.createdDate)));
  }

  /// 獲取某輛車的歷史服務紀錄
  static Future<List<Job>> getVehicleServiceHistory(String licensePlate) async {
    final allJobs = await getAllJobs();
    return allJobs
        .where((job) => job.vehicle.licensePlate == licensePlate)
        .toList()
      ..sort((a, b) => DateTime.parse(b.createdDate)
          .compareTo(DateTime.parse(a.createdDate)));
  }

  /// Firestore → Job
  static Job _jobFromFirestore(Map<String, dynamic> data) {
    final customerData = data['customer'] as Map<String, dynamic>? ?? {};
    final vehicleData = data['vehicle'] as Map<String, dynamic>? ?? {};
    final partsData = data['parts'] as Map<String, dynamic>? ?? {};

    return Job(
      id: data['id'] ?? '',
      customer: Customer(
        name: customerData['name'] ?? data['customerName'] ?? '',
        phone: customerData['phone'] ?? '',
        email: customerData['email'] ?? '',
        address: customerData['address'] ?? '',
        avatarUrl: customerData['avatarUrl'] ?? '',
      ),
      status: data['status'] ?? '',
      assignedTo: data['assignedToEmail'] ?? data['assignedTo'] ?? '',
      createdDate: data['createdDate'] ?? '',
      totalTimeSpent: data['totalTimeSpent'] ?? '',
      totalTimeSpentDisplay: data['totalTimeSpentDisplay'] ?? '',
      vehicle: Vehicle(
        model: vehicleData['model'] ?? '',
        year: vehicleData['year'] ?? '',
        color: vehicleData['color'] ?? '',
        licensePlate: vehicleData['licensePlate'] ?? '',
        currentMileage: vehicleData['currentMileage'] ?? '',
        imageUrl: vehicleData['imageUrl'] ?? '',
      ),
      jobDescription: data['jobDescription'] ?? '',
      services: List<String>.from(data['services'] ?? []),
      parts: partsData.entries.map((entry) {
        final part = entry.value as Map<String, dynamic>;
        return Part(
          name: part['name'] ?? '',
          quantity: int.tryParse(part['quantity']?.toString() ?? '0') ?? 0,
          cost: double.tryParse(part['cost']?.toString() ?? '0.0') ?? 0.0,
          unit: part['unit'] ?? '',
        );
      }).toList(),
    );
  }

  // Temporary in-memory cache of jobs
  static List<Job> _jobs = [];

  // Getter to access cached jobs
  static List<Job> get currentJobs => _jobs;

  // Method to load jobs into cache
  static Future<void> loadJobs() async {
    _jobs = await getAllJobs();
  }

  static void clearSession() {
    _currentMechanic = null;
    _jobs = [];
  }
}

// // data_service.dart
// import 'job_model.dart';
//
// class DataService {
//   static const String currentMechanic = "Muhammad Azman";
//
//   // 2024年
//   static final List<Job> _historicalJobs2024 = [
//     // 1月份 - Muhammad Azman的工作
//     Job(
//       id: "JOB-051",
//       customer: Customer(name: "Ahmad Zain", phone: "+60-121111111", email: "ahmad@gmail.com", address: "Ampang, KL"),
//       status: "Completed",
//       assignedTo: "Muhammad Azman",
//       createdDate: "2024-01-15",
//       totalTimeSpent: "3h",
//       vehicle: Vehicle(model: "Proton Saga", year: "2018", color: "White", licensePlate: "KL1001", currentMileage: "45000 km"),
//       jobDescription: "Engine oil change and general inspection",
//       services: ["Engine Oil Change", "General Inspection"],
//       parts: _generatePartsForServices(["Engine Oil Change", "General Inspection"]),
//     ),
//     Job(
//       id: "JOB-052",
//       customer: Customer(name: "Siti Aisyah", phone: "+60-132222222", email: "siti@gmail.com", address: "Shah Alam"),
//       status: "Completed",
//       assignedTo: "Muhammad Azman",
//       createdDate: "2024-01-28",
//       totalTimeSpent: "4h",
//       vehicle: Vehicle(model: "Honda City", year: "2019", color: "Silver", licensePlate: "SG2001", currentMileage: "38000 km"),
//       jobDescription: "Brake pad replacement and AC service",
//       services: ["Brake Pad Replacement", "AC System Service"],
//       parts: _generatePartsForServices(["Brake Pad Replacement", "AC System Service"]),
//     ),
//
//     // 2月份 - Muhammad Azman的工作
//     Job(
//       id: "JOB-053",
//       customer: Customer(name: "Chen Wei Lun", phone: "+60-173333333", email: "chen@gmail.com", address: "Petaling Jaya"),
//       status: "Completed",
//       assignedTo: "Muhammad Azman",
//       createdDate: "2024-02-12",
//       totalTimeSpent: "2h",
//       vehicle: Vehicle(model: "Toyota Vios", year: "2020", color: "Black", licensePlate: "PJ3001", currentMileage: "25000 km"),
//       jobDescription: "Engine oil change",
//       services: ["Engine Oil Change"],
//       parts: _generatePartsForServices(["Engine Oil Change"]),
//     ),
//     Job(
//       id: "JOB-054",
//       customer: Customer(name: "Raj Kumar", phone: "+60-194444444", email: "raj@gmail.com", address: "Subang Jaya"),
//       status: "Completed",
//       assignedTo: "Muhammad Azman",
//       createdDate: "2024-02-25",
//       totalTimeSpent: "5h",
//       vehicle: Vehicle(model: "Perodua Myvi", year: "2021", color: "Red", licensePlate: "SJ4001", currentMileage: "15000 km"),
//       jobDescription: "Transmission service and battery replacement",
//       services: ["Transmission Service", "Battery Replacement"],
//       parts: _generatePartsForServices(["Transmission Service", "Battery Replacement"]),
//     ),
//
//     // 3月份到12月份的数据 - 为Muhammad Azman生成更多工作记录
//     ...List.generate(36, (index) {
//       final month = 3 + (index ~/ 3); // 3月到12月，每月3个工作
//       final dayInMonth = 5 + ((index % 3) * 10); // 每月的5号、15号、25号
//
//       final customers = [
//         Customer(name: "Customer ${1000 + index}", phone: "+60-12${(5000 + index).toString()}", email: "cust${index}@gmail.com", address: "KL"),
//       ];
//
//       final vehicles = [
//         Vehicle(model: "Honda Civic", year: "${2018 + (index % 4)}", color: "White", licensePlate: "KL${5000 + index}", currentMileage: "${40000 + index * 1000} km"),
//         Vehicle(model: "Toyota Camry", year: "${2017 + (index % 5)}", color: "Black", licensePlate: "SG${6000 + index}", currentMileage: "${50000 + index * 800} km"),
//         Vehicle(model: "Proton X70", year: "${2019 + (index % 3)}", color: "Blue", licensePlate: "PJ${7000 + index}", currentMileage: "${30000 + index * 1200} km"),
//       ];
//
//       final servicesList = [
//         ["Engine Oil Change", "General Inspection"],
//         ["Brake Pad Replacement", "Air Filter Replacement"],
//         ["AC System Service", "Coolant System Service"],
//         ["Battery Replacement", "Engine Oil Change"],
//         ["Transmission Service", "Brake Fluid Change"],
//         ["Spark Plug Replacement", "Engine Oil Change"],
//       ];
//
//       final customerIndex = index % customers.length;
//       final vehicleIndex = index % vehicles.length;
//       final servicesIndex = index % servicesList.length;
//
//       return Job(
//         id: "JOB-${(100 + index).toString().padLeft(3, '0')}",
//         customer: customers[customerIndex],
//         status: "Completed",
//         assignedTo: "Muhammad Azman", // 全部是当前技师的工作
//         createdDate: "2024-${month.toString().padLeft(2, '0')}-${dayInMonth.toString().padLeft(2, '0')}",
//         totalTimeSpent: "${2 + (index % 4)}h",
//         vehicle: vehicles[vehicleIndex],
//         jobDescription: "Monthly maintenance work completed by Muhammad Azman.",
//         services: servicesList[servicesIndex],
//         parts: _generatePartsForServices(servicesList[servicesIndex]),
//       );
//     }),
//
//     // 添加其他技师的工作
//     ...List.generate(15, (index) {
//       final month = 2 + (index ~/ 2);
//       final dayInMonth = 10 + (index % 2) * 15;
//       final mechanics = ["Ashwin", "Lim Kai Hao"];
//       final mechanicIndex = index % mechanics.length;
//
//       return Job(
//         id: "JOB-${(200 + index).toString().padLeft(3, '0')}",
//         customer: Customer(name: "Other Customer ${index}", phone: "+60-14${(8000 + index).toString()}", email: "other${index}@gmail.com", address: "KL"),
//         status: "Completed",
//         assignedTo: mechanics[mechanicIndex],
//         createdDate: "2024-${month.toString().padLeft(2, '0')}-${dayInMonth.toString().padLeft(2, '0')}",
//         totalTimeSpent: "${2 + (index % 3)}h",
//         vehicle: Vehicle(model: "Other Car", year: "2020", color: "Various", licensePlate: "OTH${8000 + index}", currentMileage: "${35000 + index * 500} km"),
//         jobDescription: "Work completed by other mechanics.",
//         services: ["Engine Oil Change", "General Inspection"],
//         parts: _generatePartsForServices(["Engine Oil Change", "General Inspection"]),
//       );
//     }),
//   ];
//
//   // 当前Job数据（2025年7月）
//   static List<Job> get currentJobs {
//     final customer1 = Customer(
//       name: "Tan Hui Ling",
//       phone: "+60-123456789",
//       email: "huiling@gmail.com",
//       address: "1, Jalan 1, Taman Bunga, 52100 Kepong, KL",
//       avatarUrl: "assets/images/TanHuiLing.png",
//     );
//
//     final customer2 = Customer(
//       name: "Lee Hui Teng",
//       phone: "+60-178889999",
//       email: "leeteng@gmail.com",
//       address: "25, Jalan Mawar, Taman Melati, 53000 Kuala Lumpur",
//       avatarUrl: "assets/images/LeeHuiTeng.jpg",
//     );
//
//     final customer3 = Customer(
//       name: "Ahmad Rahman",
//       phone: "+60-191234567",
//       email: "ahmadrahman@gmail.com",
//       address: "12, Lorong Kenanga, Bandar Sunway, 47500 Selangor",
//       avatarUrl: "assets/images/AdmanRahman.webp",
//     );
//
//     final vehicle1 = Vehicle(
//       model: "Perodua Myvi",
//       year: "2020",
//       color: "White",
//       licensePlate: "ABC 1234",
//       currentMileage: "65,432 km",
//       imageUrl: "assets/images/WhiteMyvi.jpg",
//     );
//
//     final vehicle2 = Vehicle(
//       model: "Honda City",
//       year: "2019",
//       color: "Silver",
//       licensePlate: "DEF 5678",
//       currentMileage: "45,200 km",
//       imageUrl: "assets/images/SilverHondaCity.jpg",
//     );
//
//     final vehicle3 = Vehicle(
//       model: "Toyota Vios",
//       year: "2021",
//       color: "Blue",
//       licensePlate: "GHI 9012",
//       currentMileage: "28,900 km",
//       imageUrl: "assets/images/BlueToyotaVios.jpg",
//     );
//
//     return [
//       Job(
//         id: "JOB-001",
//         customer: customer1,
//         status: "In Progress",
//         assignedTo: currentMechanic,
//         createdDate: "2025-07-22",
//         totalTimeSpent: "5h",
//         vehicle: vehicle1,
//         jobDescription: "Customer reported unusual brake noise and requested routine maintenance. Engine oil is due for change based on mileage.",
//         services: ["Engine Oil Change", "Brake Pad Replacement", "Air Filter Replacement", "General Inspection"],
//         parts: _generatePartsForServices(["Engine Oil Change", "Brake Pad Replacement", "Air Filter Replacement", "General Inspection"]),
//       ),
//       Job(
//         id: "JOB-002",
//         customer: customer2,
//         status: "Completed",
//         assignedTo: currentMechanic,
//         createdDate: "2025-07-20",
//         totalTimeSpent: "3h",
//         vehicle: vehicle2,
//         jobDescription: "Regular maintenance service and tire pressure check. Customer also requested AC system inspection.",
//         services: ["Engine Oil Change", "AC System Diagnostic", "General Inspection"],
//         parts: _generatePartsForServices(["Engine Oil Change", "AC System Diagnostic", "General Inspection"]),
//       ),
//       Job(
//         id: "JOB-003",
//         customer: customer3,
//         status: "Assigned",
//         assignedTo: currentMechanic,
//         createdDate: "2025-07-22",
//         totalTimeSpent: "-",
//         vehicle: vehicle3,
//         jobDescription: "Customer reported air conditioning not working properly and requested diagnostic check. Also mentioned strange noise from engine during startup.",
//         services: ["AC System Service", "Engine Oil Change", "Spark Plug Replacement", "General Inspection"],
//         parts: _generatePartsForServices(["AC System Service", "Engine Oil Change", "Spark Plug Replacement", "General Inspection"]),
//       ),
//     ];
//   }
//
//   // 获取月度数据（只包含当前月的工作）
//   static List<Job> getMonthlyJobs() {
//     return currentJobs; // 2025年7月的工作
//   }
//
//   // 获取年度数据（2024 + 2025）
//   static List<Job> getYearlyJobs() {
//     return [..._historicalJobs2024, ...currentJobs];
//   }
//
//   // 获取当前技师的所有工作（用于底部导航的Service History）
//   static List<Job> getCurrentMechanicJobs() {
//     List<Job> allJobs = [..._historicalJobs2024, ...currentJobs];
//     return allJobs.where((job) => job.assignedTo == currentMechanic).toList()
//       ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
//   }
//
//   // 获取特定车辆的所有服务历史（不限制技师，用于从Vehicle详情进入的Service History）
//   static List<Job> getVehicleServiceHistory(String licensePlate) {
//     // 为演示目的，这里生成该车辆的历史记录
//     List<Job> allJobs = [..._historicalJobs2024, ...currentJobs];
//
//     // 找到该车辆的实际记录
//     List<Job> vehicleJobs = allJobs.where((job) => job.vehicle.licensePlate == licensePlate).toList();
//
//     // 如果没有历史记录，为该车辆生成一些历史服务记录
//     if (vehicleJobs.length < 3) {
//       // 获取该车辆的信息
//       Job? currentVehicleJob = allJobs.firstWhere(
//             (job) => job.vehicle.licensePlate == licensePlate,
//         orElse: () => currentJobs.first, // fallback
//       );
//
//       // 为该车辆生成一些历史服务记录
//       List<Job> generatedHistory = List.generate(5, (index) {
//         final month = 7 - index - 1; // 往前推几个月
//         final mechanics = [currentMechanic, "Ashwin", "Lim Kai Hao"];
//         final mechanicIndex = index % mechanics.length;
//
//         final servicesList = [
//           ["Engine Oil Change", "General Inspection"],
//           ["Brake Inspection", "Air Filter Replacement"],
//           ["AC System Service", "Coolant System Service"],
//           ["Battery Check", "Tire Rotation"],
//           ["Transmission Service", "Brake Fluid Change"],
//         ];
//
//         return Job(
//           id: "JOB-${licensePlate.replaceAll(' ', '')}-${(100 + index).toString()}",
//           customer: currentVehicleJob.customer,
//           status: "Completed",
//           assignedTo: mechanics[mechanicIndex],
//           createdDate: "2025-${month.toString().padLeft(2, '0')}-${(5 + index * 5).toString().padLeft(2, '0')}",
//           totalTimeSpent: "${2 + index % 3}h",
//           vehicle: currentVehicleJob.vehicle,
//           jobDescription: "Previous maintenance service for this vehicle.",
//           services: servicesList[index % servicesList.length],
//           parts: _generatePartsForServices(servicesList[index % servicesList.length]),
//         );
//       });
//
//       vehicleJobs.addAll(generatedHistory);
//     }
//
//     return vehicleJobs..sort((a, b) => b.createdDate.compareTo(a.createdDate));
//   }
//
//   static List<Part> _generatePartsForServices(List<String> services) {
//     List<Part> parts = [];
//
//     for (String service in services) {
//       switch (service) {
//         case "Engine Oil Change":
//           parts.add(Part(name: "Engine Oil 5W-30", quantity: 4, cost: 20.0, unit: "L"));
//           parts.add(Part(name: "Oil Filter", quantity: 1, cost: 15.0));
//           break;
//         case "Brake Pad Replacement":
//           parts.add(Part(name: "Brake Pads (Front)", quantity: 1, cost: 150.0, unit: "set"));
//           break;
//         case "Air Filter Replacement":
//           parts.add(Part(name: "Air Filter", quantity: 1, cost: 35.0));
//           break;
//         case "AC System Diagnostic":
//         case "AC System Service":
//           parts.add(Part(name: "AC Refrigerant", quantity: 1, cost: 80.0, unit: "kg"));
//           parts.add(Part(name: "AC Filter", quantity: 1, cost: 25.0));
//           break;
//         case "Spark Plug Replacement":
//           parts.add(Part(name: "Spark Plugs", quantity: 4, cost: 25.0));
//           break;
//         case "Transmission Service":
//           parts.add(Part(name: "Transmission Oil", quantity: 3, cost: 45.0, unit: "L"));
//           parts.add(Part(name: "Transmission Filter", quantity: 1, cost: 60.0));
//           break;
//         case "Brake Fluid Change":
//           parts.add(Part(name: "Brake Fluid", quantity: 1, cost: 40.0, unit: "L"));
//           break;
//         case "Coolant System Service":
//           parts.add(Part(name: "Coolant", quantity: 2, cost: 30.0, unit: "L"));
//           break;
//         case "Battery Replacement":
//           parts.add(Part(name: "Car Battery 12V", quantity: 1, cost: 180.0));
//           break;
//         case "Battery Check":
//         // Battery check typically doesn't require parts
//           break;
//         case "Brake Inspection":
//         // Inspection typically doesn't require parts
//           break;
//         case "Tire Rotation":
//         // Tire rotation typically doesn't require parts
//           break;
//         case "General Inspection":
//         // General inspection typically doesn't require parts
//           break;
//         default:
//         // For unknown services, add a generic part
//           parts.add(Part(name: "Miscellaneous Parts", quantity: 1, cost: 50.0));
//       }
//     }
//
//     return parts;
//   }
// }