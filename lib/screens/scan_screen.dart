// lib/screens/scan_screen.dart

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

class _ScanScreenState extends State<ScanScreen> {
  // ── Camera ────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady  = false;

  // ── Face detection ────────────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(minFaceSize: 0.25),
  );
  bool _faceDetected      = false;
  bool _isProcessingFrame = false;

  // ── State ─────────────────────────────────────────────────
  bool   _isVerifying = false;
  String _mode        = 'offline'; // 'offline' | 'online'

  // Sesi aktif (diisi dari API)
  Map<String, dynamic>? _sesiAktif;
  bool _loadingSesi = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _cekSesiAktif();
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
        imageFormatGroup: ImageFormatGroup.jpeg,
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

      final bytes = Uint8List.fromList(
        image.planes.expand((plane) => plane.bytes).toList(),
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

  // ── Cek sesi aktif dari backend ───────────────────────────
  Future<void> _cekSesiAktif() async {
    setState(() => _loadingSesi = true);
    try {
      // Cek semua matakuliah user — simplified: ambil list matakuliah user
      // Untuk demo, kita langsung biarkan user input sesi_id
      // Implementasi penuh: GET /presensi/riwayat → ambil matakuliah IDs → cek sesi
      setState(() => _loadingSesi = false);
    } catch (_) {
      setState(() => _loadingSesi = false);
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
  Future<void> _verifikasiWajah({String? sesiId, String? kodeSesi}) async {
    if (_isVerifying || _cameraController == null || !_isCameraReady) return;
    if (!_faceDetected) {
      _showSnack('Wajah belum terdeteksi', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _cameraController!.stopImageStream();

      // Ambil foto
      final XFile foto  = await _cameraController!.takePicture();
      final bytes       = await foto.readAsBytes();

      double? lat, lng;

      // Ambil GPS untuk mode offline
      if (_mode == 'offline') {
        final pos = await _getGps();
        if (pos == null) {
          setState(() => _isVerifying = false);
          _startFaceDetection();
          return;
        }
        lat = pos.latitude;
        lng = pos.longitude;
      }

      // Kirim ke backend
      final fields = <String, String>{
        'sesi_id': sesiId ?? '',
        if (kodeSesi != null) 'kode_sesi': kodeSesi,
        if (lat != null) 'latitude': lat.toString(),
        if (lng != null) 'longitude': lng.toString(),
      };

      final response = await ApiClient().postMultipart(
        '/presensi',
        fields   : fields,
        fileField: 'foto',
        fileBytes: bytes,
        filename : 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (mounted) {
        context.go('/hasil', extra: {
          'success'     : response.statusCode == 200,
          'status'      : body['status'] ?? '',
          'akurasi'     : body['akurasi_wajah'] ?? 0.0,
          'waktu'       : body['waktu_presensi'] ?? '',
          'mode'        : body['mode_kelas'] ?? _mode,
          'pesan'       : response.statusCode == 200
              ? (body['pesan'] ?? 'Presensi berhasil!')
              : (body['detail'] ?? 'Presensi gagal'),
        });
      }
    } catch (e) {
      if (mounted) {
        context.go('/hasil', extra: {
          'success': false,
          'pesan'  : 'Error: $e',
          'status' : '',
          'akurasi': 0.0,
          'waktu'  : '',
          'mode'   : _mode,
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

  // ── Dialog pilih mode / masukkan sesi ID ─────────────────
  void _showPresensiDialog() {
    final sesiController = TextEditingController();
    String selectedMode  = _mode;

    showModalBottomSheet(
      context      : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color        : Color(0xFF1E293B),
            borderRadius : BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mode Presensi',
                  style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Toggle mode
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedMode = 'offline'),
                        child: _ModeCard(
                          label    : 'Offline (Tatap Muka)',
                          icon     : Icons.location_on_rounded,
                          selected : selectedMode == 'offline',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedMode = 'online'),
                        child: _ModeCard(
                          label    : 'Online (Daring)',
                          icon     : Icons.video_call_rounded,
                          selected : selectedMode == 'online',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Sesi ID
                TextField(
                  controller : sesiController,
                  style      : const TextStyle(color: Colors.white),
                  decoration : InputDecoration(
                    labelText     : 'Session ID (UUID dari backend)',
                    labelStyle    : const TextStyle(color: Colors.white54),
                    hintText      : 'Contoh: 550e8400-e29b-41d4-a716-446655440000',
                    hintStyle     : const TextStyle(color: Colors.white30, fontSize: 12),
                    filled        : true,
                    fillColor     : Colors.white.withOpacity(0.08),
                    border        : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide.none,
                    ),
                    prefixIcon    : const Icon(Icons.key, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),

                // Input kode sesi (hanya mode online)
                if (selectedMode == 'online') ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _mode = selectedMode);
                      context.go('/kode-sesi', extra: sesiController.text.trim());
                    },
                    icon : const Icon(Icons.pin_outlined),
                    label: const Text('Masukkan Kode Sesi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding        : const EdgeInsets.symmetric(vertical: 14),
                      shape          : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _mode = selectedMode);
                      _verifikasiWajah(sesiId: sesiController.text.trim());
                    },
                    icon : const Icon(Icons.face_rounded),
                    label: const Text('Verifikasi Wajah Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding        : const EdgeInsets.symmetric(vertical: 14),
                      shape          : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Presensi Wajah'),
        actions: [
          // Tombol logout
          IconButton(
            icon    : const Icon(Icons.logout),
            tooltip : 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
          // Riwayat
          IconButton(
            icon    : const Icon(Icons.history),
            tooltip : 'Riwayat',
            onPressed: () => context.go('/riwayat'),
          ),
        ],
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
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
                _isCameraReady && _cameraController != null
                    ? SizedBox.expand(child: CameraPreview(_cameraController!))
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
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
                          _faceDetected ? 'Siap Scan' : 'Arahkan Wajah ke Kamera',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // Loading saat verifikasi
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
            padding: const EdgeInsets.all(20),
            child  : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pastikan wajah berada di dalam lingkaran sebelum scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  child : ElevatedButton.icon(
                    onPressed: (_isVerifying || !_faceDetected)
                        ? null
                        : _showPresensiDialog,
                    icon : const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    label: const Text(
                      'Lakukan Presensi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _faceDetected ? const Color(0xFF1E3A5F) : Colors.grey.shade700,
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

// ── Widget kartu mode ────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String  label;
  final IconData icon;
  final bool    selected;

  const _ModeCard({required this.label, required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration  : const Duration(milliseconds: 200),
      padding   : const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color        : selected ? const Color(0xFF1E3A5F) : Colors.white.withOpacity(0.07),
        borderRadius : BorderRadius.circular(12),
        border       : Border.all(
          color: selected ? Colors.blueAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? Colors.white : Colors.white54, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color    : selected ? Colors.white : Colors.white54,
              fontSize : 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}