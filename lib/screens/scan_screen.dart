// lib/screens/scan_screen.dart
// FIX: imageFormatGroup → yuv420 (wajib untuk ML Kit di Android)
// FIX: _buildInputImage gabungkan semua plane bytes seperti register_face_screen

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/providers/auth_provider.dart';
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
  bool _isCameraReady  = false;

  // ── Face detection ────────────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(minFaceSize: 0.15), // lebih sensitif
  );
  bool _faceDetected      = false;
  bool _isProcessingFrame = false;

  // ── State ─────────────────────────────────────────────────
  bool   _isVerifying = false;
  String _mode        = 'offline';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
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
    }
  }

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
        // ✅ FIX: yuv420 wajib agar ML Kit bisa proses di Android
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
          ) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // ✅ FIX: gabungkan SEMUA plane bytes (sama seperti register_face_screen)
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
      debugPrint('InputImage error: $e');
      return null;
    }
  }

  // ── Ambil GPS ─────────────────────────────────────────────
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

  // ── Proses verifikasi wajah & presensi ────────────────────
  Future<void> _verifikasiWajahOffline() async {
    if (_isVerifying || _cameraController == null || !_isCameraReady) return;
    if (!_faceDetected) {
      _showSnack('Wajah belum terdeteksi', isError: true);
      return;
    }
 
    setState(() => _isVerifying = true);
 
    try {
      await _cameraController!.stopImageStream();
      final XFile foto = await _cameraController!.takePicture();
      final bytes      = await foto.readAsBytes();
 
      // Ambil GPS
      final pos = await _getGps();
      if (pos == null) {
        setState(() => _isVerifying = false);
        _startFaceDetection();
        return;
      }
 
      // ✅ Pakai /presensi/simple — tidak perlu sesi_id
      final response = await ApiClient().postMultipart(
        '/presensi/simple',
        fields: {
          'latitude' : pos.latitude.toString(),
          'longitude': pos.longitude.toString(),
          // kode_sesi tidak diisi → backend tahu ini offline
        },
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

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
    ));
  }

  void _showPresensiDialog() {
    showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color       : Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih Mode Presensi',
              style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Sistem otomatis mencari sesi yang sedang aktif',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
 
            // ── Tombol Offline ────────────────────────────
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _verifikasiWajahOffline();
              },
              icon : const Icon(Icons.location_on_rounded, size: 22),
              label: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tatap Muka (Offline)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Validasi GPS lokasi kelas',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding        : const EdgeInsets.fromLTRB(16, 14, 16, 14),
                alignment      : Alignment.centerLeft,
                shape          : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
 
            // ── Tombol Online ─────────────────────────────
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/kode-sesi');
              },
              icon : const Icon(Icons.video_call_rounded, size: 22),
              label: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Daring (Online)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Masukkan kode sesi dari dosen',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding        : const EdgeInsets.fromLTRB(16, 14, 16, 14),
                alignment      : Alignment.centerLeft,
                shape          : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      // ✅ FIX: resizeToAvoidBottomInset = false cegah overflow
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Presensi Wajah'),
      ),
      body: Column(
        children: [
          // ── Info user ─────────────────────────────────────
          Container(
            color  : const Color(0xFF1E3A5F),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child  : Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  radius         : 20,
                  child          : const Icon(Icons.person, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.namaLengkap ?? 'Mahasiswa',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        user?.nimNidn ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color        : Colors.white.withOpacity(0.15),
                    borderRadius : BorderRadius.circular(20),
                  ),
                  child: Text(
                    _mode == 'offline' ? '📍 Offline' : '💻 Online',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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

                CustomPaint(
                  size   : Size.infinite,
                  painter: FaceOverlayPainter(faceDetected: _faceDetected),
                ),

                // Badge deteksi wajah
                Positioned(
                  top: 16,
                  child: AnimatedContainer(
                    duration  : const Duration(milliseconds: 300),
                    padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color        : (_faceDetected ? Colors.green : Colors.red)
                          .withOpacity(0.85),
                      borderRadius : BorderRadius.circular(20),
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
                              ? 'Siap Scan'
                              : 'Arahkan Wajah ke Kamera',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isVerifying)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Memverifikasi wajah...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tombol presensi ───────────────────────────────
          Container(
            color  : const Color(0xFF111827),
            // ✅ FIX: SafeArea bottom agar tidak overflow dengan nav bar
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child  : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pastikan wajah berada di dalam lingkaran sebelum scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child : ElevatedButton.icon(
                    onPressed: (_isVerifying || !_faceDetected || !_isCameraReady)
                        ? null
                        : _showPresensiDialog,
                    icon : const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    label: const Text(
                      'Lakukan Presensi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_faceDetected && _isCameraReady)
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

// ── Widget kartu mode ─────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;

  const _ModeCard({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration  : const Duration(milliseconds: 200),
      padding   : const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color        : selected
            ? const Color(0xFF1E3A5F)
            : Colors.white.withOpacity(0.07),
        borderRadius : BorderRadius.circular(12),
        border       : Border.all(
          color: selected ? Colors.blueAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? Colors.white : Colors.white54,
            size : 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color     : selected ? Colors.white : Colors.white54,
              fontSize  : 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}