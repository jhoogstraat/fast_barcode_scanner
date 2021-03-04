// import 'package:fast_barcode_scanner/fast_barcode_scanner.dart'
//     show PreviewOverlay, PreviewOverlayState;
// import 'package:flutter/material.dart';
// import 'package:soundpool/soundpool.dart';

// class BeepPreviewOverlay extends PreviewOverlay {
//   final _pool = Soundpool(streamType: StreamType.notification);

//   BeepPreviewOverlay({Key key}) : super(key: key);

//   @override
//   _BeepPreviewOverlayState createState() => _BeepPreviewOverlayState();
// }

// class _BeepPreviewOverlayState extends PreviewOverlayState<BeepPreviewOverlay> {
//   int soundId;

//   @override
//   void initState() {
//     super.initState();
//     widget._pool
//         .loadUri("https://bigsoundbank.com/UPLOAD/m4a/1417.m4a")
//         .then((id) => soundId = id);
//   }

//   @override
//   void didDetectBarcode() => widget._pool.play(soundId);

//   @override
//   Widget build(BuildContext context) => SizedBox.shrink();
// }
