import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Should initialize all class members from list', () {
    final config1 = PreviewConfiguration({
      "textureId": 1,
      "targetRotation": 2,
      "height": 3,
      "width": 4,
      "analysis": "5"
    });

    final config2 = PreviewConfiguration({
      "textureId": 5,
      "targetRotation": 4,
      "height": 3,
      "width": 2,
      "analysis": "1"
    });

    const expected1 = [1, 2, 3, 4, "5"];
    const expected2 = [5, 4, 3, 2, "1"];

    expect([
      config1.textureId,
      config1.targetRotation,
      config1.height,
      config1.width,
      config1.analysisResolution
    ], expected1);

    expect([
      config2.textureId,
      config2.targetRotation,
      config2.height,
      config2.width,
      config2.analysisResolution
    ], expected2);
  });

  test("Should throw A TypeError if invalid map is provided", () {
    expect(() => PreviewConfiguration({}), throwsA(isA<TypeError>()));
    expect(() => PreviewConfiguration({"textureId": "1"}),
        throwsA(isA<TypeError>()));
  });

  test('Should be value-equatable', () {
    final config1 = PreviewConfiguration({
      "textureId": 1,
      "targetRotation": 2,
      "height": 3,
      "width": 4,
      "analysis": "5"
    });

    final config2 = PreviewConfiguration({
      "textureId": 5,
      "targetRotation": 4,
      "height": 3,
      "width": 2,
      "analysis": "1"
    });

    final config1Copy = PreviewConfiguration({
      "textureId": 1,
      "targetRotation": 2,
      "height": 3,
      "width": 4,
      "analysis": "5"
    });

    final config2Copy = PreviewConfiguration({
      "textureId": 5,
      "targetRotation": 4,
      "height": 3,
      "width": 2,
      "analysis": "1"
    });

    expect(config1 == config1, true);
    expect(config2 == config2, true);
    expect(config1 == config2, false);
    expect(config1 == config1Copy, true);
    expect(config2 == config2Copy, true);
  });
}
