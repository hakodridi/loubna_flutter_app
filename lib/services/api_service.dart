import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl => 'https://loubna-laravel-project-main-mhonqj.free.laravel.cloud/api';

  static String get storageUrl => 'https://loubna-laravel-project-main-mhonqj.free.laravel.cloud/api/storage';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    // Auth endpoints that send email (register, resend-otp) need extra time
    // because they wait for the SMTP handshake before responding.
    final isMailEndpoint = endpoint.contains('register') ||
        endpoint.contains('resend-otp');
    final timeout =
        isMailEndpoint ? const Duration(seconds: 40) : const Duration(seconds: 15);

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Sends a multipart POST. Optionally attaches a file.
  /// Use this for endpoints that accept both form fields and an optional image.
  static Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    XFile? file,
    String fieldName = 'file',
  }) async {
    try {
      final token = await _getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      if (file != null) {
        if (kIsWeb) {
          final Uint8List bytes = await file.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: file.name,
          ));
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(fieldName, file.path),
          );
        }
      }

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  /// Uploads an [XFile] (from image_picker) as multipart — works on web and mobile.
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    XFile file,
    Map<String, String> fields,
  ) async {
    try {
      final token = await _getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      if (kIsWeb) {
        // On web, read bytes directly — dart:io File is unavailable
        final Uint8List bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'receipt_photo',
          bytes,
          filename: file.name,
        ));
      } else {
        // On mobile/desktop, use the file path
        request.files.add(
          await http.MultipartFile.fromPath('receipt_photo', file.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Error occurred',
        'errors': data['errors'],
        'data': data,
      };
    } catch (e) {
      return {'success': false, 'message': 'Invalid server response'};
    }
  }
}
