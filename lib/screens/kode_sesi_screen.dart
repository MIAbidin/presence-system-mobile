import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/screens/register_face_screen.dart'; // FaceOverlayPainter

class KodeSesiScreen extends StatefulWidget {
  final String? sesiId;
  const KodeSesiScreen({super.key, this.sesiId});

  @override
  State<KodeSesiScreen> createState() => _KodeSesiScreenState();
}

class _KodeSesiScreenState extends State<KodeSesiScreen> {
  String _kode    = '';
  bool   _isValid = false;

  bool   _isValidating = false;
  bool   _kodeOk       = false;
  Map<String, dynamic>? _infoSesi;

  CameraController?       _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady     = false;
  bool _faceDetected      = false;
  bool _isProcessingFrame = false;
  bool _isScanning        = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(minFaceSize: 0.25),
  );

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ── Validasi kode ke server ───────────────────────────────
  Future<void> _validasiKode() async {
    if (_kode.length != 6) return;
    setState(() => _isValidating = true);

    try {
      // Pakai getRaw agar bisa handle response error sendiri
      final response = await ApiClient().getRaw(
        '/sesi/cek-kode?kode=${_kode.toUpperCase()}',
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final sesiRaw = body['sesi'];
        setState(() {
          _kodeOk   = true;
          _infoSesi = sesiRaw is Map
              ? Map<String, dynamic>.from(sesiRaw)
              : null;
        });
        final mkNama = _infoSesi?['matakuliah'] as String? ?? '';
        _showSnack('Kode valid! ${mkNama.isNotEmpty ? "($mkNama) " : ""}Sekarang scan wajah.');
        await _initCamera();
      } else {
        // FIX: detail FastAPI bisa String atau List<Map>
        _showSnack(_extractDetail(body['detail']), isError: true);
      }
    } catch (e) {
      _showSnack('Gagal memvalidasi kode: $e', isError: true);
    } finally {
      setState(() => _isValidating = false);
    }
  }

  // ── Init kamera ───────────────────────────────────────────
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
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
          ?? InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>([], (all, plane) => all..addAll(plane.bytes)),
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

  // ── Scan wajah & kirim presensi ───────────────────────────
  // Tidak perlu sesi_id sama sekali!
 
  Future<void> _scanWajah() async {
    if (_isScanning || !_faceDetected || _cameraController == null) return;
    setState(() => _isScanning = true);
 
    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes      = await foto.readAsBytes();
 
      // ✅ Pakai /presensi/simple — tidak perlu sesi_id
      final response = await ApiClient().postMultipart(
        '/presensi/simple',
        fields   : {
          'kode_sesi': _kode.toUpperCase(),
          // latitude & longitude tidak perlu untuk online
        },
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

  /// Safely extract detail string from FastAPI response (bisa String atau List)
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
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
    ));
  }

  void _resetKode() {
    _cameraController?.dispose();
    setState(() {
      _kodeOk           = false;
      _kode             = '';
      _isValid          = false;
      _infoSesi         = null;
      _cameraController = null;
      _isCameraReady    = false;
      _faceDetected     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Presensi Online'),
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scan'),
        ),
      ),
      body: _kodeOk ? _buildScanView() : _buildKodeInputView(),
    );
  }

  // ── View 1: Input kode sesi (tanpa Session ID input) ──────
  Widget _buildKodeInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child  : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          Container(
            width : 80, height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 120),
            decoration: BoxDecoration(
              color        : const Color(0xFF1E3A5F).withOpacity(0.15),
              borderRadius : BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_open_rounded, size: 44, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 24),

          const Text(
            'Masukkan Kode Sesi',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masukkan kode 6 karakter yang diberikan dosen di platform meeting',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 36),

          PinCodeTextField(
            appContext     : context,
            length         : 6,
            obscureText    : false,
            textStyle      : const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            pinTheme: PinTheme(
              shape            : PinCodeFieldShape.box,
              borderRadius     : BorderRadius.circular(10),
              fieldHeight      : 56,
              fieldWidth       : 46,
              activeFillColor  : const Color(0xFF1E3A5F),
              selectedFillColor: const Color(0xFF1E3A5F).withOpacity(0.5),
              inactiveFillColor: Colors.white.withOpacity(0.07),
              activeColor      : Colors.blueAccent,
              selectedColor    : Colors.blueAccent,
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
          const SizedBox(height: 8),

          if (_kode.isNotEmpty)
            Text(
              'Kode: ${_kode.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),

          const SizedBox(height: 28),

          SizedBox(
            height: 54,
            child : ElevatedButton.icon(
              onPressed: (_isValid && !_isValidating) ? _validasiKode : null,
              icon : _isValidating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isValidating ? 'Memvalidasi...' : 'Verifikasi Kode',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValid ? const Color(0xFF1E3A5F) : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding   : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color        : Colors.white.withOpacity(0.05),
              borderRadius : BorderRadius.circular(12),
              border       : Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡 Cara mendapatkan kode:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('1. Lihat kode yang ditampilkan dosen di Zoom/Meet/WhatsApp',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
                SizedBox(height: 4),
                Text('2. Masukkan 6 karakter kode tersebut di atas',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
                SizedBox(height: 4),
                Text('3. Kode hanya berlaku untuk 1x presensi per mahasiswa',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View 2: Scan wajah setelah kode valid ─────────────────
  Widget _buildScanView() {
    final mkNama    = _infoSesi?['matakuliah']  as String? ?? '';
    final pertemuan = _infoSesi?['pertemuan_ke'];

    return Column(
      children: [
        // Banner kode valid
        Container(
          color  : Colors.green.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child  : Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kode ${_kode.toUpperCase()} valid!'
                  '${mkNama.isNotEmpty ? " · $mkNama" : ""}'
                  '${pertemuan != null ? " · Pertemuan $pertemuan" : ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Camera
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

              Positioned(
                top: 16,
                child: AnimatedContainer(
                  duration  : const Duration(milliseconds: 300),
                  padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color       : (_faceDetected ? Colors.green : Colors.red).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _faceDetected ? Icons.face_rounded : Icons.face_retouching_off,
                        color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _faceDetected ? 'Siap Scan' : 'Arahkan Wajah',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isScanning)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('Memverifikasi wajah...',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Tombol
        Container(
          color  : const Color(0xFF111827),
          padding: const EdgeInsets.all(20),
          child  : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: _resetKode,
                icon : const Icon(Icons.edit, size: 16, color: Colors.white54),
                label: const Text('Ganti kode',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child : ElevatedButton.icon(
                  onPressed: (_isScanning || !_faceDetected) ? null : _scanWajah,
                  icon : _isScanning
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.face_unlock_rounded, size: 24),
                  label: Text(
                    _isScanning ? 'Memverifikasi...' : 'Scan Wajah & Presensi',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _faceDetected ? const Color(0xFF1E3A5F) : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}