import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String wilaya,
    required String role,
    String? ccp,
    String? sellerType,
    double? capacityLiters,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'wilaya': wilaya,
      'role': role,
    };
    if (ccp != null && ccp.isNotEmpty) body['ccp'] = ccp;
    if (sellerType != null) body['seller_type'] = sellerType;
    if (capacityLiters != null) body['capacity_liters'] = capacityLiters;
    return await ApiService.post('/auth/register', body, withAuth: false);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await ApiService.post(
      '/auth/login',
      {'email': email, 'password': password},
      withAuth: false,
    );
    if (result['success'] == true) {
      final data = result['data'];
      if (data['token'] != null) {
        await _saveSession(data);
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final result = await ApiService.post(
      '/auth/verify-otp',
      {'email': email, 'otp': otp},
      withAuth: false,
    );
    if (result['success'] == true) {
      final data = result['data'];
      if (data['token'] != null) {
        await _saveSession(data);
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    return await ApiService.post(
      '/auth/resend-otp',
      {'email': email},
      withAuth: false,
    );
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await ApiService.post(
      '/auth/forgot-password',
      {'email': email},
      withAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    return await ApiService.post(
      '/auth/verify-reset-otp',
      {'email': email, 'otp': otp},
      withAuth: false,
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return await ApiService.post(
      '/auth/reset-password',
      {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      withAuth: false,
    );
  }

  static Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    // Remove session keys but keep 'onboarding_done' so onboarding never repeats
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_wilaya');
    await prefs.remove('user_id');
    await prefs.remove('seller_type');
    await prefs.remove('capacity_liters');
    await prefs.remove('is_available');
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    final user = data['user'];
    if (user != null) await saveUserInfo(prefs, user);
  }

  /// Persists all user fields locally. Call after login, OTP verify, and profile update.
  static Future<void> saveUserInfo(
    SharedPreferences prefs,
    Map<String, dynamic> user,
  ) async {
    await prefs.setString('role', user['role'] ?? '');
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setString('user_phone', user['phone'] ?? '');
    await prefs.setString('user_wilaya', user['wilaya'] ?? '');
    await prefs.setInt('user_id', user['id'] ?? 0);
    await prefs.setString('user_ccp', user['ccp'] ?? '');
    await prefs.setString('seller_type', user['seller_type'] ?? '');
    if (user['capacity_liters'] != null) {
      await prefs.setString('capacity_liters', user['capacity_liters'].toString());
    }
    await prefs.setBool('is_available', user['is_available'] ?? true);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name':            prefs.getString('user_name') ?? '',
      'email':           prefs.getString('user_email') ?? '',
      'phone':           prefs.getString('user_phone') ?? '',
      'wilaya':          prefs.getString('user_wilaya') ?? '',
      'role':            prefs.getString('role') ?? '',
      'ccp':             prefs.getString('user_ccp') ?? '',
      'seller_type':     prefs.getString('seller_type') ?? '',
      'capacity_liters': prefs.getString('capacity_liters') ?? '',
      'is_available':    (prefs.getBool('is_available') ?? true).toString(),
    };
  }
}
