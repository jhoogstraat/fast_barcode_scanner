import 'dart:async';

import 'package:flutter/material.dart';

abstract class PreviewOverlay extends StatefulWidget {
  const PreviewOverlay({Key key}) : super(key: key);

  @override
  PreviewOverlayState createState();
}

abstract class PreviewOverlayState<T extends PreviewOverlay> extends State<T> {
  FutureOr<void> didDetectBarcode() {}
  FutureOr<void> didResumePreview() {}
}
