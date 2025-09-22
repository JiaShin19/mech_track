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
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for current mechanic
  static Mechanic? _currentMechanic;

  /// Get current logged-in user as mechanic
  static Future<Mechanic?> getCurrentMechanic() async {
    try {
      // Check if user is logged in
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No user is currently logged in');
        return null;
      }

      // If we have cached data for this user, return it
      if (_currentMechanic != null && _currentMechanic!.id == currentUser.uid) {
        return _currentMechanic;
      }

      // Fetch user data from Firestore
      final DocumentSnapshot doc = await _db.collection('users').doc(currentUser.uid).get();

      if (!doc.exists) {
        print('User document not found in Firestore for UID: ${currentUser.uid}');
        // Create mechanic from Firebase Auth data as fallback
        _currentMechanic = Mechanic(
          id: currentUser.uid,
          name: currentUser.displayName ?? 'Unknown User',
          email: currentUser.email ?? '',
          phone: currentUser.phoneNumber ?? '',
          address: '',
          avatarUrl: currentUser.photoURL ?? '',
        );
        return _currentMechanic;
      }

      final data = doc.data() as Map<String, dynamic>;

      _currentMechanic = Mechanic(
        id: currentUser.uid,
        name: data['name'] ?? currentUser.displayName ?? 'Unknown User',
        email: data['email'] ?? currentUser.email ?? '',
        phone: data['phone'] ?? currentUser.phoneNumber ?? '',
        address: data['address'] ?? '',
        avatarUrl: data['image'] ?? data['avatarUrl'] ?? currentUser.photoURL ?? '',
      );

      return _currentMechanic;
    } catch (e) {
      print('Error getting current mechanic: $e');
      return null;
    }
  }

  /// Get current mechanic name (synchronous method)
  static String get currentMechanicName {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      return _currentMechanic?.name ?? currentUser.displayName ?? currentUser.email ?? "Current User";
    }
    return "Not Logged In";
  }

  /// Get current mechanic email (synchronous method)
  static String get currentMechanicEmail {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      return _currentMechanic?.email ?? currentUser.email ?? "";
    }
    return "";
  }

  /// Get current mechanic ID (synchronous method)
  static String get currentMechanicId {
    final User? currentUser = _auth.currentUser;
    return currentUser?.uid ?? "";
  }

  /// Check if a mechanic name/email matches the current logged-in user
  static bool isCurrentMechanic(String identifier) {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final currentName = currentMechanicName;
    final currentEmail = currentMechanicEmail;

    return identifier == currentName ||
        identifier == currentEmail ||
        identifier == currentUser.email ||
        identifier == currentUser.displayName;
  }

  /// Get all jobs from Firebase
  static Future<List<Job>> getAllJobs() async {
    try {
      final snapshot = await _db.collection('jobs').get();
      return snapshot.docs.map((doc) => _jobFromFirestore(doc.data())).toList();
    } catch (e) {
      print('Error getting all jobs: $e');
      return [];
    }
  }

  /// Get monthly jobs
  static Future<List<Job>> getMonthlyJobs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final snapshot = await FirebaseFirestore.instance
        .collection("jobs")
        .where("assignedToEmail", isEqualTo: user.email)
        .where("createdDate", isGreaterThanOrEqualTo: firstDay.toIso8601String())
        .where("createdDate", isLessThan: nextMonth.toIso8601String())
        .get();

    return snapshot.docs
        .map((doc) => Job.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get yearly jobs
  static Future<List<Job>> getYearlyJobs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final startOfNextYear = DateTime(now.year + 1, 1, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection("jobs")
          .where("assignedToEmail", isEqualTo: user.email)
          .where("createdDate", isGreaterThanOrEqualTo: startOfYear.toIso8601String())
          .where("createdDate", isLessThan: startOfNextYear.toIso8601String())
          .get();

      return snapshot.docs
          .map((doc) => Job.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => DateTime.parse(b.createdDate)
            .compareTo(DateTime.parse(a.createdDate)));
    } catch (e) {
      print('Error getting yearly jobs: $e');
      return [];
    }
  }

  /// Get current mechanic's jobs
  static Future<List<Job>> getCurrentMechanicJobs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection("jobs")
        .where("assignedToEmail", isEqualTo: user.email)
        .get();

    return snapshot.docs
        .map((doc) => Job.fromMap(doc.data(), doc.id))
        .toList();
  }


  /// Get vehicle service history
  static Future<List<Job>> getVehicleServiceHistory(String licensePlate) async {
    try {
      final allJobs = await getAllJobs();
      return allJobs
          .where((job) => job.vehicle.licensePlate == licensePlate)
          .toList()
        ..sort((a, b) => DateTime.parse(b.createdDate)
            .compareTo(DateTime.parse(a.createdDate)));
    } catch (e) {
      print('Error getting vehicle service history: $e');
      return [];
    }
  }

  /// Convert Firestore data to Job
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

  // Clear session data (useful for logout)
  static void clearSession() {
    _currentMechanic = null;
    _jobs = [];
  }

  // Listen to auth state changes
  static void listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User logged out, clear session
        clearSession();
      } else {
        // User logged in, clear cached mechanic data to refresh
        _currentMechanic = null;
      }
    });
  }
}