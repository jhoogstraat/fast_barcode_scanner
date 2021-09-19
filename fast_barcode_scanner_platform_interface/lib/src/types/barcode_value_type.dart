import 'package:flutter/foundation.dart';

/// Contains all currently supported barcode value types.
/// see https://developers.google.com/android/reference/com/google/mlkit/vision/barcode/Barcode.BarcodeValueType
enum BarcodeValueType {
  unknown,
  contactInfo,
  email,
  isbn,
  phone,
  product,
  sms,
  text,
  url,
  wifi,
  geo,
  calender,
  license
}

extension BarcodeValueTypeName on BarcodeValueType {
  String get name => describeEnum(this);
}
