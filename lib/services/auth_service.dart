import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

/// Mirrors `TeacherResource` on the backend
/// (`app/Http/Resources/Api/Teacher/TeacherResource.php`).
class AuthenticatedTeacher {
  const AuthenticatedTeacher({
    required this.id,
    required this.name,
    this.nip,
    this.nuptk,
    this.email,
    this.phone,
    this.photoUrl,
    this.isHomeroom = false,
  });

  final int id;
  final String name;
  final String? nip;
  final String? nuptk;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isHomeroom;

  factory AuthenticatedTeacher.fromJson(Map<String, dynamic> json) {
    return AuthenticatedTeacher(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nip: json['nip'] as String?,
      nuptk: json['nuptk'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      isHomeroom: json['is_homeroom'] as bool? ?? false,
    );
  }

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Wraps `/api/v1/teacher/login`, `/me` and `/logout`, and persists the
/// Sanctum bearer token in secure storage so the session survives a restart.
class AuthService {
  AuthService({required this.client, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'teacher_token';

  final ApiClient client;
  final FlutterSecureStorage _storage;

  Future<AuthenticatedTeacher> login(String email, String password) async {
    final data = await client.post('/v1/teacher/login', body: {
      'email': email,
      'password': password,
      'device_name': 'mobile-sekolah-os',
    }) as Map<String, dynamic>;

    final token = data['token'] as String;
    client.setToken(token);
    await _storage.write(key: _tokenKey, value: token);
    return AuthenticatedTeacher.fromJson(
        data['teacher'] as Map<String, dynamic>);
  }

  /// Cold start: reuse the stored token and re-fetch the profile. Returns null
  /// when there is no token or it is no longer valid (expired/revoked).
  Future<AuthenticatedTeacher?> restore() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    client.setToken(token);
    try {
      final data = await client.get('/v1/teacher/me') as Map<String, dynamic>;
      return AuthenticatedTeacher.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await client.post('/v1/teacher/logout');
    } on ApiException {
      // Token may already be invalid server-side; local logout proceeds anyway.
    }
    await _clear();
  }

  Future<void> _clear() async {
    client.setToken(null);
    await _storage.delete(key: _tokenKey);
  }
}
