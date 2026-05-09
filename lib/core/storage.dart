// lib/core/storage.dart
// v2.1.0 — Tambah saveRaw/getRaw untuk FCM Service dan key-value generic

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
      key  : AppConstants.keyUserData,
      value: jsonEncode(user),
    );
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final raw = await _storage.read(key: AppConstants.keyUserData);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── [BARU v2.1.0] FCM Token ───────────────────────────────
  static Future<void> saveFcmToken(String token) async {
    await _storage.write(key: AppConstants.keyFcmToken, value: token);
  }

  static Future<String?> getFcmToken() async {
    return await _storage.read(key: AppConstants.keyFcmToken);
  }

  // ── [BARU v2.1.0] Generic key-value (untuk FcmService) ────
  /// Simpan nilai string dengan key apapun ke secure storage
  static Future<void> saveRaw({
    required String key,
    required String value,
  }) async {
    await _storage.write(key: key, value: value);
  }

  /// Baca nilai string dari secure storage berdasarkan key
  static Future<String?> getRaw({required String key}) async {
    return await _storage.read(key: key);
  }

  /// Hapus satu key dari secure storage
  static Future<void> deleteRaw({required String key}) async {
    await _storage.delete(key: key);
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