import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Should initialize all class members from list', () {
    final config1 = PreviewConfiguration({
      "textureId": 1,
      "targetRotation": 2,
      "height": 3,
      "width": 4,
      "analysisWidth": 6,
      "analysisHeight": 7,
    });

    final config2 = PreviewConfiguration({
      "textureId": 7,
      "targetRotation": 6,
      "height": 5,
      "width": 4,
      "analysisWidth": 2,
      "analysisHeight": 1,
    });

    const expected1 = [1, 2, 3, 4, "5", 6, 7];
    const expected2 = [7, 6, 5, 4, "3", 2, 1];

    expect([
      config1.textureId,
      config1.targetRotation,
      config1.height,
      config1.width,
      config1.analysisResolution,
      config1.analysisWidth,
      config1.analysisHeight,
    ], expected1);

    expect([
      config2.textureId,
      config2.targetRotation,
      config2.height,
      config2.width,
      config2.analysisResolution,
      config2.analysisWidth,
      config2.analysisHeight,
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
      "analysisWidth": 6,
      "analysisHeight": 7,
    });

    final config2 = PreviewConfiguration({
      "textureId": 5,
      "targetRotation": 4,
      "height": 3,
      "width": 2,
      "analysisWidth": 0,
      "analysisHeight": -1,
    });

    final config1Copy = PreviewConfiguration({
      "textureId": 1,
      "targetRotation": 2,
      "height": 3,
      "width": 4,
      "analysisWidth": 6,
      "analysisHeight": 7,
    });

    final config2Copy = PreviewConfiguration({
      "textureId": 5,
      "targetRotation": 4,
      "height": 3,
      "width": 2,
      "analysisWidth": 0,
      "analysisHeight": -1,
    });

    expect(config1, config1);
    expect(config2, config2);
    expect(config1, isNot(equals(config2)));
    expect(config1, config1Copy);
    expect(config2, config2Copy);
  });
}
