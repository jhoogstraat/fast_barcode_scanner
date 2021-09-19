import 'package:flutter/foundation.dart';

/// Contains all currently on iOS and Android supported barcode types.
enum BarcodeType {
  /// Android, iOS
  aztec,

  /// Android, iOS
  code128,

  /// Android, iOS
  code39,

  /// iOS
  code39mod43,

  /// Android, iOS
  code93,

  /// Android
  codabar,

  /// Android, iOS
  dataMatrix,

  /// Android, iOS
  ean13,

  /// Android, iOS
  ean8,

  /// Android, iOS
  itf,

  /// Android, iOS
  pdf417,

  /// Android, iOS
  qr,

  /// Android, iOS
  upcA,

  /// Android, iOS
  upcE,

  /// iOS
  interleaved,
}

extension BarcodeTypeName on BarcodeType {
  String get name => describeEnum(this);
}
