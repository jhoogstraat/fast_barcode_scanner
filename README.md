# Flutter Fast Barcode Scanner

A fast, modern Flutter barcode & QR code scanning plugin powered by native platform APIs (**CameraX + ML Kit** on Android, **AVFoundation / Vision** on iOS).

## Packages

### [fast_barcode_scanner](fast_barcode_scanner/)

[![Pub Version](https://img.shields.io/pub/v/fast_barcode_scanner?style=for-the-badge)](https://pub.dev/packages/fast_barcode_scanner)

The main Flutter plugin providing `BarcodeCamera`, `CameraController`, built-in overlays, and native iOS/Android implementations.

### [fast_barcode_scanner_platform_interface](fast_barcode_scanner_platform_interface/)

[![Pub Version](https://img.shields.io/pub/v/fast_barcode_scanner_platform_interface?style=for-the-badge)](https://pub.dev/packages/fast_barcode_scanner_platform_interface)

The common platform interface shared across implementations.

## Development

This repository uses a Dart Pub Workspace (`pubspec.yaml` at the root):

```bash
flutter pub get
flutter analyze
(cd fast_barcode_scanner_platform_interface && flutter test)
(cd fast_barcode_scanner && flutter test)
(cd fast_barcode_scanner/example && flutter test)
```

## Issues & Contributions

Please report bugs and feature requests via [GitHub Issues](https://github.com/jhoogstraat/fast_barcode_scanner/issues). See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
