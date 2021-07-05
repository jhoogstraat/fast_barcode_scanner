import 'package:fast_barcode_scanner_example/scan_history.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: ListView.separated(
        itemBuilder: (ctx, idx) => ListTile(
          title: Text(history.scans[idx].value),
          subtitle: Text(
            describeEnum(history.scans[history.scans.length - idx - 1].type),
          ),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: history.scans.length,
      ),
    );
  }
}
