import 'package:flutter/material.dart';

/// An Interface that overlays implement to be able to receive events from the
/// barcode camera as delegates.
abstract class PreviewOverlay extends StatefulWidget {
  const PreviewOverlay({Key key}) : super(key: key);

  @override
  PreviewOverlayState createState();
}

abstract class PreviewOverlayState<T extends PreviewOverlay> extends State<T> {
  void didDetectBarcode() {}
  void didResumePreview() {}
}
