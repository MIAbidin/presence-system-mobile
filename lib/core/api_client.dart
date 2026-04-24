// lib/core/api_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:presensi_app/core/constants.dart';
import 'package:presensi_app/core/storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final String _baseUrl = AppConstants.baseUrl;

  // ── Build headers with auto JWT ───────────────────────────
  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await AppStorage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── GET ───────────────────────────────────────────────────
  Future<http.Response> get(String path) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  // ── POST (JSON) ───────────────────────────────────────────
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(withAuth: withAuth),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  // ── POST (Multipart — for photo upload) ───────────────────
  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final token   = await AppStorage.getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: filename,
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    return await http.Response.fromStream(streamed);
  }

  // ── PATCH ─────────────────────────────────────────────────
  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  // ── Response handler ──────────────────────────────────────
  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: body['detail'] ?? 'An error occurred',
      );
    }
    return response;
  }
}

// Custom exception for API errors
class ApiException implements Exception {
  final int    statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}