# fast_barcode_scanner

A high-performance Flutter barcode & QR code scanning plugin built on native platform APIs:

- **Android**: [CameraX](https://developer.android.com/training/camerax) + [Google ML Kit Barcode Scanning](https://developers.google.com/ml-kit/vision/barcode-scanning) rendered via zero-copy Flutter `Texture`
- **iOS**: [AVFoundation](https://developer.apple.com/av-foundation/) or [Vision](https://developer.apple.com/documentation/vision) (`AVCaptureMetadataOutput` / `VNDetectBarcodesRequest`)

## Features

- Live `BarcodeCamera` preview widget with automatic lifecycle, orientation (portrait & landscape), and pinch-to-zoom support
- Dynamic reconfiguration without rebuilding the widget (barcode types, performance mode, detection mode, front/back camera switching)
- Configurable iOS detection engine: hardware-accelerated `AVFoundationApiMode` or `VisionApiMode(confidence: ...)`
- Still image scanning from raw bytes (`ImageSource.binary` / `ImageSource.bytes`) or native photo picker (`ImageSource.picker`)
- Built-in customizable overlays: `MaterialPreviewOverlay` (with `RectOfInterest` filtering), `CodeBoundaryOverlay` (bounding boxes & corner polygons), and `BlurPreviewOverlay`
- Torch control, zoom control (`setZoom`), camera switching (`canSwitchCamera` / `switchCamera`), and independent camera vs. detector pause/resume

## Requirements

- **Flutter**: `>=3.27.0` / **Dart**: `>=3.6.0`
- **iOS**: `13.0+` (add `NSCameraUsageDescription` to `ios/Runner/Info.plist`)
- **Android**: `minSdk 24+`, `compileSdk 36`, Java 17, AGP 9+ / Gradle 9.5+

## Installation

```yaml
dependencies:
  fast_barcode_scanner: ^2.0.0
```

### iOS Setup

Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan barcodes and QR codes.</string>
```

## Quick Start

```dart
import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanner')),
      body: BarcodeCamera(
        types: const [
          BarcodeType.ean8,
          BarcodeType.ean13,
          BarcodeType.code128,
          BarcodeType.qr,
        ],
        mode: PerformanceMode.system,
        detectionMode: DetectionMode.pauseDetection,
        position: CameraPosition.back,
        api: const ApiMode(apple: AVFoundationApiMode()),
        enablePinchToZoom: true,
        onScan: (barcodes) {
          for (final code in barcodes) {
            debugPrint('${code.type.name}: ${code.value}');
          }
        },
        children: [
          MaterialPreviewOverlay(
            rectOfInterest: RectOfInterest.wide(),
            showSensing: true,
          ),
          const CodeBoundaryOverlay(),
          const BlurPreviewOverlay(),
        ],
      ),
    );
  }
}
```

## Controlling the Camera

Use `CameraController.shared` to control the active scanner session:

| Method | Description |
| --- | --- |
| `initialize(...)` | Initializes and starts the camera and detector |
| `configure(...)` | Dynamically updates barcode types, performance mode, detection mode, or camera position |
| `pauseCamera()` / `resumeCamera()` | Pauses or resumes both preview and barcode detection |
| `pauseScanner()` / `resumeScanner()` | Pauses or resumes barcode detection while keeping the preview live |
| `toggleTorch()` | Toggles the flashlight and returns the new state |
| `setZoom(double factor)` | Sets zoom factor clamped to `[minZoom, maxZoom]` |
| `canSwitchCamera()` / `switchCamera()` | Checks multi-camera availability and toggles front/back camera |
| `scanImage(ImageSource)` | Scans a still image from bytes or the native photo picker |
| `dispose()` | Stops the camera and releases all native resources |

## Migration from v1.x

- `resolution` and `framerate` were replaced by `PerformanceMode` (`system`, `economic`, `high`).
- `onScan` now receives `List<Barcode>` (all codes detected in a frame) rather than a single `Barcode`.
- `CameraController.instance` is now `CameraController.shared`.
- `pauseDetector()` / `resumeDetector()` are now `pauseScanner()` / `resumeScanner()`.
- `Barcode.boundingBox` is now a `dart:ui` `Rect?`, with optional `Barcode.cornerPoints` (`List<Offset>?`).
