platform :ios, '15.0'
use_frameworks! :linkage => :static

target 'CarAutoPad' do
  local_framework = File.expand_path('vendor/OpenSSL-Universal/OpenSSL.xcframework', __dir__)
  if Dir.exist?(local_framework)
    pod 'OpenSSL-Universal', :path => 'vendor/OpenSSL-Universal'
  else
    pod 'OpenSSL-Universal', '~> 3.6'
  end
end