# fast_barcode_scanner

Fast barcode scanning library using the latest technologies on Android and iOS.

- [**ML Kit**](https://developers.google.com/ml-kit) and [**CameraX**](https://developer.android.com/training/camerax) on Android
- [**AVFoundation**](https://developer.apple.com/av-foundation/) and [**Vision**](https://developer.apple.com/documentation/vision) on iOS.

It provides a live preview widget you can put anywhere in your widget tree with rich configurability.

**This plugin required iOS 11.0 and Android API level 21 or higher.**

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jhoogstraat)

## Installation

Add the following line to your **pubspec.yaml**:

```yaml
fast_barcode_scanner: ^2.0.0-dev.2
```

### iOS

Add the `NSCameraUsageDescription` key to your `ios/Runner/Info.plist`, like so:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires access to your phone’s camera solely for scanning barcodes</string>
```

### Android

Change the minimum Android api level to 21 (or higher) in your `android/app/build.gradle` file.

```
minSdkVersion 21
```

## Usage

Insert the `BarcodeCamera` anywhere in your widget tree to get a live camera preview:

```dart
import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';

class MyScannerScreen extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: Text('Barcode Scanner')),
            body: BarcodeCamera(
                types: const [
                    BarcodeType.ean8,
                    BarcodeType.ean13,
                    BarcodeType.code128
                ],
                resolution: Resolution.hd720,
                framerate: Framerate.fps30,
                position: CameraPosition.back,
                mode: DetectionMode.pauseVideo,
                onScan: (code) => print(code),
                children: [
                    MaterialPreviewOverlay(animateDetection: false),
                    BlurPreviewOverlay(),
                    Positioned(
                      child: ElevatedButton(
                        onPressed: () =>
                            CameraController.instance.resumeDetector(),
                        child: Text('Resume'),
                      ),
                    )
                ],
            )
        )
    }
}
```

Two overlays are included:

- `MaterialPreviewOverlay` mimics the official material barcode scanning [example](https://material.io/design/machine-learning/barcode-scanning.html#usage)
- `BlurPreviewOverlay` blurs the screen when a barcode is detected

## Controlling the camera

The `CameraController`-singleton manages the camera. Normally when using `BarcodeCamera` you don't need `CameraController`.

To get access use the following anyhwere in your code:

```dart
final controller = CameraController()
```

Here is a full list of all the methods `CameraController` provides:
| method | Description |
| --------------------- | ------------------------------------------------ |
| `initialize` | Initializes the scanner with the provided config |
| `pauseDetector` | Actively pauses the scanner |
| `resumeDetector` | Resumes the scanner from the paused state |
| `toggleTorch` | toggles the torch on and off |
| `changeConfiguration` | Push an updated `ScannerConfiguration` |
| `analyzeImage` | |
| `dispose` | Stops and resets the camera on platform level |

### CameraState

The state comes in handy when building overlays that change depending on it.
You can access the state by using `CameraController().state`.

| Attribute       | Description                                           |
| --------------- | ----------------------------------------------------- |
| `isInitialized` | Indicated whether the camera is currently initialized |
| `previewConfig` | The current `PreviewConfiguration`                    |
| `scannerConfig` | The current `ScannerConfiguration`                    |
| `eventNotifier` | Notifies listeners of `CameraEvent`s                  |
| `torchState`    | The current state of the torch (on/off)               |
| `hasError`      | Indicates if `error` is null or not                   |
| `error`         | Access the most recent error                          |
