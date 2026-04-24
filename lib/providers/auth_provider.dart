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

  // ── Getters ───────────────────────────────────────────────
  AuthStatus get status       => _status;
  UserModel? get currentUser  => _currentUser;
  String?    get errorMessage => _errorMessage;
  bool       get isLoading    => _isLoading;
  bool       get isLoggedIn   => _status == AuthStatus.authenticated;

  // ── Check session on app start ────────────────────────────
  Future<void> checkAuth() async {
    final loggedIn = await AppStorage.isLoggedIn();
    if (!loggedIn) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Restore user from local storage
    final userData = await AppStorage.getUserData();
    if (userData != null) {
      _currentUser = UserModel.fromJson(userData);
      _status      = AuthStatus.authenticated;
      notifyListeners();
    } else {
      // Token exists but user data is missing — re-fetch from API
      await _fetchCurrentUser();
    }
  }

  // ── Login ─────────────────────────────────────────────────
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

      // Save tokens to secure storage
      await AppStorage.saveAccessToken(data['access_token']);
      await AppStorage.saveRefreshToken(data['refresh_token']);

      // Save user data locally
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
      _errorMessage = 'Cannot connect to server, please check your connection';
      _status       = AuthStatus.unauthenticated;
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await ApiClient().post('/auth/logout');
    } catch (_) {
      // Still logout even if API call fails
    }
    await AppStorage.clearAll();
    _currentUser = null;
    _status      = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Refresh access token silently ─────────────────────────
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

  // ── Fetch current user from API ───────────────────────────
  Future<void> _fetchCurrentUser() async {
    try {
      final response = await ApiClient().get('/auth/me');
      final data     = jsonDecode(response.body);
      _currentUser   = UserModel.fromJson(data);
      await AppStorage.saveUserData(data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Update face registered flag locally ───────────────────
  // Called after successful face registration in Phase 7
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