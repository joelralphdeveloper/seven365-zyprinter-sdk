require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'Seven365Zyprinter'
  s.version = package['version']
  s.summary = package['description']
  s.license = package['license']
  s.homepage = package['repository']['url']
  s.author = package['author']
  s.source = { :git => package['repository']['url'], :tag => s.version.to_s }
  # Source files include Swift and Objective-C source from ios/Sources
  s.source_files = 'ios/Sources/**/*.{swift,h,m,mm,c,cc,cpp}'
  s.ios.deployment_target = '14.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.1'
  
  # iOS system frameworks required for Zyprint functionality
  # CoreBluetooth for BLE, SystemConfiguration/CFNetwork for networking
  s.frameworks = 'CoreBluetooth', 'SystemConfiguration', 'CFNetwork'

  # Expose Zywell SDK public headers so consumers can import Objective-C APIs
  s.public_header_files = 'ios/Sources/zywell/ZywellSDK/**/*.h'
  
  # Uncomment when you add the Zywell SDK framework:
  # s.vendored_frameworks = 'Frameworks/ZywellPrinter.xcframework'
end
