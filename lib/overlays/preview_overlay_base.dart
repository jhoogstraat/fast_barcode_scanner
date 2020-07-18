import 'package:flutter/material.dart';

abstract class PreviewOverlay extends StatefulWidget {
  const PreviewOverlay({Key key}) : super(key: key);

  @override
  PreviewOverlayState createState();
}

abstract class PreviewOverlayState<T extends PreviewOverlay> extends State<T> {
  Future<void> didDetectBarcode();
  Future<void> didResumePreview();
}
