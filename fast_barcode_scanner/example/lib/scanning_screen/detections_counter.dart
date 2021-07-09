import 'package:fast_barcode_scanner_example/history_screen/history_screen.dart';
import 'package:fast_barcode_scanner_example/scan_history.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DetectionsCounter extends StatefulWidget {
  const DetectionsCounter({Key? key}) : super(key: key);

  @override
  _DetectionsCounterState createState() => _DetectionsCounterState();
}

class _DetectionsCounterState extends State<DetectionsCounter> {
  @override
  void initState() {
    super.initState();
    history.addListener(onBarcodeListener);
  }

  @override
  void dispose() {
    history.removeListener(onBarcodeListener);
    super.dispose();
  }

  void onBarcodeListener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final barcode = history.recent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: barcode != null
                ? Text(
                    "${history.count(barcode)}x\n${describeEnum(barcode.type)}: ${barcode.value}")
                : const SizedBox.shrink(),
          ),
          TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: const Text('History'))
        ],
      ),
    );
  }
}
