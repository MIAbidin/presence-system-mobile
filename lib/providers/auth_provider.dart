// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/storage.dart';
import 'package:presensi_app/models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status      = AuthStatus.unknown;
  UserModel? _currentUser;
  String?    _errorMessage;
  bool       _isLoading   = false;

  AuthStatus get status       => _status;
  UserModel? get currentUser  => _currentUser;
  String?    get errorMessage => _errorMessage;
  bool       get isLoading    => _isLoading;
  bool       get isLoggedIn   => _status == AuthStatus.authenticated;

  // Dipanggil saat app start — WAJIB validasi token ke server
  Future<void> checkAuth() async {
    final token = await AppStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Pakai getRaw() agar tidak throw untuk status 401
    try {
      final response = await ApiClient().getRaw('/auth/me');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(data);
        await AppStorage.saveUserData(data);
        _status = AuthStatus.authenticated;
      } else {
        // Token tidak valid di server → paksa login ulang
        await AppStorage.clearAll();
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // Tidak bisa reach server → fallback ke data lokal
      final userData = await AppStorage.getUserData();
      if (userData != null) {
        _currentUser = UserModel.fromJson(userData);
        _status      = AuthStatus.authenticated;
      } else {
        await AppStorage.clearAll();
        _status = AuthStatus.unauthenticated;
      }
    }

    notifyListeners();
  }

  Future<bool> login(String nimNidn, String password) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient().post(
        '/auth/login',
        body    : {'nim_nidn': nimNidn, 'password': password},
        withAuth: false,
      );

      final data = jsonDecode(response.body);

      await AppStorage.saveAccessToken(data['access_token']);
      await AppStorage.saveRefreshToken(data['refresh_token']);

      final user = UserModel.fromJson(data['user']);
      await AppStorage.saveUserData(data['user']);

      _currentUser = user;
      _status      = AuthStatus.authenticated;
      _isLoading   = false;
      notifyListeners();
      return true;

    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status       = AuthStatus.unauthenticated;
      _isLoading    = false;
      notifyListeners();
      return false;

    } catch (e) {
      _errorMessage = 'Tidak dapat terhubung ke server, periksa koneksi';
      _status       = AuthStatus.unauthenticated;
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient().post('/auth/logout');
    } catch (_) {}
    await AppStorage.clearAll();
    _currentUser = null;
    _status      = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await AppStorage.getRefreshToken();
      if (refreshToken == null) return false;
      final response = await ApiClient().post(
        '/auth/refresh-token',
        body    : {'refresh_token': refreshToken},
        withAuth: false,
      );
      final data = jsonDecode(response.body);
      await AppStorage.saveAccessToken(data['access_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateFaceRegistered(bool value) {
    if (_currentUser == null) return;
    _currentUser = UserModel(
      id              : _currentUser!.id,
      nimNidn         : _currentUser!.nimNidn,
      namaLengkap     : _currentUser!.namaLengkap,
      email           : _currentUser!.email,
      role            : _currentUser!.role,
      programStudi    : _currentUser!.programStudi,
      isFaceRegistered: value,
    );
    notifyListeners();
  }
}