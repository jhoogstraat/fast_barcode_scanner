# fast_barcode_scanner

[![pub package](https://img.shields.io/pub/v/fast_barcode_scanner)](https://pub.dev/packages/fast_barcode_scanner)

A fast barcode scanner using **MLKit** (and **CameraX**) on Android and **AVFoundation** on iOS. This package leaves the UI up to the user, but rather gives an access to a camera preview.

*Note*: If you have any issues, ideas or recommendendations, don't hesitate to create an issue or pull request on github. I am using this plugin in production myself and will actively develop and maintain it going forward.

**This plugin required iOS 11.0 and Android sdk version 21 or higher.**

### If you like my work, please consider to
[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jhoogstraat)

## Installation
Add the following line to your **pubspec.yaml**:
```yaml
fast_barcode_scanner: ^2.0.0
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
The barcode scanner consists of two main classes `CameraController` and `BarcodeCamera`, which are further described below. Have a look at the example app to find out how to control and interact with the plugin.
A (almost) minimal example looks like this:
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
You don' have to provide all settings yourself, as sensible defaults are set already.
As you can see, there are two overlays in the childrens list. These two are included in the package. `MaterialPreviewOverlay` mimics the official [material barcode scanning example](https://material.io/design/machine-learning/barcode-scanning.html#usage). `BlurPreviewOverlay` blurs the screen when a barcode is detected and unblurs it on resuming. These are normal widget, which are shown above the camera preview (inside a `Stack` widget). If you want to code your own overlay, look at the source code, to find out how to react to events from the barcode scanner.

### CameraController
The `CameraController`-singleton manages the camera. It handles all the low level stuff like communicating with native code. It is implemented as a singleton to guarantee that there is always one and the same controller managing the camera. You can access the controller via the `CameraController.instance` attribute. These are the accessible methods:

method          |Description                                      
----------------------|-------------------------------------------------
`initialize`          | Initializes the scanner with the provided config
`pauseDetector`       | Actively pauses the scanner
`resumeDetector`      | Resumes the scanner from the paused state
`toggleTorch`         | toggles the torch on and off
`changeConfiguration` | Push an updated `ScannerConfiguration`
`analyzeImage`
`dispose`             | Stops and resets the camera on platform level

You do not have to call `initialize` yourself, if you use the `BarcodeCamera` widget.
Calling these methods are throwing. For possible error codes have a look at ScannerError.swift or ScannerError.kt.

#### CameraState
`CameraController.instance.state` contains the current state of the scanner.
Use it to build your own overlay. The following information can be accessed:

Attribute | Description
----------------|-------------------------------------------------
`isInitialized` | Indicated whether the camera is currently initialized
`previewConfig` | A `PreviewConfiguration` that is currently used
`scannerConfig` | A `ScannerConfiguration` that is currently used
`eventNotifier` | A event notifier to react to init or detecting codes
`torchState`    | The current state of the torch (on/off)
`hasError`      | Indicates whether `error` is null or not
`error`         | Access the error produced last

A `PreviewConfiguration` contains informations about the the dimensions and rotation of the preview and `ScannerConfiguration` holds the settings about how the camera was setup.

### BarcodeCamera
The `BarcodeCamera` is a widget showing a preview of the camera feed. It calls the `CameraController` in the background for initialization and configuration of the barcode camera.

It allows to configurate the scanner. A `ScannerConfiguration` is then generated and passed to native code, which in turn produces a `PreviewConfiguration`. You can find both in the `CameraController.instance.state` attribute. A full overview of all parameters that can be passed to `BarcodeCamera`:

Attribute    |Description                                              
-------------|-------------------------------------------
`types`      | See code types to scan (see `BarcodeType`)
`resolution` | The resolution of the camera feed
`framerate`  | The framerate of the camera feed
`position`   | Choose between back and front camera
`mode`       | Whether to pause the camera on detection
`onScan`     | The callback when a barcode is scanned
`onError`    | A Widget to display when an error occurs
`children`   | Widgets to display on top of the preview
