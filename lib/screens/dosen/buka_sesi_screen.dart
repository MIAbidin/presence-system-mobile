// lib/screens/dosen/buka_sesi_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';

class BukaSesiScreen extends StatefulWidget {
  const BukaSesiScreen({super.key});

  @override
  State<BukaSesiScreen> createState() => _BukaSesiScreenState();
}

class _BukaSesiScreenState extends State<BukaSesiScreen> {
  // ── State ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _matakuliahList = [];
  String? _selectedMatakuliahId;
  String  _mode           = 'offline'; // 'offline' | 'online'
  int     _batasTerlambat = 15;        // menit (offline)
  int     _durasiKode     = 30;        // menit (online)
  bool    _isCustomDurasi = false;
  int     _pertemuanKe    = 1;

  bool _isLoading    = false;
  bool _isLoadingMk  = true;
  String? _errorMsg;

  final _customDurasiController = TextEditingController();

  // Pilihan durasi preset (menit)
  final List<int> _durasiPreset = [15, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _fetchMatakuliah();
  }

  @override
  void dispose() {
    _customDurasiController.dispose();
    super.dispose();
  }

  // ── Fetch daftar matakuliah yang diampu dosen ─────────────
  Future<void> _fetchMatakuliah() async {
    setState(() => _isLoadingMk = true);
    try {
      // Endpoint GET /matakuliah/saya — list matakuliah dosen yang login
      final response = await ApiClient().get('/matakuliah/saya');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _matakuliahList = data.cast<Map<String, dynamic>>();
          if (_matakuliahList.isNotEmpty) {
            _selectedMatakuliahId = _matakuliahList.first['id'] as String;
          }
        });
      }
    } catch (e) {
      // Jika endpoint belum ada, tampilkan placeholder
      setState(() {
        _matakuliahList = [
          {'id': 'placeholder-id', 'nama': 'Matakuliah (data belum tersedia)', 'kode': '???'},
        ];
        _selectedMatakuliahId = 'placeholder-id';
      });
    } finally {
      setState(() => _isLoadingMk = false);
    }
  }

  // ── Buka sesi → POST /sesi/buka ──────────────────────────
  Future<void> _bukaSesi() async {
    if (_selectedMatakuliahId == null) {
      _showSnack('Pilih matakuliah terlebih dahulu', isError: true);
      return;
    }

    // Validasi durasi custom
    int durasiMenit = _durasiKode;
    if (_isCustomDurasi) {
      final parsed = int.tryParse(_customDurasiController.text.trim());
      if (parsed == null || parsed < 5 || parsed > 180) {
        _showSnack('Durasi harus antara 5–180 menit', isError: true);
        return;
      }
      durasiMenit = parsed;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      final body = <String, dynamic>{
        'matakuliah_id'  : _selectedMatakuliahId,
        'mode'           : _mode,
        'batas_terlambat': _batasTerlambat,
        'pertemuan_ke'   : _pertemuanKe,
      };

      // Durasi hanya untuk mode online
      if (_mode == 'online') {
        body['durasi_menit'] = durasiMenit;
      }

      final response = await ApiClient().post('/sesi/buka', body: body);

      if (response.statusCode == 200) {
        final sesiData = jsonDecode(response.body) as Map<String, dynamic>;

        if (!mounted) return;

        if (_mode == 'online') {
          // Navigasi ke halaman tampil kode
          context.go('/dosen/kode', extra: sesiData);
        } else {
          // Navigasi ke dashboard monitor
          context.go('/dosen/dashboard', extra: sesiData);
        }
      } else {
        final err = jsonDecode(response.body);
        setState(() => _errorMsg = err['detail'] ?? 'Gagal membuka sesi');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Buka Sesi Presensi'),
        elevation      : 0,
      ),
      body: _isLoadingMk
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section: Pilih Matakuliah ─────────────
                  _SectionCard(
                    title: '📚 Matakuliah',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue      : _selectedMatakuliahId,
                          decoration : InputDecoration(
                            labelText : 'Pilih Matakuliah',
                            filled    : true,
                            fillColor : Colors.white,
                            border    : OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide  : BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide  : BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: _matakuliahList.map((mk) {
                            return DropdownMenuItem<String>(
                              value: mk['id'] as String,
                              child: Text('${mk['kode']} – ${mk['nama']}'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedMatakuliahId = val),
                        ),
                        const SizedBox(height: 12),
                        // Pertemuan ke-
                        Row(
                          children: [
                            const Text('Pertemuan ke-',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                            const Spacer(),
                            _CounterButton(
                              value    : _pertemuanKe,
                              min      : 1,
                              max      : 16,
                              onChanged: (val) => setState(() => _pertemuanKe = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Mode Kelas ───────────────────
                  _SectionCard(
                    title: '🎓 Mode Kelas',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeToggleCard(
                            label    : 'Offline\n(Tatap Muka)',
                            icon     : Icons.location_on_rounded,
                            selected : _mode == 'offline',
                            color    : Colors.blue.shade700,
                            onTap    : () => setState(() => _mode = 'offline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ModeToggleCard(
                            label    : 'Online\n(Daring)',
                            icon     : Icons.video_call_rounded,
                            selected : _mode == 'online',
                            color    : Colors.purple.shade700,
                            onTap    : () => setState(() => _mode = 'online'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Konfigurasi berdasarkan mode ──
                  if (_mode == 'offline') ...[
                    _SectionCard(
                      title: '⏰ Batas Terlambat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mahasiswa yang presensi lebih dari $_batasTerlambat menit '
                            'setelah sesi dibuka akan dicatat Terlambat.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CounterButton(
                                value    : _batasTerlambat,
                                min      : 5,
                                max      : 60,
                                step     : 5,
                                onChanged: (val) => setState(() => _batasTerlambat = val),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$_batasTerlambat menit',
                                style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Quick select
                          Wrap(
                            spacing: 8,
                            children: [5, 10, 15, 20, 30].map((m) {
                              final selected = _batasTerlambat == m;
                              return ChoiceChip(
                                label    : Text('$m mnt'),
                                selected : selected,
                                onSelected: (_) => setState(() => _batasTerlambat = m),
                                selectedColor: const Color(0xFF1E3A5F),
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : Colors.black87),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _SectionCard(
                      title: '🔑 Durasi Kode Aktif',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kode sesi akan kedaluwarsa setelah durasi ini. '
                            'Dosen dapat memperpanjang atau generate ulang kode.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 16),

                          // Preset chips
                          Wrap(
                            spacing: 8,
                            children: _durasiPreset.map((d) {
                              final selected = !_isCustomDurasi && _durasiKode == d;
                              return ChoiceChip(
                                label    : Text('$d mnt'),
                                selected : selected,
                                onSelected: (_) => setState(() {
                                  _durasiKode     = d;
                                  _isCustomDurasi = false;
                                }),
                                selectedColor: const Color(0xFF1E3A5F),
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : Colors.black87),
                              );
                            }).toList()
                              ..add(ChoiceChip(
                                label    : const Text('Custom'),
                                selected : _isCustomDurasi,
                                onSelected: (_) => setState(() => _isCustomDurasi = true),
                                selectedColor: Colors.purple.shade600,
                                labelStyle: TextStyle(
                                  color: _isCustomDurasi ? Colors.white : Colors.black87),
                              )),
                          ),

                          if (_isCustomDurasi) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller  : _customDurasiController,
                              keyboardType: TextInputType.number,
                              decoration  : InputDecoration(
                                labelText : 'Durasi (menit)',
                                hintText  : 'Masukkan 5–180',
                                suffixText: 'menit',
                                filled    : true,
                                fillColor : Colors.white,
                                border    : OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                '$_durasiKode menit',
                                style: const TextStyle(
                                  fontSize  : 24,
                                  fontWeight: FontWeight.bold,
                                  color     : Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Error message ─────────────────────────
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding   : const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color        : Colors.red.shade50,
                        borderRadius : BorderRadius.circular(10),
                        border       : Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                              style: TextStyle(color: Colors.red.shade700)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Tombol Buka Sesi ──────────────────────
                  SizedBox(
                    height: 56,
                    child : ElevatedButton.icon(
                      onPressed: _isLoading ? null : _bukaSesi,
                      icon : _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_rounded, size: 24),
                      label: Text(
                        _isLoading
                            ? 'Membuka sesi...'
                            : _mode == 'online'
                                ? 'Buka Sesi & Generate Kode'
                                : 'Buka Sesi Tatap Muka',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == 'online'
                            ? Colors.purple.shade700
                            : const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color        : Colors.white,
        borderRadius : BorderRadius.circular(14),
        boxShadow    : [
          BoxShadow(
            color      : Colors.black.withOpacity(0.05),
            blurRadius : 8,
            offset     : const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ModeToggleCard extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _ModeToggleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration  : const Duration(milliseconds: 200),
        padding   : const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color        : selected ? color : Colors.grey.shade100,
          borderRadius : BorderRadius.circular(12),
          border       : Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: selected ? Colors.white : Colors.grey.shade600,
              size : 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color     : selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize  : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final int      value;
  final int      min;
  final int      max;
  final int      step;
  final Function(int) onChanged;

  const _CounterButton({
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon     : const Icon(Icons.remove_circle_outline),
          onPressed: value - step >= min
              ? () => onChanged(value - step)
              : null,
          color: const Color(0xFF1E3A5F),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon     : const Icon(Icons.add_circle_outline),
          onPressed: value + step <= max
              ? () => onChanged(value + step)
              : null,
          color: const Color(0xFF1E3A5F),
        ),
      ],
    );
  }
}