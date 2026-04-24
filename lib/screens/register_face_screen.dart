import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'dart:typed_data';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  // ── Camera ────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;

  // ── ML Kit Face Detector ──────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );
  bool _faceDetected = false;
  bool _isProcessingFrame = false;

  // ── State ─────────────────────────────────────────────────
  int    _totalTerdaftar = 0;
  bool   _isUploading    = false;
  bool   _isComplete     = false;
  String _statusPesan    = 'Posisikan wajah di dalam lingkaran';
  String _instruksi      = 'Pastikan wajah terlihat jelas dan pencahayaan cukup';

  final List<Map<String, String>> _instruksiList = [
    {'posisi': 'Lurus',             'hint': 'Hadapkan wajah langsung ke kamera'},
    {'posisi': 'Kiri 30°',          'hint': 'Putar kepala sedikit ke kiri'},
    {'posisi': 'Kanan 30°',         'hint': 'Putar kepala sedikit ke kanan'},
    {'posisi': 'Atas',              'hint': 'Angkat sedikit dagumu ke atas'},
    {'posisi': 'Bawah',             'hint': 'Turunkan sedikit dagumu ke bawah'},
    {'posisi': 'Lurus + Senyum',    'hint': 'Tersenyum menghadap kamera'},
    {'posisi': 'Pencahayaan Kiri',  'hint': 'Cari cahaya dari sisi kiri wajah'},
    {'posisi': 'Pencahayaan Kanan', 'hint': 'Cari cahaya dari sisi kanan wajah'},
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

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
        enableAudio: false,
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
        print("Faces detected: ${faces.length}");
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
          ) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // 🔥 gabungkan semua plane bytes
      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>(
          [],
          (allBytes, plane) => allBytes..addAll(plane.bytes),
        ),
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('InputImage error: $e');
      return null;
    }
  }

  Future<void> _ambilFoto() async {
    if (_isUploading || _cameraController == null || !_isCameraReady) return;
    if (!_faceDetected) {
      _showSnack('Wajah belum terdeteksi', isError: true);
      return;
    }

    setState(() { _isUploading = true; _statusPesan = 'Memproses foto...'; });

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
        final isComplete = data['is_complete'] as bool;

        setState(() {
          _totalTerdaftar = total;
          _isComplete     = isComplete;
          if (isComplete) {
            _statusPesan = '✅ Registrasi selesai! Mengarahkan ke scan...';
          } else {
            final idx  = total < _instruksiList.length ? total : _instruksiList.length - 1;
            _instruksi   = _instruksiList[idx]['hint']!;
            _statusPesan = 'Foto ke-$total berhasil. ${8 - total} foto lagi.';
          }
        });

        if (isComplete) {
          if (mounted) context.read<AuthProvider>().updateFaceRegistered(true);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/scan');
          return;
        }
        _showSnack('Foto ke-$total berhasil disimpan!');
      } else {
        final body  = jsonDecode(response.body) as Map<String, dynamic>;
        _showSnack((body['detail'] ?? 'Upload gagal').toString(), isError: true);
        setState(() => _statusPesan = 'Foto gagal, coba lagi');
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
      setState(() => _statusPesan = 'Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _startFaceDetection();
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
      duration        : const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx    = _totalTerdaftar < _instruksiList.length ? _totalTerdaftar : _instruksiList.length - 1;
    final posisi = _instruksiList[idx]['posisi']!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Registrasi Wajah'),
        elevation      : 0,
      ),
      body: Column(
        children: [
          // ── Progress header ───────────────────────────────
          Container(
            color  : const Color(0xFF1E3A5F),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child  : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_totalTerdaftar / 8 foto',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color        : Colors.white.withOpacity(0.15),
                        borderRadius : BorderRadius.circular(20),
                      ),
                      child: Text(
                        posisi,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value          : _totalTerdaftar / 8,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor     : const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    minHeight      : 10,
                  ),
                ),
              ],
            ),
          ),

          // ── Camera + overlay ──────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _isCameraReady && _cameraController != null
                    ? SizedBox.expand(child: CameraPreview(_cameraController!))
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Memuat kamera...', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),

                CustomPaint(
                  size   : Size.infinite,
                  painter: FaceOverlayPainter(faceDetected: _faceDetected),
                ),

                // Badge deteksi
                Positioned(
                  top  : 16,
                  child: AnimatedContainer(
                    duration  : const Duration(milliseconds: 300),
                    padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color        : (_faceDetected ? Colors.green : Colors.red).withOpacity(0.85),
                      borderRadius : BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _faceDetected ? Icons.face_rounded : Icons.face_retouching_off,
                          color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _faceDetected ? 'Wajah Terdeteksi' : 'Wajah Tidak Terdeteksi',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // Instruksi
                Positioned(
                  bottom: 16, left: 20, right: 20,
                  child: Container(
                    padding   : const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color        : Colors.black.withOpacity(0.65),
                      borderRadius : BorderRadius.circular(12),
                    ),
                    child: Text(
                      _instruksi,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tombol & status ───────────────────────────────
          Container(
            color  : const Color(0xFF111827),
            padding: const EdgeInsets.all(20),
            child  : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _statusPesan,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color   : _isComplete ? Colors.greenAccent : Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
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
                              color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _isUploading
                          ? 'Memproses...'
                          : !_faceDetected
                              ? 'Arahkan wajah ke kamera'
                              : 'Ambil Foto ${_totalTerdaftar + 1} dari 8',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _faceDetected && !_isUploading
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable face overlay painter ────────────────────────────

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
    canvas.drawPath(bgPath, Paint()..color = Colors.black.withOpacity(0.45));

    // Border oval
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color       = faceDetected ? Colors.greenAccent : Colors.redAccent
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(FaceOverlayPainter old) => old.faceDetected != faceDetected;
}