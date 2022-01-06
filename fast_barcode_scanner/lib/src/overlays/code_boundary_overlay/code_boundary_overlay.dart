import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/src/overlays/code_boundary_overlay/code_box_painter.dart';
import 'package:flutter/material.dart';

typedef CustomBarcodePaintSelector = Paint Function(Barcode code);
typedef BarcodeTextDecorator = TextDecoration? Function(Barcode code);

class CodeBoundaryOverlay extends StatefulWidget {
  final CustomBarcodePaintSelector? customBarcodePaint;
  final BarcodeTextDecorator? barcodeTextDecorator;

  const CodeBoundaryOverlay({
    Key? key,
    this.customBarcodePaint,
    this.barcodeTextDecorator,
  }) : super(key: key);

  @override
  State<CodeBoundaryOverlay> createState() => _CodeBoundaryOverlayState();
}

class _CodeBoundaryOverlayState extends State<CodeBoundaryOverlay> {
  final _cameraController = CameraController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Barcode>>(
        stream: _cameraController.scannedCodes,
        initialData: const [],
        builder: (context, scannedCodesSnapshot) {
          final analysisSize = _cameraController.analysisSize;
          var scannedCodes = scannedCodesSnapshot.data;
          if (analysisSize != null &&
              scannedCodes != null &&
              scannedCodes.isNotEmpty) {
            return CustomPaint(
              painter: BarcodePainter(
                imageSize: analysisSize,
                barcodes: scannedCodes,
                barcodePaintSelector: widget.customBarcodePaint,
                textDecorator: widget.barcodeTextDecorator,
              ),
            );
          } else {
            return Container();
          }
        });
  }
}

enum TextDecorationLocation { centerTop, centerBottom }

abstract class TextDecoration {
  final TextDecorationLocation location;
  final Color color;

  TextSpan get textSpan;

  TextDecoration(
      {required this.color,
        this.location = TextDecorationLocation.centerBottom});
}

class SimpleTextDecoration extends TextDecoration {
  final String text;
  final double fontSize;
  final Color backgroundColor;
  final FontWeight fontWeight;
  final String fontFamily;

  SimpleTextDecoration({
    required this.text,
    required Color color,
    TextDecorationLocation location = TextDecorationLocation.centerBottom,
    CustomBarcodePaintSelector? customBarcodePaintSelector,
    this.fontSize = 16.0,
    this.backgroundColor = Colors.white,
    this.fontWeight = FontWeight.w600,
    this.fontFamily = "Roboto",
  }) : super(location: location, color: color);

  @override
  TextSpan get textSpan => TextSpan(
    style: TextStyle(
        color: color,
        fontSize: fontSize,
        backgroundColor: backgroundColor,
        fontWeight: fontWeight,
        fontFamily: fontFamily),
    text: text,
  );
}