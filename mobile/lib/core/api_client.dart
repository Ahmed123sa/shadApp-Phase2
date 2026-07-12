import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
  final Duration _timeout = const Duration(seconds: 30);
  String? _token;
  int? userId;
  int? workspaceId;
  int get workspaceIdSafe => workspaceId ?? 1;
  String? role;
  String? userName;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static final ApiClient _instance = ApiClient._();
  ApiClient._();
  factory ApiClient() => _instance;

  Future<void> init() async {
    _token = await _secureStorage.read(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('base_url') ?? baseUrl;
    role = prefs.getString('role');
    userId = prefs.getInt('user_id');
    workspaceId = prefs.getInt('workspace_id');
    userName = prefs.getString('user_name');
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = await _secureStorage.read(key: 'token');
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    userId = null;
    workspaceId = null;
    role = null;
    userName = null;
    await _secureStorage.delete(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('user_id');
    await prefs.remove('workspace_id');
    await prefs.remove('user_name');
  }

  Future<void> setRole(String value) async {
    role = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', value);
  }

  Future<String?> getRole() async {
    if (role != null) return role;
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString('role');
    return role;
  }

  Future<void> setUserData({int? id, String? name, int? workspace}) async {
    if (id != null) userId = id;
    if (name != null) userName = name;
    if (workspace != null) workspaceId = workspace;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) await prefs.setInt('user_id', id);
    if (name != null) await prefs.setString('user_name', name);
    if (workspace != null) await prefs.setInt('workspace_id', workspace);
  }

  Future<void> registerFcmToken(String token, String deviceType) async {
    try {
      await post('/notifications/register-token', {
        'token': token,
        'device_type': deviceType,
      });
    } catch (_) {}
  }

  String resolveFileUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = baseUrl.replaceFirst('/api', '');
    String cleaned = url;
    if (cleaned.startsWith('/')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('storage/')) return '$base/$cleaned';
    return '$base/storage/$cleaned';
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
  }

  Future<Map<String, String>> _headers({bool multipart = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (!multipart) headers['Content-Type'] = 'application/json';
    final token = await getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers()).timeout(_timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'), headers: await _headers()).timeout(_timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> multipartPost(String path, Map<String, dynamic> fields,
      {File? file, Uint8List? bytes, String? filename, String fileField = 'file',
       List<File>? multipleFiles, String multipleFileField = 'files[]',
       List<Uint8List>? multipleBytes, List<String>? multipleBytesNames}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll(await _headers(multipart: true));
    fields.forEach((key, value) => request.fields[key] = value.toString());
    if (multipleFiles != null) {
      for (final f in multipleFiles) {
        if (kIsWeb) {
          throw UnsupportedError('multipleFiles not supported on web; use multipleBytes');
        }
        request.files.add(await http.MultipartFile.fromPath(multipleFileField, f.path));
      }
    } else if (multipleBytes != null) {
      for (int i = 0; i < multipleBytes.length; i++) {
        final fn = (multipleBytesNames != null && i < multipleBytesNames.length) ? multipleBytesNames[i] : null;
        request.files.add(http.MultipartFile.fromBytes(multipleFileField, multipleBytes[i], filename: fn));
      }
    } else if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
    } else if (file != null) {
      if (kIsWeb) {
        throw UnsupportedError('Use bytes parameter instead of File on web');
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> multipartPostMultiple(String path, Map<String, dynamic> fields, {required List<File> files, String fileField = 'files[]'}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll(await _headers(multipart: true));
    fields.forEach((key, value) => request.fields[key] = value.toString());
    for (final file in files) {
      if (kIsWeb) {
        throw UnsupportedError('multipartPostMultiple does not support web yet');
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Map<String, dynamic> _handle(http.Response response) {
    final data = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : <String, dynamic>{};
    if (response.statusCode == 401) {
      clearToken();
      throw AuthException(data['message'] ?? 'انتهت الجلسة');
    }
    if (response.statusCode == 422) {
      final errors = data['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values.firstOrNull;
      final msg = firstError is List ? firstError.first.toString() : (data['message'] ?? 'بيانات غير صحيحة');
      throw ValidationException(msg);
    }
    if (response.statusCode >= 400) {
      throw ServerException(data['message'] ?? 'حدث خطأ في الخادم');
    }
    return data;
  }
}

List<dynamic> safeList(dynamic value) {
  if (value is List) return value;
  if (value is Map) return (value['data'] as List<dynamic>?) ?? [];
  return [];
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}
