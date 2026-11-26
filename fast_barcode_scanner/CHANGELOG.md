## 2.0.0

### Highlights
- **Stable v2.0.0 release** with unified cross-platform wire protocol across Dart, iOS (Swift), and Android (Kotlin).
- **Modernized Android stack**: Kotlin DSL (`build.gradle.kts`), AGP 9.3.1 / Gradle 9.5, Kotlin 2.4.20, `namespace` support, `compileSdk 36`, `minSdk 24`, Java 17, CameraX 1.4.1, ML Kit 17.3.0, and zero-copy Flutter `Texture` preview rendering.
- **Hardened iOS stack**: Dedicated serial `AVCaptureSession` queue (eliminating main-thread warnings and background `EXC_BAD_ACCESS` crashes), PrivacyInfo manifest bundled in podspec, full AVFoundation + Vision symbology support (including Codabar, GS1 DataBar, GS1 DataMatrix, and MSI on iOS 17+).

### New Features
- **Zoom control**: `CameraController.setZoom(double)` and built-in pinch-to-zoom on `BarcodeCamera` (`enablePinchToZoom`).
- **Camera switching**: `CameraController.canSwitchCamera()` and `CameraController.switchCamera()`, plus live `configure(position: ...)`.
- **Landscape & orientation support**: Automatic orientation handling on both iOS (`AVCaptureVideoPreviewLayer`) and Android (`Texture` + CameraX display rotation).
- **Barcode corner points**: `Barcode.boundingBox` (`Rect?`) and `Barcode.cornerPoints` (`List<Offset>?`) returned on both iOS and Android, wired into `CodeBoundaryOverlay` and `MaterialPreviewOverlay`.
- **Hot Restart resilience**: Re-initializing cleanly disposes any stale native camera session instead of failing with `ALREADY_INITIALIZED`.
- **Automatic app lifecycle management**: `BarcodeCamera` automatically pauses/resumes the camera when the app moves to/from background.

### Bug Fixes
- Fixed `startDetector` / `stopDetector` method name mismatch on iOS.
- Fixed first-launch black screen on Android after granting camera permission.
- Fixed crash on Android when denying camera permission.
- Fixed Android `CameraInformation.serialized()` returning `Unit` and `scanImage` double-submitting results / using unsupported `Bitmap.Config.HARDWARE`.
- Fixed iOS `VisionBarcodeScanner` firing empty detections and potential main-queue deadlock.
- Fixed `CameraController` ignoring `PlatformException` (previously caught `Error` instead of `Object`) and leaking `_isConfiguringLock` on failure.
- Fixed `MaterialPreviewOverlay` ROI filtering (previously had `analysisSize = null`).
- Removed dependency on `package:flutter/material.dart` inside the plugin library so it works in Cupertino and Widgets-only apps.

## 2.0.0-dev.2

- Analyze still images from binary or native image pickers on iOS and Android
- Added options to customize the QR scanner: sensingColor, backgroundColor, cutOutShape, cutOutBorderColor
- Added first tests
- Even more refactoring
- Simplified Readme

## 2.0.0-dev.1

- Added ability to change the scanner configuration while running
- Restructured and simplified native code on iOS and Android
- Fully implemented error handling
- UPC-A is now correctly reported on iOS (EAN-13 with a leading 0 is regarded as UPC-A).
- Massively improved sample app with controls over all features.
- Updated CameraX and ML Kit to the newest versions
