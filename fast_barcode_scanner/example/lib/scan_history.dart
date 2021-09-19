import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/cupertino.dart';

final history = ScanHistory();

class ScanHistory extends ChangeNotifier {
  final scans = <Barcode>[];
  final counter = <String, int>{};

  Barcode? get recent => scans.isNotEmpty ? scans.last : null;
  int count(Barcode of) => counter[of.value] ?? 0;

  void add(Barcode barcode) {
    scans.add(barcode);
    counter.update(barcode.value, (value) => value + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void clear() {
    scans.clear();
    counter.clear();
    notifyListeners();
  }
}
