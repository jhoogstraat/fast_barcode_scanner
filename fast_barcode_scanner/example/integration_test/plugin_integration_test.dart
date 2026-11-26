import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CameraController starts uninitialized',
      (WidgetTester tester) async {
    expect(CameraController.shared.state.value.isInitialized, isFalse);
  });
}
