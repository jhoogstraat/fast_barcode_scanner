enum ScanningOverlayType {
  none,
  materialOverlay,
  codeBoundaryOverlay,
  blurPreview,
}

class ScanningOverlayConfig {
  final List<ScanningOverlayType> availableOverlays;
  final List<ScanningOverlayType> enabledOverlays;

  ScanningOverlayConfig({
    required this.availableOverlays,
    required this.enabledOverlays,
  });

  ScanningOverlayConfig copyWith(
      {List<ScanningOverlayType>? enabledOverlays}) {
    return ScanningOverlayConfig(
      availableOverlays: availableOverlays,
      enabledOverlays: enabledOverlays ?? this.enabledOverlays,
    );
  }
}
