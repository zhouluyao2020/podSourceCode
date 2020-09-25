#
# Be sure to run `pod lib lint podSourceCode.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'podSourceCode'
  s.version          = '0.1.1'
  s.summary          = 'A short description of podSourceCode.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'git remote add origin https://github.com/zhouluyao2020/podSourceCode.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '437001178@qq.com' => 'zly77153@offcn.com' }
  s.source           = { :git => 'https://github.com/zhouluyao2020/podSourceCode.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'podSourceCode/Classes/**/*'
  
  # s.resource_bundles = {
  #   'podSourceCode' => ['podSourceCode/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  s.dependency 'AFNetworking', '~> 3.1.0'
  s.dependency 'YYKit', '~> 1.0.9'
  s.dependency 'FMDB', '~> 2.5'
  s.dependency 'M3U8Kit', '~> 0.4.0'
end
