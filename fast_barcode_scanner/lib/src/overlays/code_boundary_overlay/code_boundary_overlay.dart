import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/src/overlays/code_boundary_overlay/code_border_painter.dart';
import 'package:flutter/material.dart';

typedef CodeBorderPaintBuilder = Paint Function(Barcode code);
typedef CodeValueDisplayBuilder = CodeValueDisplay? Function(Barcode code);

class CodeBoundaryOverlay extends StatefulWidget {
  final CodeBorderPaintBuilder? codeBorderPaintBuilder;
  final CodeValueDisplayBuilder? codeValueDisplayBuilder;

  const CodeBoundaryOverlay({
    Key? key,
    this.codeBorderPaintBuilder,
    this.codeValueDisplayBuilder,
  }) : super(key: key);

  @override
  State<CodeBoundaryOverlay> createState() => _CodeBoundaryOverlayState();
}

class _CodeBoundaryOverlayState extends State<CodeBoundaryOverlay> {
  final _cameraController = CameraController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Barcode>>(
        valueListenable: _cameraController.scannedBarcodes,
        builder: (context, barcodes, child) {
          final analysisSize = _cameraController.analysisSize;
          if (analysisSize != null && barcodes.isNotEmpty) {
            return CustomPaint(
              painter: CodeBorderPainter(
                imageSize: analysisSize,
                barcodes: barcodes,
                barcodePaintSelector: widget.codeBorderPaintBuilder,
                textDecorator: widget.codeValueDisplayBuilder,
              ),
            );
          } else {
            return Container();
          }
        });
  }
}

enum CodeValueDisplayLocation { centerTop, centerBottom }

abstract class CodeValueDisplay {
  final CodeValueDisplayLocation location;
  final Color color;

  TextSpan get textSpan;

  CodeValueDisplay({
    required this.color,
    this.location = CodeValueDisplayLocation.centerBottom,
  });
}

class BasicBarcodeValueDisplay extends CodeValueDisplay {
  final String text;
  final double fontSize;
  final Color backgroundColor;
  final FontWeight fontWeight;
  final String fontFamily;

  BasicBarcodeValueDisplay({
    required this.text,
    required Color color,
    CodeValueDisplayLocation location = CodeValueDisplayLocation.centerBottom,
    CodeBorderPaintBuilder? customBarcodePaintSelector,
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
