import 'package:fast_barcode_scanner/preview_overlay.dart';
import 'package:flutter/material.dart';
import 'package:soundpool/soundpool.dart';

class BeepPreviewOverlay extends PreviewOverlay {
  final _pool = Soundpool(streamType: StreamType.notification);

  BeepPreviewOverlay({Key key}) : super(key: key);

  @override
  _BeepPreviewOverlayState createState() => _BeepPreviewOverlayState();
}

class _BeepPreviewOverlayState extends PreviewOverlayState<BeepPreviewOverlay> {
  int soundId;

  @override
  void initState() async {
    super.initState();
    soundId = await widget._pool
        .loadUri("https://bigsoundbank.com/UPLOAD/m4a/1417.m4a");
  }

  @override
  Future<void> didDetectBarcode() {
    widget._pool.play(soundId);
  }

  @override
  Future<void> didResumePreview() {}

  @override
  Widget build(BuildContext context) {
    return SizedBox();
  }
}
