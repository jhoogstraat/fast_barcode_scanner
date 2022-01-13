enum ScanningOverlayType {
  none,
  materialOverlay,
  codeBoundaryOverlay,
  blurPreview,
}

class ScanningOverlayConfig {
  final List<ScanningOverlayType> availableOverlays;
  final ScanningOverlayType? enabledOverlay;

  ScanningOverlayConfig({
    required this.availableOverlays,
    required this.enabledOverlay,
  });

  ScanningOverlayConfig copyWith(
      {List<ScanningOverlayType>? availableOverlays,
      ScanningOverlayType? enabledOverlay}) {
    return ScanningOverlayConfig(
      availableOverlays: availableOverlays ?? this.availableOverlays,
      enabledOverlay: enabledOverlay ?? this.enabledOverlay,
    );
  }
}
