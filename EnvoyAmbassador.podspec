Pod::Spec.new do |spec|
  spec.name         = 'dariancamposasfAmbassador'
  spec.version      = '0.0.1-alpha-3'
  spec.summary      = 'Lightweight web framework in Swift based on SWSGI for iOS UI Automatic testing data mocking'
  spec.homepage     = 'https://github.com/envoy/Ambassador'
  spec.license      = 'MIT'
  spec.license      = { type: 'MIT', file: 'LICENSE' }
  spec.author             = { 'Victor' => 'victor@envoy.com' }
  spec.social_media_url   = 'http://twitter.com/victorlin'
  spec.platform     = :ios, '8.0'
  spec.source       = {
    git: 'https://github.com/dariancamposasf/Ambassador.git',
    tag: 'v0.0.1-alpha-3'
  }
  spec.source_files = 'Ambassador/*.swift', 'Ambassador/**/*.swift'
  spec.dependency 'Embassy', '~> 3.0'
end
