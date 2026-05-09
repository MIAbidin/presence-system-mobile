// lib/screens/register_face_screen.dart
// v2.1.0 — Fase 4.2:
//   - Fetch GET /face/status → max_foto dinamis dari konfigurasi sistem
//   - Progress text dinamis: "Foto ke-3 dari 8 berhasil"
//   - Tombol "Cek Diagnosa Wajah" (POST /face/diagnose)
//   - Navigasi ke /home setelah selesai registrasi

import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'dart:typed_data';

// ─── Model face status ────────────────────────────────────────

class _FaceStatusModel {
  final int  totalFoto;
  final int  maxFoto;
  final bool isComplete;

  const _FaceStatusModel({
    required this.totalFoto,
    required this.maxFoto,
    required this.isComplete,
  });

  factory _FaceStatusModel.fromJson(Map<String, dynamic> json) =>
      _FaceStatusModel(
        totalFoto : json['total_foto']   as int?  ?? 0,
        maxFoto   : json['max_foto']     as int?  ?? 8,
        isComplete: json['is_complete']  as bool? ?? false,
      );
}

// ─── Model diagnosa wajah ─────────────────────────────────────

class _DiagnosaModel {
  final int     totalEmbedding;
  final double? jarakRataRata;
  final double? jarakTerkecil;
  final double? jarakTerbesar;
  final double? threshold;
  final String? pesan;
  final bool?   konsisten;

  const _DiagnosaModel({
    required this.totalEmbedding,
    this.jarakRataRata,
    this.jarakTerkecil,
    this.jarakTerbesar,
    this.threshold,
    this.pesan,
    this.konsisten,
  });

  factory _DiagnosaModel.fromJson(Map<String, dynamic> json) =>
      _DiagnosaModel(
        totalEmbedding: json['total_embedding'] as int?    ?? 0,
        jarakRataRata : (json['jarak_rata_rata'] as num?)?.toDouble(),
        jarakTerkecil : (json['jarak_terkecil']  as num?)?.toDouble(),
        jarakTerbesar : (json['jarak_terbesar']  as num?)?.toDouble(),
        threshold     : (json['threshold']        as num?)?.toDouble(),
        pesan         : json['pesan']             as String?,
        konsisten     : json['konsisten']         as bool?,
      );
}

