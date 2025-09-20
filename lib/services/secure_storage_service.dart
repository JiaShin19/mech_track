import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveAdminCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: 'admin_email', value: email);
    await _storage.write(key: 'admin_password', value: password);
  }

  Future<Map<String, String?>> getAdminCredentials() async {
    final email = await _storage.read(key: 'admin_email');
    final password = await _storage.read(key: 'admin_password');
    return {
      'email': email,
      'password': password,
    };
  }

  Future<void> clearAdminCredentials() async {
    await _storage.delete(key: 'admin_email');
    await _storage.delete(key: 'admin_password');
  }
}
