enum ScanningOverlayType {
  none,
  materialOverlay,
  codeBoundaryOverlay,
  blurPreview,
}

class ScanningOverlayConfig {
  final List<ScanningOverlayType> availableOverlays;
  final ScanningOverlayType? enabledOverlay;

  ScanningOverlayConfig(this.availableOverlays, this.enabledOverlay);

  ScanningOverlayConfig copyWith(
      {List<ScanningOverlayType>? availableOverlays,
      ScanningOverlayType? enabledOverlay}) {
    return ScanningOverlayConfig(availableOverlays ?? this.availableOverlays,
        enabledOverlay ?? enabledOverlay);
  }
}
