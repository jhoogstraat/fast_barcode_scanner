import 'dart:async';
import 'scanner_screen.dart';
import 'package:flutter/material.dart';

class DetectionsCounter extends StatefulWidget {
  const DetectionsCounter({Key? key}) : super(key: key);

  @override
  _DetectionsCounterState createState() => _DetectionsCounterState();
}

class _DetectionsCounterState extends State<DetectionsCounter> {
  @override
  void initState() {
    super.initState();
    _streamToken = codeStream.stream.listen((event) {
      final count = detectionCount.update(event.value, (value) => value + 1,
          ifAbsent: () => 1);
      detectionInfo.value = "${count}x\n${event.value}";
    });
  }

  late StreamSubscription _streamToken;
  Map<String, int> detectionCount = {};
  final detectionInfo = ValueNotifier("");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ValueListenableBuilder(
        valueListenable: detectionInfo,
        builder: (context, dynamic info, child) => Text("Detection: " + info),
      ),
    );
  }

  @override
  void dispose() {
    _streamToken.cancel();
    super.dispose();
  }
}
