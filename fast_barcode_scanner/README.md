# fast_barcode_scanner

[![pub package](https://img.shields.io/pub/v/fast_barcode_scanner)](https://pub.dev/packages/fast_barcode_scanner)

A fast barcode scanner using **MLKit** (and **CameraX**) on Android and **AVFoundation** on iOS. This package leaves the UI up to the user, but rather gives an access to a camera preview.

*Note*: This plugin is still under development, and some APIs might not be available yet. If you have any issues, ideas or recommendendations, don't hesitate to create an issue or pull request on github. I am using this plugin in production myself and will actively develop and maintain it going forward.

**This plugin required iOS 10.0 and Android sdk version 21 or higher.**

## Installation
Add the following line to your **pubspec.yaml**:
```yaml
fast_barcode_scanner: ^1.0.2
```
### iOS
Add the `NSCameraUsageDescription` key to your `ios/Runner/Info.plist`, like so:
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires access to your phone’s camera solely for scanning barcodes</string>
```

### Android
Change the minimum Android sdk version to 21 (or higher) in your `android/app/build.gradle` file.
```
minSdkVersion 21
```

## Usage
The barcode scanner consists of two main classes `CameraController` and `BarcodeCamera`.
A full example looks like this:
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
As you can see, there are two overlays in the childrens list. These two are included in the package. `MaterialPreviewOverlay` mimics the official [material barcode scanning example](https://material.io/design/machine-learning/barcode-scanning.html#usage). `BlurPreviewOverlay` blurs the screen when a barcode is detected and unblurs it on resuming. These are normal widget, which are shown above the camera preview. Look at their source code to find out, how to react to events from the barcode scanner.

### CameraController
The `CameraController`-singleton manages the camera. It handles all the low level stuff like communicating with native code. It is implemented as a singleton to guarantee that there is always one and the same controller managing the camera. You can access the controller via the `CameraController.instance` attribute. These are the accessible methods:

|method          |Description                                      |
|----------------|-------------------------------------------------|
|`initialize`    | Initialized the scanner with the provided config|          
|`pauseDetector` | Actively pauses the scanner                     | 
|`resumeDetector`| Resumes the scanner from the paused state       |
|`toggleTorch`   | toggles the torch on and off                    |
|`dispose`       | Stops and resets the camera on platform level   |

You do not have to call `initialize` yourself, if you use the `BarcodeCamera` widget.
If you want to use your own widget however, have a look at `CameraController.instance.state`, which contains a `PreviewConfiguration` after initialization. This class contains all necessary information to build a preview widget yourself.

### BarcodeCamera
The `BarcodeCamera` is a widget showing a preview of the camera feed. It calls the `CameraController` in the background for initialization and configuration of the barcode camera.

An overview of all possible configurations (either passed to `BarcodeCamera` or `CameraController.initialize`):

|Attribute    |Description                                              |
|-------------|---------------------------------------------------------|
|`types`      | See code types to scan (see `BarcodeType`)              |
|`mode`       | Whether to pause the camera on detection                |          
|`resolution` | The resolution of the camera feed                       | 
|`framerate`  | The framerate of the camera feed                        |
|`position`   | Choose betreen back and front camera                    |
|`onScan`     | The callback when a barcode is scanned                  |
|`children`   | Child widgets to display on top (`BarcodeCamera` only)  |
