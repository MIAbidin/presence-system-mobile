// lib/services/notification_service.dart
// v2.1.0 Fase 6 UPDATE
// - pengingatBukaSesi sekarang navigasi ke /dosen/jadwal (bukan /dosen/home)
//   agar dosen langsung lihat jadwal hari ini dan bisa buka sesi dari sana.
// Setup flutter_local_notifications + channel Android/iOS.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/theme.dart';

// ── Payload type dari notifikasi ─────────────────────────────
enum NotifType {
  presensiSukses,
  presensGagal,
  sesiDibuka,
  kodeHampirExpired,
  sesiTutupOtomatis,
  pengingatBukaSesi,
  unknown,
}

class NotifPayload {
  final NotifType type;
  final String?   sesiId;
  final String?   matakuliahNama;
  final String?   role; // 'mahasiswa' | 'dosen'

  const NotifPayload({
    required this.type,
    this.sesiId,
    this.matakuliahNama,
    this.role,
  });

  factory NotifPayload.fromData(Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? '';
    final type = switch (typeStr) {
      'presensi_sukses'       => NotifType.presensiSukses,
      'presensi_gagal'        => NotifType.presensGagal,
      'sesi_dibuka'           => NotifType.sesiDibuka,
      'kode_hampir_expired'   => NotifType.kodeHampirExpired,
      'sesi_tutup_otomatis'   => NotifType.sesiTutupOtomatis,
      'pengingat_buka_sesi'   => NotifType.pengingatBukaSesi,
      _                       => NotifType.unknown,
    };

    return NotifPayload(
      type          : type,
      sesiId        : data['sesi_id']          as String?,
      matakuliahNama: data['matakuliah_nama']   as String?,
      role          : data['role']              as String?,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE
// ══════════════════════════════════════════════════════════════

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Navigator key — dipakai untuk navigasi dari notif tanpa BuildContext
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ── Channel Android ───────────────────────────────────────
  static const AndroidNotificationChannel _channelPresensi =
      AndroidNotificationChannel(
    'presensi_channel',
    'Presensi',
    description    : 'Notifikasi status presensi mahasiswa',
    importance     : Importance.high,
    playSound      : true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _channelSesi =
      AndroidNotificationChannel(
    'sesi_channel',
    'Sesi Perkuliahan',
    description: 'Notifikasi pembukaan dan penutupan sesi',
    importance : Importance.high,
    playSound  : true,
  );

  static const AndroidNotificationChannel _channelPengingat =
      AndroidNotificationChannel(
    'pengingat_channel',
    'Pengingat',
    description: 'Pengingat jadwal 15 menit sebelum kelas',
    importance : Importance.defaultImportance,
  );

  // ── Init ──────────────────────────────────────────────────
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS    : iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTapNotification,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channelPresensi);
    await androidPlugin?.createNotificationChannel(_channelSesi);
    await androidPlugin?.createNotificationChannel(_channelPengingat);
  }

  // ── Tampilkan notifikasi dari RemoteMessage (foreground) ──
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data      = message.data;
    final payload   = jsonEncode(data);
    final typeStr   = data['type'] as String? ?? '';
    final channelId = switch (typeStr) {
      'presensi_sukses' || 'presensi_gagal'
          => _channelPresensi.id,
      'sesi_dibuka' || 'sesi_tutup_otomatis' || 'kode_hampir_expired'
          => _channelSesi.id,
      _   => _channelPengingat.id,
    };

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelNama(channelId),
      importance      : Importance.high,
      priority        : Priority.high,
      color           : AppColors.kNavy,
      icon            : '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── Handler tap notif (foreground/background) ─────────────
  void _onTapNotification(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data    = jsonDecode(response.payload!) as Map<String, dynamic>;
      final payload = NotifPayload.fromData(data);
      _navigateFromPayload(payload);
    } catch (_) {}
  }

  void handleMessageOpenedApp(RemoteMessage message) {
    final payload = NotifPayload.fromData(message.data);
    _navigateFromPayload(payload);
  }

  Future<void> handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return;
    final payload = NotifPayload.fromData(message.data);
    await Future.delayed(const Duration(milliseconds: 800));
    _navigateFromPayload(payload);
  }

  // ── Routing berdasarkan tipe notifikasi ───────────────────
  void _navigateFromPayload(NotifPayload payload) {
    final router = navigatorKey.currentContext != null
        ? GoRouter.of(navigatorKey.currentContext!)
        : null;

    if (router == null) return;

    final role = payload.role;

    switch (payload.type) {
      // Mahasiswa: presensi berhasil/gagal → riwayat
      case NotifType.presensiSukses:
      case NotifType.presensGagal:
        if (role == 'mahasiswa') router.go('/riwayat');

      // Mahasiswa: sesi dibuka → scan (auto-detect cek sesi aktif)
      // CATATAN: notif sesi dibuka TIDAK menyertakan kode sesi (v2.1.0)
      case NotifType.sesiDibuka:
        if (role == 'mahasiswa') router.go('/scan');

      // Mahasiswa: kode hampir expired → scan
      case NotifType.kodeHampirExpired:
        if (role == 'mahasiswa') router.go('/scan');

      // Dosen: sesi tutup otomatis → rekap sesi
      case NotifType.sesiTutupOtomatis:
        if (role == 'dosen') {
          if (payload.sesiId != null) {
            router.go('/dosen/rekap/${payload.sesiId}');
          } else {
            router.go('/dosen/rekap-list');
          }
        }

      // [Fase 6 UPDATE] Dosen: pengingat buka sesi → tab Jadwal
      // (sebelumnya menuju /dosen/home — sekarang lebih tepat ke Jadwal
      //  agar dosen langsung lihat jadwal hari ini dan tap "Buka Sesi")
      case NotifType.pengingatBukaSesi:
        if (role == 'dosen') router.go('/dosen/jadwal');

      case NotifType.unknown:
        break;
    }
  }

  // ── Helper ────────────────────────────────────────────────
  String _channelNama(String channelId) => switch (channelId) {
    'presensi_channel'  => 'Presensi',
    'sesi_channel'      => 'Sesi Perkuliahan',
    'pengingat_channel' => 'Pengingat',
    _                   => 'Notifikasi',
  };
}