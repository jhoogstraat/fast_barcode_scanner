import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/src/overlays/code_boundary_overlay/code_border_painter.dart';
import 'package:flutter/widgets.dart';

typedef CodeBorderPaintBuilder = Paint Function(Barcode);

/// Draws a boundary around detected [Barcode]s.
class CodeBoundaryOverlay extends StatelessWidget {
  /// Creates a [CodeBoundaryOverlay].
  const CodeBoundaryOverlay({
    super.key,
    this.codeBorderPaintBuilder,
    this.barcodeValueStyle,
  });

  final CodeBorderPaintBuilder? codeBorderPaintBuilder;
  final TextStyle Function(Barcode)? barcodeValueStyle;

  @override
  Widget build(BuildContext context) {
    final controller = CameraController.shared;
    return ValueListenableBuilder<List<Barcode>>(
      valueListenable: controller.resultNotifier,
      builder: (context, barcodes, _) {
        final cameraInfo = controller.state.value.cameraInformation;
        final analysisSize =
            cameraInfo?.analysisFrame.size ?? cameraInfo?.videoSize;

        if (analysisSize == null || barcodes.isEmpty) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: CodeBorderPainter(
            imageSize: analysisSize,
            barcodes: barcodes,
            barcodePaintSelector: codeBorderPaintBuilder,
            barcodeValueStyle: barcodeValueStyle,
          ),
        );
      },
    );
  }
}
