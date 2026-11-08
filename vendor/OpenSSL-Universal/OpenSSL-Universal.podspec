Pod::Spec.new do |s|
  s.name         = "OpenSSL-Universal"
  s.version      = "3.6.2000"
  s.summary      = "OpenSSL for iOS, macOS, tvOS, visionOS, watchOS"
  s.homepage     = "https://github.com/krzyzanowskim/OpenSSL"
  s.license      = { :type => 'Apache License, Version 2.0' }
  s.source       = { :git => "https://github.com/krzyzanowskim/OpenSSL.git", :tag => s.version.to_s }
  s.authors      = { 'OpenSSL' => 'openssl@openssl.org' }
  s.requires_arc = true
  s.cocoapods_version = '>= 1.9'
  s.ios.deployment_target = "12.0"
  s.osx.deployment_target = "10.15"
  s.tvos.deployment_target = "12.0"
  s.visionos.deployment_target = "1.0"
  s.watchos.deployment_target = "8.0"
  s.vendored_frameworks = "OpenSSL.xcframework"
end
