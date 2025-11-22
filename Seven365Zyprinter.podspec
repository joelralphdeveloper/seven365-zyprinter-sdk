Pod::Spec.new do |s|
  s.name = 'Seven365Zyprinter'
  s.version = '0.0.1'
  s.summary = 'Capacitor plugin for Zywell/Zyprint thermal printer integration'
  s.license = 'MIT'
  s.homepage = 'https://github.com/Seven365-Pte-Ltd/plateful-pos-mobile'
  s.author = 'joelralph'
  s.source = { :git => 'https://github.com/Seven365-Pte-Ltd/plateful-pos-mobile', :tag => s.version.to_s }
  s.source_files = 'ios/Sources/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.exclude_files = 'ios/Sources/sources/POSWIFIManagerAsync.{h,m}'
  s.ios.deployment_target  = '14.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.1'
  
  # Framework dependencies
  s.frameworks = 'CoreBluetooth', 'SystemConfiguration', 'CFNetwork'
  
  # Public headers for Objective-C SDK - expose to Swift
  s.public_header_files = 'ios/Sources/sources/**/*.h'

  
  # Explicitly disable bridging header (not supported in frameworks)
  s.pod_target_xcconfig = {
    'SWIFT_OBJC_BRIDGING_HEADER' => '',
    'DEFINES_MODULE' => 'YES'
  }
end
