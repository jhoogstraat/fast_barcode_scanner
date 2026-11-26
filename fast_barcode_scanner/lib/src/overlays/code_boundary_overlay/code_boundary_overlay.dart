import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/src/overlays/code_boundary_overlay/code_border_painter.dart';
import 'package:flutter/widgets.dart';

typedef CodeBorderPaintBuilder = Paint Function(Barcode);

/// Draws a boundary around detected [Barcode]s.
class CodeBoundaryOverlay extends StatefulWidget {
  /// Creates a [CodeBoundaryOverlay].
  const CodeBoundaryOverlay({
    super.key,
    this.codeBorderPaintBuilder,
    this.barcodeValueStyle,
  });

  final CodeBorderPaintBuilder? codeBorderPaintBuilder;
  final TextStyle Function(Barcode)? barcodeValueStyle;

  @override
  State<CodeBoundaryOverlay> createState() => _CodeBoundaryOverlayState();
}

class _CodeBoundaryOverlayState extends State<CodeBoundaryOverlay> {
  final _cameraController = CameraController.shared;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Barcode>>(
      valueListenable: _cameraController.resultNotifier,
      builder: (context, barcodes, _) {
        final cameraInfo = _cameraController.state.value.cameraInformation;
        final analysisSize =
            cameraInfo?.analysisFrame.size ?? cameraInfo?.videoSize;

        if (analysisSize == null || barcodes.isEmpty) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: CodeBorderPainter(
            imageSize: analysisSize,
            barcodes: barcodes,
            barcodePaintSelector: widget.codeBorderPaintBuilder,
            barcodeValueStyle: widget.barcodeValueStyle,
          ),
        );
      },
    );
  }
}
