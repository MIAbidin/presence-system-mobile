// lib/screens/scan_screen.dart
// v2.1.0 — Fase 3 Langkah 3.1 SELESAI
//
// PERUBAHAN DARI v2.0.0:
// ✅ HAPUS: Modal pilih mode (Offline/Online) — tidak ada lagi
// ✅ HAPUS: Tombol pilih mode sebelum scan
// ✅ TAMBAH: SesiDetectService().detectSesiAktif() di initState
// ✅ TAMBAH: Info sesi terdeteksi di atas kamera (nama MK, kelas, dosen, mode)
// ✅ TAMBAH: Tombol 'Ikut sebagai Tamu' saat tidak ada jadwal aktif
// ✅ UPDATE: Overlay kamera → oval elegan dengan gradient border UMS
// ✅ UPDATE: Kirim kelas_id dari _sesiAktif secara otomatis ke POST /presensi/simple
// ✅ UPDATE: Jika sesi online terdeteksi → navigasi otomatis ke KodeSesiScreen

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/services/sesi_detect_service.dart';
import 'package:presensi_app/widgets/empty_error_state.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/screens/register_face_screen.dart'; // FaceOverlayPainter

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  @override
  bool get wantKeepAlive => true;

  // ── Camera ────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;

  // ── Face detection ────────────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(minFaceSize: 0.15),
  );
  bool _faceDetected      = false;
  bool _isProcessingFrame = false;

  // ── State ─────────────────────────────────────────────────
  bool _isVerifying   = false;

  // ── v2.1.0: Sesi Auto-Detect ──────────────────────────────
  SesiDetectResult? _sesiAktif;
  bool _isDetectingSesi = true;   // loading state saat detect pertama kali

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _detectSesiAktif();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      if (mounted) setState(() => _isCameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      _detectSesiAktif(); // re-detect saat app kembali aktif
    }
  }

  // ══════════════════════════════════════════════════════════
  // v2.1.0: AUTO-DETECT SESI AKTIF
  // ══════════════════════════════════════════════════════════

  Future<void> _detectSesiAktif() async {
    if (!mounted) return;
    setState(() => _isDetectingSesi = true);

    final result = await SesiDetectService().detectSesiAktif();

    if (!mounted) return;
    setState(() {
      _sesiAktif        = result;
      _isDetectingSesi  = false;
    });
  }

  // ══════════════════════════════════════════════════════════
  // CAMERA
  // ══════════════════════════════════════════════════════════

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final frontCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
        _startFaceDetection();
      }
    } catch (e) {
      if (mounted) _showSnack('Kamera error: $e', isError: true);
    }
  }

  void _startFaceDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (!mounted || _isProcessingFrame) return;
      _isProcessingFrame = true;
      try {
        final inputImage = _buildInputImage(image);
        if (inputImage == null) return;
        final faces = await _faceDetector.processImage(inputImage);
        if (mounted) setState(() => _faceDetected = faces.isNotEmpty);
      } catch (_) {
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  InputImage? _buildInputImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final rotation = InputImageRotationValue.fromRawValue(
            camera.sensorOrientation,
          ) ?? InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>(
          [],
          (allBytes, plane) => allBytes..addAll(plane.bytes),
        ),
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size      : Size(image.width.toDouble(), image.height.toDouble()),
          rotation  : rotation,
          format    : format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('InputImage error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // GPS
  // ══════════════════════════════════════════════════════════

  Future<Position?> _getGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Aktifkan GPS terlebih dahulu', isError: true);
        return null;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showSnack('Izin lokasi ditolak', isError: true);
          return null;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Izin lokasi ditolak permanen, buka Settings', isError: true);
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _showSnack('Gagal ambil GPS: $e', isError: true);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // v2.1.0: PRESENSI — AUTO BERDASARKAN SESI TERDETEKSI
  // ══════════════════════════════════════════════════════════

  /// Dipanggil saat tombol "Lakukan Presensi" ditekan.
  /// Sistem sudah auto-detect sesi → tidak ada pilihan mode manual.
  Future<void> _lakukanPresensi() async {
    if (_isVerifying || _sesiAktif == null || !_sesiAktif!.isFound) return;
    if (!_faceDetected) {
      _showSnack('Wajah belum terdeteksi', isError: true);
      return;
    }

    final sesi = _sesiAktif!;

    // ✅ Jika sesi ONLINE → navigasi ke KodeSesiScreen (dipanggil otomatis)
    if (sesi.isOnline) {
      context.go('/kode-sesi', extra: sesi.sesiId);
      return;
    }

    // ✅ Jika sesi OFFLINE → langsung scan wajah + GPS
    await _verifikasiWajahOffline(sesi);
  }

  Future<void> _verifikasiWajahOffline(SesiDetectResult sesi) async {
    if (_isVerifying || _cameraController == null || !_isCameraReady) return;

    setState(() => _isVerifying = true);

    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes = await foto.readAsBytes();

      // Ambil GPS
      final pos = await _getGps();
      if (pos == null) {
        setState(() => _isVerifying = false);
        _startFaceDetection();
        return;
      }

      // Build fields — sertakan kelas_id jika ada (v2.1.0)
      final fields = <String, String>{
        'latitude' : pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
      };
      if (sesi.kelasId != null && sesi.kelasId!.isNotEmpty) {
        fields['kelas_id'] = sesi.kelasId!;
      }

      final response = await ApiClient().postMultipart(
        '/presensi/simple',
        fields   : fields,
        fileField: 'foto',
        fileBytes: bytes,
        filename : 'scan_offline_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (mounted) {
        context.go('/hasil', extra: {
          'success': response.statusCode == 200,
          'status' : body['status']         ?? '',
          'akurasi': (body['akurasi_wajah'] as num?)?.toDouble() ?? 0.0,
          'waktu'  : body['waktu_presensi'] ?? '',
          'mode'   : 'offline',
          'pesan'  : response.statusCode == 200
              ? (body['pesan'] ?? 'Presensi berhasil!')
              : (body['detail'] ?? 'Presensi gagal'),
          // v2.1.0: info kelas
          'kelas_info' : sesi.kodeKelas,
          'is_tamu'    : false,
        });
      }
    } catch (e) {
      if (mounted) {
        context.go('/hasil', extra: {
          'success': false,
          'pesan'  : 'Error: $e',
          'status' : '', 'akurasi': 0.0, 'waktu': '', 'mode': 'offline',
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
        _startFaceDetection();
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // HELPER
  // ══════════════════════════════════════════════════════════

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? AppColors.kDanger : AppColors.kSuccess,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  bool get _canScan =>
      !_isVerifying &&
      !_isDetectingSesi &&
      _isCameraReady &&
      _faceDetected &&
      _sesiAktif != null &&
      _sesiAktif!.isFound;

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.kNavy,
        foregroundColor: Colors.white,
        title: const Text('Presensi Wajah'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            color : AppColors.kGold.withOpacity(0.4),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Info user ─────────────────────────────────────
          _buildUserHeader(user?.namaLengkap, user?.nimNidn),

          // ── Info sesi terdeteksi (v2.1.0) ────────────────
          _buildSesiInfoBanner(),

          // ── Camera + overlay ──────────────────────────────
          Expanded(child: _buildCameraView()),

          // ── Tombol presensi ───────────────────────────────
          _buildBottomActions(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Header user
  // ─────────────────────────────────────────────────────────

  Widget _buildUserHeader(String? nama, String? nimNidn) {
    return Container(
      color  : AppColors.kNavy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child  : Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.15),
            radius         : 20,
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama ?? 'Mahasiswa',
                  style: AppTypography.bodyBold.copyWith(color: Colors.white),
                ),
                Text(
                  nimNidn ?? '',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Banner info sesi yang terdeteksi (v2.1.0)
  // ─────────────────────────────────────────────────────────

  Widget _buildSesiInfoBanner() {
    // Loading
    if (_isDetectingSesi) {
      return Container(
        color  : AppColors.kNavy.withOpacity(0.95),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child  : Row(
          children: [
            const SizedBox(
              width : 14,
              height: 14,
              child : CircularProgressIndicator(
                color      : Colors.white54,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Mencari jadwal aktif...',
              style: AppTypography.caption.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Sesi ditemukan
    if (_sesiAktif != null && _sesiAktif!.isFound) {
      final sesi = _sesiAktif!;
      return Container(
        color  : AppColors.kNavy.withOpacity(0.97),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child  : Row(
          children: [
            // Ikon status sesi
            Container(
              padding   : const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color       : AppColors.kGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                sesi.isOnline
                    ? Icons.laptop_outlined
                    : Icons.location_on_outlined,
                color: AppColors.kGold,
                size : 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama MK
                  Text(
                    sesi.matakuliahNama ?? 'Matakuliah',
                    style  : AppTypography.bodyBold.copyWith(
                      color   : Colors.white,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Row: badge kelas + badge mode + dosen
                  Wrap(
                    spacing : 6,
                    runSpacing: 3,
                    children: [
                      if (sesi.kodeKelas != null)
                        KelasBadge(kodeKelas: sesi.kodeKelas!),
                      ModeBadge(mode: sesi.mode ?? 'offline'),
                      if (sesi.dosenNama != null)
                        Text(
                          sesi.dosenNama!,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white54),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Tombol refresh
            IconButton(
              onPressed : _detectSesiAktif,
              icon      : const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 18),
              tooltip   : 'Perbarui sesi',
              padding   : EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // Tidak ada sesi aktif
    return Container(
      color  : Colors.black.withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child  : Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tidak ada jadwal kelas aktif saat ini',
              style: AppTypography.caption.copyWith(color: Colors.white54),
            ),
          ),
          IconButton(
            onPressed : _detectSesiAktif,
            icon      : const Icon(Icons.refresh_rounded,
                color: Colors.white38, size: 16),
            tooltip   : 'Perbarui',
            padding   : EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Camera view + overlay oval UMS (v2.1.0)
  // ─────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        if (_isCameraReady && _cameraController != null)
          SizedBox.expand(child: CameraPreview(_cameraController!))
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Memuat kamera...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

        // ── v2.1.0: Overlay oval elegan dengan gradient border UMS ──
        CustomPaint(
          size   : Size.infinite,
          painter: UMSOvalOverlayPainter(faceDetected: _faceDetected),
        ),

        // Badge deteksi wajah
        Positioned(
          top: 16,
          child: _buildFaceDetectionBadge(),
        ),

        // Overlay verifikasi
        if (_isVerifying) _buildVerifyingOverlay(),
      ],
    );
  }

  Widget _buildFaceDetectionBadge() {
    return AnimatedContainer(
      duration  : const Duration(milliseconds: 300),
      padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (_faceDetected
            ? AppColors.kSuccess
            : Colors.red.shade700).withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _faceDetected ? Icons.face_rounded : Icons.face_retouching_off,
            color: Colors.white,
            size : 18,
          ),
          const SizedBox(width: 6),
          Text(
            _faceDetected ? 'Wajah Terdeteksi' : 'Arahkan Wajah ke Kamera',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Memverifikasi wajah...',
              style: AppTypography.bodyBold.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Bottom action — tombol presensi / tidak ada jadwal
  // ─────────────────────────────────────────────────────────

  Widget _buildBottomActions() {
    return Container(
      color  : const Color(0xFF111827),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ada sesi aktif → tampilkan instruksi + tombol scan ──
          if (!_isDetectingSesi && _sesiAktif != null && _sesiAktif!.isFound) ...[
            Text(
              _sesiAktif!.isOnline
                  ? 'Pastikan wajah berada di dalam oval, lalu masukkan kode sesi'
                  : 'Pastikan wajah berada di dalam oval sebelum scan',
              textAlign: TextAlign.center,
              style    : AppTypography.caption.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child : ElevatedButton.icon(
                onPressed: _canScan ? _lakukanPresensi : null,
                icon : Icon(
                  _sesiAktif!.isOnline
                      ? Icons.lock_open_rounded
                      : Icons.face_unlock_rounded,
                  size: 22,
                ),
                label: Text(
                  _isVerifying
                      ? 'Memverifikasi...'
                      : _sesiAktif!.isOnline
                          ? 'Masukkan Kode Sesi'
                          : 'Lakukan Presensi',
                  style: AppTypography.button.copyWith(
                    color: AppColors.kNavyDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canScan
                      ? AppColors.kGold
                      : Colors.grey.shade700,
                  foregroundColor: AppColors.kNavyDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]

          // ── Loading detect ─────────────────────────────────
          else if (_isDetectingSesi) ...[
            const SizedBox(height: 8),
            const Center(
              child: CircularProgressIndicator(
                color      : Colors.white54,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 8),
          ]

          // ── Tidak ada jadwal aktif → pesan + tombol tamu ───
          else ...[
            NoJadwalAktifState(
              onIkutTamu: () => context.go('/mahasiswa/tamu-sesi'),
            ),
            const SizedBox(height: 12),
            // Tombol refresh
            TextButton.icon(
              onPressed: _detectSesiAktif,
              icon : const Icon(Icons.refresh_rounded, size: 16,
                  color: Colors.white54),
              label: Text(
                'Perbarui Jadwal',
                style: AppTypography.caption.copyWith(color: Colors.white54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// v2.1.0: OVAL OVERLAY PAINTER — Tema UMS
// Menggantikan FaceOverlayPainter lama yang berbentuk lingkaran.
// Oval elegan dengan gradient border Navy + Gold UMS.
// ══════════════════════════════════════════════════════════════

class UMSOvalOverlayPainter extends CustomPainter {
  final bool faceDetected;

  UMSOvalOverlayPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX  = size.width / 2;
    final centerY  = size.height / 2 - 20; // sedikit ke atas
    final ovalW    = size.width  * 0.68;
    final ovalH    = size.height * 0.52;

    final ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width : ovalW,
      height: ovalH,
    );

    // ── 1. Darken seluruh layar ───────────────────────────────
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── 2. "Lubang" transparan berbentuk oval ─────────────────
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawOval(ovalRect, clearPaint);

    // ── 3. Border oval gradien UMS (navy → gold → navy) ───────
    final borderColor = faceDetected
        ? AppColors.kGold
        : AppColors.kNavyLight;

    final borderPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader      = SweepGradient(
          colors: faceDetected
              ? [
                  AppColors.kGold,
                  AppColors.kGold.withOpacity(0.6),
                  AppColors.kNavyLight,
                  AppColors.kGold,
                ]
              : [
                  AppColors.kNavyLight,
                  AppColors.kNavy.withOpacity(0.4),
                  AppColors.kNavyLight,
                  AppColors.kNavy.withOpacity(0.4),
                ],
          center: Alignment.center,
        ).createShader(ovalRect);

    canvas.drawOval(ovalRect, borderPaint);

    // ── 4. Sudut-sudut dekoratif (arc corner UMS) ─────────────
    _drawCornerArcs(canvas, ovalRect, faceDetected);

    // ── 5. Glow effect saat wajah terdeteksi ─────────────────
    if (faceDetected) {
      final glowPaint = Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color       = AppColors.kGold.withOpacity(0.18)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(ovalRect, glowPaint);
    }
  }

  void _drawCornerArcs(Canvas canvas, Rect oval, bool active) {
    final color = active ? AppColors.kGold : AppColors.kNavyLight;
    final paint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color      = color
      ..strokeCap  = StrokeCap.round;

    const arcLen  = 0.35; // panjang arc sudut dalam radian
    final rx      = oval.width  / 2;
    final ry      = oval.height / 2;
    const offsets = [0.0, 1.5707963, 3.1415927, 4.7123890]; // 4 sudut

    for (final angle in offsets) {
      canvas.drawArc(oval, angle - arcLen / 2, arcLen, false, paint);
    }
  }

  @override
  bool shouldRepaint(UMSOvalOverlayPainter old) =>
      old.faceDetected != faceDetected;
}