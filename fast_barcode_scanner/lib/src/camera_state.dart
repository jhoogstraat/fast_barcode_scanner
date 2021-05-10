import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum CameraEvent { init, paused, resumed, codeFound }

class CameraController extends InheritedWidget {
  final CameraEvent event;

  const CameraController({
    required Widget child,
    this.event = CameraEvent.init,
  }) : super(child: child);

  @override
  bool updateShouldNotify(CameraController oldWidget) =>
      event != oldWidget.event || event == CameraEvent.codeFound;

  static CameraEvent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameraController>()!.event;
}
