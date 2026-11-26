#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fast_barcode_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fast_barcode_scanner'
  s.version          = '2.0.0'
  s.summary          = 'A fast barcode scanner using ML Kit on Android and AVFoundation/Vision on iOS.'
  s.description      = <<-DESC
A fast barcode scanner using ML Kit and CameraX on Android, and AVFoundation and Vision on iOS.
                       DESC
  s.homepage         = 'https://github.com/jhoogstraat/fast_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Joshua Hoogstraat' => 'https://github.com/jhoogstraat' }
  s.source           = { :path => '.' }
  s.source_files     = 'fast_barcode_scanner/Sources/fast_barcode_scanner/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
  s.resource_bundles = {
    'fast_barcode_scanner_privacy' => [
      'fast_barcode_scanner/Sources/fast_barcode_scanner/PrivacyInfo.xcprivacy'
    ]
  }
end
