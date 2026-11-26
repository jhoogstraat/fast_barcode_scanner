import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';

final history = ScanHistory();

class ScanHistory extends ChangeNotifier {
  final scans = <Barcode>[];
  final counter = <String, int>{};

  Barcode? get recent => scans.lastOrNull;

  int count(Barcode barcode) => counter[barcode.value] ?? 0;

  void addAll(List<Barcode> barcodes) {
    for (final barcode in barcodes) {
      scans.add(barcode);
      counter.update(barcode.value, (value) => value + 1, ifAbsent: () => 1);
    }

    notifyListeners();
  }

  void clear() {
    scans.clear();
    counter.clear();
    notifyListeners();
  }
}
