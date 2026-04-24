// lib/core/storage.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:presensi_app/core/constants.dart';

class AppStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Access Token ──────────────────────────────────────────
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.keyAccessToken);
  }

  // ── Refresh Token ─────────────────────────────────────────
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.keyRefreshToken, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.keyRefreshToken);
  }

  // ── User Data ─────────────────────────────────────────────
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    await _storage.write(
      key: AppConstants.keyUserData,
      value: jsonEncode(user),
    );
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final raw = await _storage.read(key: AppConstants.keyUserData);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Clear all (logout) ────────────────────────────────────
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── Check if logged in ────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}