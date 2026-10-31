import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Thrown for any non-2xx response. Carries the backend's `errors.message`
/// (`ApiResponds` envelope) so screens can show it directly.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin wrapper around `http` for the `/api/v1/teacher/*` JSON envelope
/// (`{data, meta, errors}`). Handles the bearer token and unwraps `data`.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers);
    return _unwrap(response);
  }

  /// Like [get] but returns the whole `{data, meta}` envelope, for paginated
  /// lists that need `meta.last_page`.
  Future<Map<String, dynamic>> getEnvelope(String path,
      {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers);
    final data = _unwrap(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return {'data': data, 'meta': body['meta'] ?? const {}};
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _unwrap(response);
  }

  /// DELETE with a JSON body (unregistering a phone's push token).
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final request = http.Request('DELETE', _uri(path))
      ..headers.addAll(_headers)
      ..body = body != null ? jsonEncode(body) : '';
    return _unwrap(await http.Response.fromStream(await _client.send(request)));
  }

  /// `multipart/form-data` POST (a leave request with its attachment).
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields)
      ..files.addAll(files)
      ..headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    final response = await http.Response.fromStream(await _client.send(request));
    return _unwrap(response);
  }

  /// Raw bytes of a download (an attachment); errors still come as the envelope.
  Future<List<int>> getBytes(String path) async {
    final response = await _client.get(_uri(path), headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _unwrap(response); // throws the ApiException
    return const [];
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _unwrap(response);
  }

  dynamic _unwrap(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Server tidak merespons dengan benar (status ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['data'];
    }

    final errors = body['errors'] as Map<String, dynamic>?;
    throw ApiException(
      errors?['message'] as String? ?? 'Terjadi kesalahan.',
      statusCode: response.statusCode,
      details: errors?['details'] as Map<String, dynamic>?,
    );
  }

  void dispose() => _client.close();
}
