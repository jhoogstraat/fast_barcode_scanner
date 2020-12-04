import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum CameraEvent { init, paused, resumed, codeFound }

class CameraState extends InheritedWidget {
  final CameraEvent event;

  const CameraState({
    Widget child,
    this.event = CameraEvent.init,
  }) : super(child: child);

  @override
  bool updateShouldNotify(CameraState oldWidget) =>
      event != oldWidget.event || event == CameraEvent.codeFound;

  static CameraEvent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameraState>().event;
}
