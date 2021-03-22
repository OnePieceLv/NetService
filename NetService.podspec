Pod::Spec.new do |s|
  s.name         = "NetService"
  s.version      = "1.0.3"
  s.summary      = "NetService is an HTTP client library written in Swift."
  s.homepage     = "https://github.com/OnePieceLv/NetService"
  s.license      = {:type =>"MIT", :file => "LICENSE"}
  s.author             = { "steven lv" => "steven.suzhou@gmail.com" }
  s.swift_version = "5.0"
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.15"
  s.source       = { :git => "https://github.com/OnePieceLv/NetService.git", :tag => "#{s.version}" }
  s.source_files  = "NetService", "NetService/**/*.{h,m,swift}"
  s.frameworks = "Foundation"
end
