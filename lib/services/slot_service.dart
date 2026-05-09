// lib/services/slot_service.dart
// v2.1.0 — Fetch dan cache slot waktu perkuliahan dari /kelas/slot-options
// Cache in-memory selama sesi app berjalan, fallback ke SlotDefaults jika API error

import 'dart:convert';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/models/kelas.dart';

class SlotService {
  // Singleton
  SlotService._();
  static final SlotService _instance = SlotService._();
  factory SlotService() => _instance;

  // ── In-memory cache ───────────────────────────────────────
  List<SlotOption>? _cachedSlots;
  DateTime?         _cachedAt;

  /// Durasi cache valid (12 jam)
  static const Duration _cacheDuration = Duration(hours: 12);

  // ── Fetch slot options ────────────────────────────────────
  /// Ambil semua slot waktu dari API.
  /// Menggunakan cache in-memory — hanya fetch ulang jika cache expired.
  /// Fallback ke [SlotDefaults] jika API tidak bisa diakses.
  Future<List<SlotOption>> getSlotOptions({bool forceRefresh = false}) async {
    // Return cache jika masih valid
    if (!forceRefresh && _cachedSlots != null && _cachedAt != null) {
      final age = DateTime.now().difference(_cachedAt!);
      if (age < _cacheDuration) return _cachedSlots!;
    }

    try {
      final response = await ApiClient().get('/kelas/slot-options');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        _cachedSlots = data
            .map((e) => SlotOption.fromJson(e as Map<String, dynamic>))
            .toList();
        _cachedAt = DateTime.now();
        return _cachedSlots!;
      }
    } catch (_) {
      // ignore
    }

    // Fallback: gunakan data default hardcoded
    _cachedSlots = SlotDefaults.all;
    _cachedAt    = DateTime.now();
    return _cachedSlots!;
  }

  // ── Helper: jam dari slot ─────────────────────────────────
  /// Konversi nomor slot ke label jam range: "07:00 – 09:30"
  Future<String> slotToJamRange(int slotMulai, int slotSelesai) async {
    final slots = await getSlotOptions();
    return SlotOption.rangeLabel(slotMulai, slotSelesai, slots);
  }

  /// Ambil jam mulai dari slot tertentu
  Future<String> getJamMulai(int slot) async {
    final slots = await getSlotOptions();
    final found = slots.firstWhere(
      (s) => s.slot == slot,
      orElse: () => SlotOption(
        slot: slot, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    return found.jamMulai;
  }

  /// Ambil jam selesai dari slot tertentu
  Future<String> getJamSelesai(int slot) async {
    final slots = await getSlotOptions();
    final found = slots.firstWhere(
      (s) => s.slot == slot,
      orElse: () => SlotOption(
        slot: slot, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    return found.jamSelesai;
  }

  // ── Synchronous versi (dari cache) ───────────────────────
  /// Ambil label jam dari cache tanpa async.
  /// Pastikan [getSlotOptions()] sudah dipanggil terlebih dahulu.
  String slotToJamSync(int? slotMulai, int? slotSelesai) {
    if (slotMulai == null) return '';
    final slots = _cachedSlots ?? SlotDefaults.all;
    final mulai = slots.firstWhere(
      (s) => s.slot == slotMulai,
      orElse: () => SlotOption(
        slot: slotMulai, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    if (slotSelesai == null) return mulai.jamMulai;
    final selesai = slots.firstWhere(
      (s) => s.slot == slotSelesai,
      orElse: () => SlotOption(
        slot: slotSelesai, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    return '${mulai.jamMulai} – ${selesai.jamSelesai}';
  }

  // ── Invalidate cache ──────────────────────────────────────
  void invalidate() {
    _cachedSlots = null;
    _cachedAt    = null;
  }
}