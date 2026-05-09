// lib/screens/kode_sesi_screen.dart
// v2.1.0 — Fase 3 Langkah 3.2 SELESAI
//
// PERUBAHAN DARI v2.0.0:
// ✅ TAMBAH: Parameter konteks sesi (SesiDetectResult) dari ScanScreen
// ✅ TAMBAH: Header konteks sesi — nama MK, KelasBadge, nama dosen
// ✅ TAMBAH: Instruksi "Masukkan kode yang dibagikan dosen via WhatsApp/Zoom"
// ✅ TAMBAH: Tampilkan info kelas (A/B/C) saat kode valid (dari GET /sesi/cek-kode)
// ✅ HAPUS: Tombol "Kembali pilih mode" — mode sudah otomatis dari ScanScreen
// ✅ UPDATE: Dipanggil otomatis oleh ScanScreen, bukan manual mahasiswa
// ✅ UPDATE: Tema UMS — Navy + Gold, tipografi Montserrat/Inter

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/services/sesi_detect_service.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/screens/scan_screen.dart'; // _UMSOvalOverlayPainter

class KodeSesiScreen extends StatefulWidget {
  /// [sesiAktif] dikirim dari ScanScreen saat sesi online terdeteksi otomatis.
  /// Berisi nama MK, kelas, dosen, sesiId untuk konteks tampilan.
  /// Bisa null jika screen dibuka via route langsung (edge case).
  final SesiDetectResult? sesiAktif;

  /// [sesiId] — backward-compat untuk route /kode-sesi yang menerima String?
  final String? sesiId;

  const KodeSesiScreen({super.key, this.sesiAktif, this.sesiId});

  @override
  State<KodeSesiScreen> createState() => _KodeSesiScreenState();
}

class _KodeSesiScreenState extends State<KodeSesiScreen> {

  // ── Input kode ────────────────────────────────────────────
  String _kode    = '';
  bool   _isValid = false;

  // ── Validasi kode ─────────────────────────────────────────
  bool  _isValidating = false;
  bool  _kodeOk       = false;

  /// Info sesi dari GET /sesi/cek-kode — tersedia setelah kode valid
  Map<String, dynamic>? _infoSesiFromServer;

