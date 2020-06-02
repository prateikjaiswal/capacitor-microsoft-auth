
  Pod::Spec.new do |s|
    s.name = 'CapacitorMicrosoftAuth'
    s.version = '0.0.1'
    s.summary = 'Capacitor plugin for Microsoft Authentication'
    s.license = 'MIT'
    s.homepage = 'https://github.com/prateikjaiswal/capacitor-microsoft-auth.git'
    s.author = 'Pratik Jaiswal'
    s.source = { :git => 'https://github.com/prateikjaiswal/capacitor-microsoft-auth.git', :tag => s.version.to_s }
    s.source_files = 'ios/Plugin/**/*.{swift,h,m,c,cc,mm,cpp}'
    s.ios.deployment_target  = '11.0'
    s.dependency 'Capacitor'
    s.dependency 'MSAL'
  end
