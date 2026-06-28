Pod::Spec.new do |s|
  s.name             = 'qrpay_sdk_ios'
  s.version          = '0.0.1'
  s.summary          = 'iOS implementation of qrpay_sdk.'
  s.description      = <<-DESC
iOS implementation of qrpay_sdk.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'
  s.frameworks = 'AVFoundation', 'Vision'

  # NOTE: The host app MUST declare these in its ios/Runner/Info.plist:
  # <key>NSCameraUsageDescription</key>
  # <string>Camera access is required to scan QR codes.</string>
  # <key>NSLocationWhenInUseUsageDescription</key>
  # <string>Location access is required to tag scans.</string>

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
