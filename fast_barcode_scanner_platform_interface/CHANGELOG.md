## 2.0.0

- Finalized v2.0.0 platform interface API (`PerformanceMode`, `DetectionMode`, `CameraPosition`, `ApiMode`, `AppleApiMode`, `AVFoundationApiMode`, `VisionApiMode`, `AndroidApiMode`).
- Added `setZoom(double)` and `canSwitchCamera()` to `FastBarcodeScannerPlatform` and `MethodChannelFastBarcodeScanner`.
- Extended `CameraInformation` with `textureId`, `sensorOrientation`, `minZoom`, and `maxZoom`.
- Updated `Barcode` to expose `Rect? boundingBox` and `List<Offset>? cornerPoints` with proper value equality and `Object.hash`.
- Converted `ImageSource` to a sealed class (`BinaryImageSource`, `PickerImageSource`) with `ImageSource.bytes(...)` convenience factory.
- Fixed `MethodChannelFastBarcodeScanner.init` serializing `PerformanceMode` enum instead of `mode.name`.
- Added comprehensive unit test suite.

## 2.0.0-dev.2

- Refactoring
- Moved detections to separate event channel

## 2.0.0-dev.1

- Add ability to update the scanner configuration.
- Add ability to request a single image detection.