  // ── Camera & face detection ───────────────────────────────
  CameraController?       _cameraController;
  List<CameraDescription> _cameras = [];
  bool   _isCameraReady     = false;
  bool   _faceDetected      = false;
  bool   _isProcessingFrame = false;
  bool   _isScanning        = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(minFaceSize: 0.25),
  );

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // VALIDASI KODE
  // ══════════════════════════════════════════════════════════

  Future<void> _validasiKode() async {
    if (_kode.length != 6) return;
    setState(() => _isValidating = true);

    try {
      final response = await ApiClient().getRaw(
        '/sesi/cek-kode?kode=${_kode.toUpperCase()}',
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final sesiRaw = body['sesi'];
        setState(() {
          _kodeOk           = true;
          _infoSesiFromServer = sesiRaw is Map
              ? Map<String, dynamic>.from(sesiRaw)
              : null;
        });

        final mkNama = _infoSesiFromServer?['matakuliah'] as String? ?? '';
        final kodeKelas = _infoSesiFromServer?['kode_kelas'] as String?;
        final kelasInfo = kodeKelas != null ? ' · Kelas $kodeKelas' : '';
        _showSnack(
          'Kode valid!${mkNama.isNotEmpty ? " · $mkNama" : ""}$kelasInfo — Sekarang scan wajah.',
        );
        await _initCamera();
      } else {
        _showSnack(_extractDetail(body['detail']), isError: true);
      }
    } catch (e) {
      _showSnack('Gagal memvalidasi kode: $e', isError: true);
    } finally {
      setState(() => _isValidating = false);
    }
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
      _showSnack('Kamera error: $e', isError: true);
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
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      final rotation = InputImageRotationValue.fromRawValue(
              camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>(
            [], (all, plane) => all..addAll(plane.bytes)),
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size       : Size(image.width.toDouble(), image.height.toDouble()),
          rotation   : rotation,
          format     : format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // SCAN WAJAH & KIRIM PRESENSI
  // ══════════════════════════════════════════════════════════

  Future<void> _scanWajah() async {
    if (_isScanning || !_faceDetected || _cameraController == null) return;
    setState(() => _isScanning = true);

    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes = await foto.readAsBytes();

      // Build fields — sertakan kelas_id jika ada dari sesiAktif (v2.1.0)
      final fields = <String, String>{
        'kode_sesi': _kode.toUpperCase(),
      };
      if (widget.sesiAktif?.kelasId != null &&
          widget.sesiAktif!.kelasId!.isNotEmpty) {
        fields['kelas_id'] = widget.sesiAktif!.kelasId!;
      }

      final response = await ApiClient().postMultipart(
        '/presensi/simple',
        fields   : fields,
        fileField: 'foto',
        fileBytes: bytes,
        filename : 'scan_online_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (mounted) {
        context.go('/hasil', extra: {
          'success': response.statusCode == 200,
          'status' : body['status']         ?? '',
          'akurasi': (body['akurasi_wajah'] as num?)?.toDouble() ?? 0.0,
          'waktu'  : body['waktu_presensi'] ?? '',
          'mode'   : 'online',
          'pesan'  : response.statusCode == 200
              ? (body['pesan'] ?? 'Presensi berhasil!')
              : _extractDetail(body['detail']),
          // v2.1.0: info kelas
          'kelas_info': _effectiveKodeKelas,
          'is_tamu'   : false,
        });
      }
    } catch (e) {
      if (mounted) {
        context.go('/hasil', extra: {
          'success': false,
          'pesan'  : 'Error: $e',
          'status' : '', 'akurasi': 0.0, 'waktu': '', 'mode': 'online',
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
        _startFaceDetection();
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // RESET
  // ══════════════════════════════════════════════════════════

  void _resetKode() {
    _cameraController?.dispose();
    setState(() {
      _kodeOk             = false;
      _kode               = '';
      _isValid            = false;
      _infoSesiFromServer = null;
      _cameraController   = null;
      _isCameraReady      = false;
      _faceDetected       = false;
    });
  }

  // ══════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════

  /// Kode kelas efektif: prioritaskan dari server, fallback dari sesiAktif
  String? get _effectiveKodeKelas =>
      _infoSesiFromServer?['kode_kelas'] as String? ??
      widget.sesiAktif?.kodeKelas;

  /// Nama MK efektif: prioritaskan dari server, fallback dari sesiAktif
  String get _effectiveMkNama =>
      _infoSesiFromServer?['matakuliah'] as String? ??
      widget.sesiAktif?.matakuliahNama ??
      '';

  /// Nama dosen efektif
  String? get _effectiveDosenNama =>
      _infoSesiFromServer?['dosen_nama'] as String? ??
      widget.sesiAktif?.dosenNama;

  /// Nomor pertemuan
  int? get _effectivePertemuan =>
      _infoSesiFromServer?['pertemuan_ke'] as int? ??
      widget.sesiAktif?.pertemuanKe;

  String _extractDetail(dynamic detail) {
    if (detail is String) return detail;
    if (detail is List) {
      return detail
          .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
          .join(', ');
    }
    return 'Terjadi kesalahan';
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? AppColors.kDanger : AppColors.kSuccess,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: AppColors.kNavy,
        foregroundColor: Colors.white,
        title          : const Text('Presensi Online'),
        // v2.1.0: kembali ke scan screen, bukan ke pilihan mode
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/scan'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.kGold.withOpacity(0.4)),
        ),
      ),
      body: _kodeOk ? _buildScanView() : _buildKodeInputView(),
    );
  }

  // ══════════════════════════════════════════════════════════
  // VIEW 1: INPUT KODE
  // ══════════════════════════════════════════════════════════

  Widget _buildKodeInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── v2.1.0: Header konteks sesi (jika ada) ────────
          if (widget.sesiAktif != null && widget.sesiAktif!.isFound)
            _buildSesiContextCard(),

          const SizedBox(height: 28),

          // ── Ikon kunci ────────────────────────────────────
          Center(
            child: Container(
              width     : 72,
              height    : 72,
              decoration: BoxDecoration(
                color       : AppColors.kNavy.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border      : Border.all(
                  color: AppColors.kGold.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                size : 36,
                color: AppColors.kGold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Judul ─────────────────────────────────────────
          Text(
            'Masukkan Kode Sesi',
            textAlign: TextAlign.center,
            style    : AppTypography.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),

          // ── v2.1.0: Instruksi share kode dari dosen ───────
          _buildShareInstruction(),

          const SizedBox(height: 32),

          // ── Pin input ─────────────────────────────────────
          PinCodeTextField(
            appContext     : context,
            length         : 6,
            obscureText    : false,
            textStyle      : AppTypography.kodeSmall.copyWith(
              color   : Colors.white,
              fontSize: 22,
            ),
            pinTheme: PinTheme(
              shape            : PinCodeFieldShape.box,
              borderRadius     : BorderRadius.circular(10),
              fieldHeight      : 56,
              fieldWidth       : 46,
              activeFillColor  : AppColors.kNavy,
              selectedFillColor: AppColors.kNavy.withOpacity(0.5),
              inactiveFillColor: Colors.white.withOpacity(0.07),
              activeColor      : AppColors.kGold,
              selectedColor    : AppColors.kGold,
              inactiveColor    : Colors.white24,
            ),
            enableActiveFill  : true,
            keyboardType      : TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            animationType     : AnimationType.fade,
            onChanged: (val) => setState(() {
              _kode    = val.toUpperCase();
              _isValid = val.length == 6;
            }),
            onCompleted: (val) => setState(() {
              _kode    = val.toUpperCase();
              _isValid = true;
            }),
          ),
          const SizedBox(height: 6),

          if (_kode.isNotEmpty)
            Text(
              'Kode: ${_kode.toUpperCase()}',
              textAlign: TextAlign.center,
              style    : AppTypography.label.copyWith(color: Colors.white38),
            ),

          const SizedBox(height: 28),

          // ── Tombol verifikasi ─────────────────────────────
          SizedBox(
            height: 54,
            child : ElevatedButton.icon(
              onPressed: (_isValid && !_isValidating) ? _validasiKode : null,
              icon : _isValidating
                  ? const SizedBox(
                      width : 20,
                      height: 20,
                      child : CircularProgressIndicator(
                          color: AppColors.kNavyDark, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                _isValidating ? 'Memvalidasi...' : 'Verifikasi Kode',
                style: AppTypography.button.copyWith(
                    color: AppColors.kNavyDark),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValid
                    ? AppColors.kGold
                    : Colors.grey.shade700,
                foregroundColor: AppColors.kNavyDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Cara mendapatkan kode ─────────────────────────
          _buildHowToGetCode(),
        ],
      ),
    );
  }

  // ── v2.1.0: Kartu konteks sesi (nama MK, kelas, dosen) ───

  Widget _buildSesiContextCard() {
    final sesi = widget.sesiAktif!;
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : AppColors.kNavy.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(
          color: AppColors.kGold.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding   : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color       : AppColors.kGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.laptop_outlined,
              color: AppColors.kGold,
              size : 22,
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                // Badge kelas + mode
                Wrap(
                  spacing: 6,
                  children: [
                    if (sesi.kodeKelas != null)
                      KelasBadge(kodeKelas: sesi.kodeKelas!),
                    const ModeBadge(mode: 'online'),
                    if (sesi.pertemuanKe != null)
                      _SmallChip(
                        label: 'Pertemuan ${sesi.pertemuanKe}',
                        color: Colors.white30,
                      ),
                  ],
                ),
                if (sesi.dosenNama != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    sesi.dosenNama!,
                    style  : AppTypography.caption.copyWith(
                      color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── v2.1.0: Instruksi share kode dari dosen ───────────────

  Widget _buildShareInstruction() {
    return Container(
      padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.kGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.kGold, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.kGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Masukkan kode 6 karakter yang dibagikan dosen '
              'via WhatsApp grup atau chat Zoom.',
              style: AppTypography.body2.copyWith(
                color : Colors.white60,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Petunjuk cara mendapatkan kode ───────────────────────

  Widget _buildHowToGetCode() {
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(
                'Cara mendapatkan kode:',
                style: AppTypography.label.copyWith(
                  color     : Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HowToStep(
            step : '1',
            text : 'Lihat kode yang dibagikan dosen di grup WhatsApp atau chat Zoom',
          ),
          const SizedBox(height: 6),
          _HowToStep(
            step : '2',
            text : 'Masukkan 6 karakter kode tersebut di atas',
          ),
          const SizedBox(height: 6),
          _HowToStep(
            step : '3',
            text : 'Kode hanya berlaku untuk 1× presensi per mahasiswa',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // VIEW 2: SCAN WAJAH (setelah kode valid)
  // ══════════════════════════════════════════════════════════

  Widget _buildScanView() {
    return Column(
      children: [
        // ── v2.1.0: Banner kode valid + info kelas lengkap ──
        _buildValidBanner(),

        // ── Camera ────────────────────────────────────────
        Expanded(child: _buildCameraArea()),

        // ── Tombol ───────────────────────────────────────
        _buildScanActions(),
      ],
    );
  }

  // ── Banner kode valid — tampilkan info kelas dari server ──

  Widget _buildValidBanner() {
    final mkNama    = _effectiveMkNama;
    final kodeKelas = _effectiveKodeKelas;
    final pertemuan = _effectivePertemuan;
    final dosenNama = _effectiveDosenNama;

    return Container(
      color  : AppColors.kSuccess.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child  : Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: kode valid + nama MK
                Wrap(
                  spacing  : 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children : [
                    Text(
                      'Kode ${_kode.toUpperCase()} valid!',
                      style: AppTypography.bodyBold.copyWith(
                        color   : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    if (mkNama.isNotEmpty)
                      Text(
                        '· $mkNama',
                        style: AppTypography.body2.copyWith(
                          color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Baris 2: badge kelas + pertemuan + dosen
                Wrap(
                  spacing : 6,
                  children: [
                    if (kodeKelas != null)
                      KelasBadge(
                        kodeKelas: kodeKelas,
                        fontSize : 9,
                        padding  : const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                      ),
                    if (pertemuan != null)
                      _SmallChip(
                        label: 'Pertemuan $pertemuan',
                        color: Colors.white30,
                      ),
                    if (dosenNama != null)
                      Text(
                        dosenNama,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white70),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera area + oval overlay UMS ───────────────────────

  Widget _buildCameraArea() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        _isCameraReady && _cameraController != null
            ? SizedBox.expand(child: CameraPreview(_cameraController!))
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Memuat kamera...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

        // v2.1.0: Overlay oval UMS (dipakai ulang dari ScanScreen)
        CustomPaint(
          size   : Size.infinite,
          painter: UMSOvalOverlayPainter(faceDetected: _faceDetected),
        ),

        // Badge deteksi wajah
        Positioned(
          top: 16,
          child: AnimatedContainer(
            duration  : const Duration(milliseconds: 300),
            padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: (_faceDetected ? AppColors.kSuccess : AppColors.kDanger)
                  .withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color     : Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _faceDetected
                      ? Icons.face_rounded
                      : Icons.face_retouching_off_rounded,
                  color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(
                  _faceDetected ? 'Siap Scan' : 'Arahkan Wajah',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Overlay scanning
        if (_isScanning)
          Container(
            color: Colors.black.withOpacity(0.72),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 14),
                  Text(
                    'Memverifikasi wajah...',
                    style: AppTypography.bodyBold.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Tombol scan ───────────────────────────────────────────

  Widget _buildScanActions() {
    return Container(
      color  : const Color(0xFF111827),
      padding: EdgeInsets.fromLTRB(
        20, 14, 20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // v2.1.0: Ganti kode — kembali ke input, bukan pilih mode
          TextButton.icon(
            onPressed: _resetKode,
            icon : const Icon(Icons.edit_outlined,
                size: 15, color: Colors.white38),
            label: Text(
              'Ganti kode sesi',
              style: AppTypography.caption.copyWith(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 54,
            child : ElevatedButton.icon(
              onPressed: (_isScanning || !_faceDetected) ? null : _scanWajah,
              icon : _isScanning
                  ? const SizedBox(
                      width : 20, height: 20,
                      child : CircularProgressIndicator(
                          color: AppColors.kNavyDark, strokeWidth: 2),
                    )
                  : const Icon(Icons.face_unlock_rounded, size: 22),
              label: Text(
                _isScanning ? 'Memverifikasi...' : 'Scan Wajah & Presensi',
                style: AppTypography.button.copyWith(
                    color: AppColors.kNavyDark),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _faceDetected
                    ? AppColors.kGold
                    : Colors.grey.shade700,
                foregroundColor: AppColors.kNavyDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KOMPONEN PENDUKUNG
// ══════════════════════════════════════════════════════════════

/// Chip kecil untuk label tambahan (pertemuan ke-X, dll.)
class _SmallChip extends StatelessWidget {
  final String label;
  final Color  color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(
          color   : Colors.white54,
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Langkah cara mendapatkan kode
class _HowToStep extends StatelessWidget {
  final String step;
  final String text;

  const _HowToStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width : 18,
          height: 18,
          decoration: BoxDecoration(
            color       : AppColors.kNavy.withOpacity(0.5),
            shape       : BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Center(
            child: Text(
              step,
              style: AppTypography.badge.copyWith(
                color   : Colors.white60,
                fontSize: 9,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color : Colors.white38,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}