import 'package:flutter/material.dart';

import 'scanning_screen/scanning_screen.dart';

void main() {
  runApp(const MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fast Barcode Scanner')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Open Scanner'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanningScreen()),
          ),
        ),
      ),
    );
  }
}
