/// Indicates the current state the camera is in.
///
/// Part of the [ScannerState].
enum ScannerEvent {
  /// The scanner is not loaded.
  ///
  /// If in this state, calling [initialize] is required, before
  /// the scanner can be used.
  uninitialized,

  /// The scanner is active, but scanning is paused.
  ///
  ///
  paused,

  /// The scanner is active and running.
  ///
  ///
  resumed,

  /// The scanner has detected a [Barcode] and is awaiting user interaction.
  ///
  /// To resume scanning, call [CameraController.resumeCamera].
  detected,

  /// The scanner has encountered an error and is stopped consequently.
  ///
  /// [initialize] or [start] might be called again to retry.
  error,
}
