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

## 1.1.4

- Fixes `pauseDetector` on iOS
- Fixes no error reported when permissions are denied on Android
- Updates CameraX (compileSdk is now 31)

## 1.1.3

- Remove references to FlutterActivity (required by local_auth package)

## 1.1.2

- Fixed a bug where the app would crash when denying permissions on iOS.
- Smaller code cleanups
- Updated CameraX and ML Kit to latest versions.

## 1.1.1

- Camera position now taken into account on Android.
- Fix DetectionMode.pauseDetection on Android.
- Updated CameraX to v1.1.0-alpha05

## 1.1.0

- Relaxed kotlin version to 1.3.50
- Updated MLKit version (16.1.2)
- The camera state now contains the torch state (on/off)
- Fixed toggling the torch in the example project

## 1.0.2

- Even more documentation.

## 1.0.1

- Updated documentation.

## 1.0.0

- Initial pre-release.
