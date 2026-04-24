// temp
import 'package:flutter/material.dart';

class RekapScreen extends StatelessWidget {
  final String sesiId;

  const RekapScreen({super.key, required this.sesiId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap')),
      body: Center(
        child: Text('Sesi ID: $sesiId'),
      ),
    );
  }
}