// ─── RegisterFaceScreen ───────────────────────────────────────

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen>
    with SingleTickerProviderStateMixin {
  // ── Camera ────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;

  // ── ML Kit Face Detector ──────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode  : FaceDetectorMode.accurate,
      enableContours   : true,
      enableClassification: true,
      minFaceSize      : 0.15,
    ),
  );
  bool _faceDetected      = false;
  bool _isProcessingFrame = false;

  // ── State utama ───────────────────────────────────────────
  int    _totalTerdaftar = 0;
  int    _maxFoto        = 8;   // Default — akan di-override dari /face/status
  bool   _isUploading    = false;
  bool   _isComplete     = false;
  bool   _isLoadingStatus= true;
  String _statusPesan    = 'Memuat status registrasi...';
  // Diinisialisasi dari _instruksiList[0] di initState setelah list siap
  String _instruksi      = '';

  // ── Animasi sukses ────────────────────────────────────────
  late AnimationController _successAnim;
  bool _showSuccess = false;

  // ── Instruksi per foto ────────────────────────────────────
  final List<Map<String, String>> _instruksiList = [
    {'posisi': 'Lurus',             'hint': 'Hadapkan wajah langsung ke kamera'},
    {'posisi': 'Kiri 30°',          'hint': 'Putar kepala sedikit ke kiri'},
    {'posisi': 'Kanan 30°',         'hint': 'Putar kepala sedikit ke kanan'},
    {'posisi': 'Atas',              'hint': 'Angkat sedikit dagumu ke atas'},
    {'posisi': 'Bawah',             'hint': 'Turunkan sedikit dagumu ke bawah'},
    {'posisi': 'Lurus + Senyum',    'hint': 'Tersenyum menghadap kamera'},
    {'posisi': 'Pencahayaan Kiri',  'hint': 'Cari cahaya dari sisi kiri wajah'},
    {'posisi': 'Pencahayaan Kanan', 'hint': 'Cari cahaya dari sisi kanan wajah'},
    // Slot tambahan jika max_foto > 8
    {'posisi': 'Ekspresi Netral',   'hint': 'Wajah santai, tatap kamera'},
    {'posisi': 'Lurus + Kacamata',  'hint': 'Jika pakai kacamata, gunakan sekarang'},
    {'posisi': 'Cahaya Depan',      'hint': 'Pastikan cahaya menerangi wajah dari depan'},
    {'posisi': 'Profil Kiri',       'hint': 'Putar kepala 45° ke kiri'},
    {'posisi': 'Profil Kanan',      'hint': 'Putar kepala 45° ke kanan'},
    {'posisi': 'Dagu Turun',        'hint': 'Turunkan dagu agak lebih rendah'},
    {'posisi': 'Dagu Naik',         'hint': 'Angkat dagu agak lebih tinggi'},
    {'posisi': 'Cahaya Atas',       'hint': 'Hadapi sumber cahaya dari atas'},
    {'posisi': 'Ekspresi Senyum',   'hint': 'Senyum lebar menghadap kamera'},
    {'posisi': 'Posisi Akhir',      'hint': 'Foto terakhir — wajah lurus ke kamera'},
    {'posisi': 'Konfirmasi',        'hint': 'Satu foto terakhir untuk konfirmasi'},
    {'posisi': 'Final',             'hint': 'Foto final untuk melengkapi registrasi'},
  ];

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchFaceStatus();
    _initCamera();
  }

  // ── Fetch /face/status untuk max_foto dinamis ─────────────

  Future<void> _fetchFaceStatus() async {
    try {
      final response = await ApiClient().get('/face/status');
      if (response.statusCode == 200 && mounted) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final status = _FaceStatusModel.fromJson(data);
        setState(() {
          _totalTerdaftar = status.totalFoto;
          _maxFoto        = status.maxFoto;
          _isComplete     = status.isComplete;
          _isLoadingStatus= false;
          _statusPesan    = _isComplete
              ? '✅ Registrasi sudah selesai!'
              : 'Posisikan wajah di dalam lingkaran';
        });

        // Jika sudah selesai sejak awal, tampilkan animasi sukses
        if (_isComplete) _triggerSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
          _statusPesan     = 'Posisikan wajah di dalam lingkaran';
        });
      }
    }
  }

  // ── Kamera ────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio     : false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
        _startFaceDetection();
      }
    } catch (e) {
      if (mounted) setState(() => _statusPesan = 'Kamera error: $e');
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
      final camera   = _cameraController!.description;
      final rotation = InputImageRotationValue.fromRawValue(
            camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format   = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>(
          [],
          (allBytes, plane) => allBytes..addAll(plane.bytes),
        ),
      );

      return InputImage.fromBytes(
        bytes   : bytes,
        metadata: InputImageMetadata(
          size        : Size(image.width.toDouble(), image.height.toDouble()),
          rotation    : rotation,
          format      : format,
          bytesPerRow : image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // ── Ambil foto & upload ───────────────────────────────────

  Future<void> _ambilFoto() async {
    if (_isUploading || _cameraController == null || !_isCameraReady) return;
    if (!_faceDetected) {
      _showSnack('Wajah belum terdeteksi', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _statusPesan = 'Memproses foto...';
    });

    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes      = await foto.readAsBytes();

      final response = await ApiClient().postMultipart(
        '/face/register',
        fields   : {},
        fileField: 'foto',
        fileBytes: bytes,
        filename : 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (response.statusCode == 200) {
        final data       = jsonDecode(response.body) as Map<String, dynamic>;
        final total      = data['total_terdaftar'] as int;
        final isComplete = data['is_complete']     as bool;

        setState(() {
          _totalTerdaftar = total;
          _isComplete     = isComplete;

          if (isComplete) {
            _statusPesan = '✅ Registrasi selesai! $_maxFoto foto berhasil direkam.';
          } else {
            final remaining = _maxFoto - total;
            _statusPesan    = 'Foto ke-$total berhasil. $remaining foto lagi.';
            final idx       = total < _instruksiList.length
                ? total
                : _instruksiList.length - 1;
            _instruksi      = _instruksiList[idx]['hint']!;
          }
        });

        if (isComplete) {
          if (mounted) {
            context.read<AuthProvider>().updateFaceRegistered(true);
          }
          _triggerSuccess();
          return;
        }

        _showSnack('Foto ke-$total dari $_maxFoto berhasil disimpan!');
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _showSnack(
            (body['detail'] ?? 'Upload gagal').toString(), isError: true);
        setState(() => _statusPesan = 'Foto gagal, coba lagi');
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
      setState(() => _statusPesan = 'Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        if (!_isComplete) _startFaceDetection();
      }
    }
  }

  // ── Diagnosa wajah ────────────────────────────────────────

  Future<void> _cekDiagnosa() async {
    if (_totalTerdaftar == 0) {
      _showSnack('Belum ada foto yang terdaftar untuk didiagnosa.', isError: true);
      return;
    }

    // Minta user ambil foto untuk diagnosa
    if (_cameraController == null || !_isCameraReady) {
      _showSnack('Kamera belum siap.', isError: true);
      return;
    }

    if (!_faceDetected) {
      _showSnack('Arahkan wajah ke kamera untuk diagnosa.', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes      = await foto.readAsBytes();

      final response = await ApiClient().postMultipart(
        '/face/diagnose',
        fields   : {},
        fileField: 'foto',
        fileBytes: bytes,
        filename : 'diagnose_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (response.statusCode == 200 && mounted) {
        final data     = jsonDecode(response.body) as Map<String, dynamic>;
        final diagnosa = _DiagnosaModel.fromJson(data);
        _showDiagnosaDialog(diagnosa);
      } else {
        _showSnack('Diagnosa gagal. Coba lagi.', isError: true);
      }
    } catch (e) {
      _showSnack('Error diagnosa: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _startFaceDetection();
      }
    }
  }

  void _showDiagnosaDialog(_DiagnosaModel d) {
    final konsistenColor = d.konsisten == true
        ? AppColors.kStatusHadir
        : AppColors.kWarning;
    final konsistenLabel = d.konsisten == true ? 'Konsisten ✅' : 'Perlu Perbaikan ⚠️';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.biotech_outlined, color: AppColors.kNavy, size: 22),
            const SizedBox(width: 8),
            Text('Diagnosa Wajah',
                style: AppTypography.heading3.copyWith(
                    color: AppColors.kNavy, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DiagnosaRow(
              label: 'Total Embedding',
              value: '${d.totalEmbedding} foto',
            ),
            if (d.threshold != null)
              _DiagnosaRow(
                label: 'Threshold Sistem',
                value: d.threshold!.toStringAsFixed(2),
              ),
            if (d.jarakRataRata != null)
              _DiagnosaRow(
                label: 'Jarak Rata-Rata',
                value: d.jarakRataRata!.toStringAsFixed(3),
              ),
            if (d.jarakTerkecil != null)
              _DiagnosaRow(
                label: 'Jarak Terkecil',
                value: d.jarakTerkecil!.toStringAsFixed(3),
                highlight: true,
              ),
            if (d.jarakTerbesar != null)
              _DiagnosaRow(
                label: 'Jarak Terbesar',
                value: d.jarakTerbesar!.toStringAsFixed(3),
              ),
            if (d.konsisten != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Container(
                    padding   : const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color       : konsistenColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: konsistenColor.withOpacity(0.4)),
                    ),
                    child: Text(konsistenLabel,
                        style: AppTypography.badge.copyWith(
                            color: konsistenColor, fontSize: 12)),
                  ),
                ],
              ),
            ],
            if (d.pesan != null) ...[
              const SizedBox(height: 10),
              Text(d.pesan!,
                  style: AppTypography.caption.copyWith(
                      color: AppColors.kTextSecondary)),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style    : ElevatedButton.styleFrom(
              backgroundColor: AppColors.kNavy,
              foregroundColor: Colors.white,
              minimumSize    : const Size(0, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── Animasi sukses + navigasi ke /home ────────────────────

  Future<void> _triggerSuccess() async {
    if (!mounted) return;
    setState(() => _showSuccess = true);
    _successAnim.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) context.go('/home');
  }

  // ── Snackbar ──────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError
          ? AppColors.kStatusAbsen
          : AppColors.kStatusHadir,
      behavior       : SnackBarBehavior.floating,
      duration       : const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _successAnim.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final idx    = _totalTerdaftar < _instruksiList.length
        ? _totalTerdaftar
        : _instruksiList.length - 1;
    final posisi = _instruksiList[idx]['posisi']!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.kNavy,
        foregroundColor: Colors.white,
        title          : const Text('Registrasi Wajah'),
        elevation      : 0,
        bottom         : PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
              height: 2, color: AppColors.kGold.withOpacity(0.5)),
        ),
        actions: [
          // Tombol diagnosa — hanya tampil jika sudah ada foto
          if (_totalTerdaftar > 0)
            IconButton(
              icon     : const Icon(Icons.biotech_outlined),
              tooltip  : 'Cek Diagnosa Wajah',
              onPressed: _isUploading ? null : _cekDiagnosa,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Progress header ──────────────────────────
              _buildProgressHeader(posisi),

              // ── Camera + overlay ─────────────────────────
              Expanded(child: _buildCameraArea()),

              // ── Tombol & status ──────────────────────────
              _buildBottomControls(),
            ],
          ),

          // ── Overlay sukses ───────────────────────────────
          if (_showSuccess) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(String posisi) {
    return Container(
      color  : AppColors.kNavy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child  : Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dinamis: "3 / 8 foto" sesuai max dari server
              Text(
                _isLoadingStatus
                    ? 'Memuat...'
                    : '$_totalTerdaftar / $_maxFoto foto',
                style: const TextStyle(
                  color     : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize  : 15,
                ),
              ),
              Container(
                padding   : const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color       : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(posisi,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar dinamis berdasarkan max_foto dari server
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value          : _maxFoto > 0
                  ? (_totalTerdaftar / _maxFoto).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor     : const AlwaysStoppedAnimation<Color>(
                  Colors.greenAccent),
              minHeight      : 10,
            ),
          ),
          const SizedBox(height: 6),
          // Hint jumlah tersisa
          if (!_isLoadingStatus && !_isComplete)
            Text(
              '${(_maxFoto - _totalTerdaftar).clamp(0, _maxFoto)} foto lagi untuk menyelesaikan registrasi',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Kamera
        _isCameraReady && _cameraController != null
            ? SizedBox.expand(
                child: CameraPreview(_cameraController!))
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Memuat kamera...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

        // Overlay oval UMS
        CustomPaint(
          size   : Size.infinite,
          painter: FaceOverlayPainter(faceDetected: _faceDetected),
        ),

        // Badge deteksi wajah
        Positioned(
          top  : 16,
          child: AnimatedContainer(
            duration  : const Duration(milliseconds: 300),
            padding   : const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: (_faceDetected ? AppColors.kStatusHadir : AppColors.kStatusAbsen)
                  .withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _faceDetected
                      ? Icons.face_rounded
                      : Icons.face_retouching_off,
                  color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  _faceDetected
                      ? 'Wajah Terdeteksi'
                      : 'Wajah Tidak Terdeteksi',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),

        // Instruksi bawah kamera
        Positioned(
          bottom: 16, left: 20, right: 20,
          child : Container(
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _instruksi,
              textAlign: TextAlign.center,
              style     : const TextStyle(
                  color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color  : const Color(0xFF111827),
      padding: const EdgeInsets.all(20),
      child  : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status pesan — dinamis
          Text(
            _statusPesan,
            textAlign: TextAlign.center,
            style: TextStyle(
              color   : _isComplete
                  ? Colors.greenAccent
                  : Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          // Tombol ambil foto
          SizedBox(
            height: 52,
            child : ElevatedButton.icon(
              onPressed: (_isUploading || !_faceDetected || _isComplete)
                  ? null
                  : _ambilFoto,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt_rounded),
              label: Text(
                _isUploading
                    ? 'Memproses...'
                    : _isComplete
                        ? 'Registrasi Selesai ✅'
                        : !_faceDetected
                            ? 'Arahkan wajah ke kamera'
                            : 'Ambil Foto ${_totalTerdaftar + 1} dari $_maxFoto',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _faceDetected && !_isUploading && !_isComplete
                    ? AppColors.kNavy
                    : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Tombol diagnosa (tampil jika sudah ada minimal 1 foto & belum upload)
          if (_totalTerdaftar > 0 && !_isUploading) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child : OutlinedButton.icon(
                onPressed: _cekDiagnosa,
                icon : const Icon(Icons.biotech_outlined, size: 18),
                label: const Text('Cek Diagnosa Wajah',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.3), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Overlay sukses ────────────────────────────────────────

  Widget _buildSuccessOverlay() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder  : (context, child) {
        return Opacity(
          opacity: _successAnim.value.clamp(0.0, 1.0),
          child  : Container(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  // Icon animasi
                  TweenAnimationBuilder<double>(
                    tween   : Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve   : Curves.elasticOut,
                    builder : (_, scale, __) => Transform.scale(
                      scale: scale,
                      child: Container(
                        width     : 100,
                        height    : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.kStatusHadir.withOpacity(0.2),
                          border: Border.all(
                              color: AppColors.kStatusHadir, width: 3),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.greenAccent,
                          size : 56,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Registrasi Wajah Selesai!',
                    style: AppTypography.hero.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_maxFoto foto wajah berhasil direkam.\nMenuju beranda...',
                    style    : AppTypography.heroSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Progress indicator kecil
                  SizedBox(
                    width : 160,
                    child : ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor     : const AlwaysStoppedAnimation<Color>(
                            Colors.greenAccent),
                        minHeight      : 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Widget diagnosa row ───────────────────────────────────────

class _DiagnosaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   highlight;

  const _DiagnosaRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child  : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.label),
          Text(
            value,
            style: AppTypography.bodyBold.copyWith(
              color   : highlight ? AppColors.kNavy : AppColors.kTextPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Face overlay painter ──────────────────────────────────────

class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  const FaceOverlayPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.width * 0.38;

    // Background gelap di luar oval
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
        bgPath, Paint()..color = Colors.black.withOpacity(0.45));

    // Border oval — navy saat tidak terdeteksi, gold/green saat terdeteksi
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color       = faceDetected
            ? Colors.greenAccent
            : AppColors.kGold.withOpacity(0.8)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Titik sudut dekoratif (4 sudut oval)
    if (faceDetected) {
      final dotPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.fill;
      final positions = [
        Offset(center.dx, center.dy - radius),         // atas
        Offset(center.dx, center.dy + radius),         // bawah
        Offset(center.dx - radius, center.dy),         // kiri
        Offset(center.dx + radius, center.dy),         // kanan
      ];
      for (final pos in positions) {
        canvas.drawCircle(pos, 5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter old) =>
      old.faceDetected != faceDetected;
}