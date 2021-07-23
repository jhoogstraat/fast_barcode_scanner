import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../history_screen/history_screen.dart';
import '../scan_history.dart';

class ScansCounter extends StatefulWidget {
  const ScansCounter({Key? key}) : super(key: key);

  @override
  _ScansCounterState createState() => _ScansCounterState();
}

class _ScansCounterState extends State<ScansCounter> {
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
                    "${history.count(barcode)}x\n${describeEnum(barcode.type)} - ${describeEnum(barcode.valueType)}: ${barcode.value}")
                : const SizedBox.shrink(),
          ),
          TextButton(
              onPressed: () async {
                final cam = CameraController();
                cam.pauseCamera();
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()));
                cam.resumeCamera();
              },
              child: const Text('History'))
        ],
      ),
    );
  }
}
