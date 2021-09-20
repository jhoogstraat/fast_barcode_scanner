#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fast_barcode_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fast_barcode_scanner'
  s.version          = '0.0.1'
  s.summary          = 'A fast barcode scanner using ML Kit on Android and AVFoundation on iOS.'
  s.description      = <<-DESC
  A fast barcode scanner using ML Kit on Android and AVFoundation on iOS.
                       DESC
  s.homepage         = 'https://github.com/jhoogstraat/fast_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Joshua Hoogstraat' => 'https://github.com/jhoogstraat' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '10.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
