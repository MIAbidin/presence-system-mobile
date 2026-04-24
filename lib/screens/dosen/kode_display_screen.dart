// temp
import 'package:flutter/material.dart';

class KodeDisplayScreen extends StatelessWidget {
  final dynamic sesiData;

  const KodeDisplayScreen({super.key, required this.sesiData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kode Display')),
      body: Center(
        child: Text('Data: $sesiData'),
      ),
    );
  }
}