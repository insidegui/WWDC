Pod::Spec.new do |s|
  s.name             = "WWDCPlayer"
  s.version          = "1.0.0"
  s.summary          = "Video player for WWDC"
  s.homepage         = "https://github.com/insidegui/WWDC"
  s.license          = 'BSD'
  s.author           = { "Guilherme Rambo" => "eu@guilhermerambo.me" }
  s.source           = { :path => '.' }
  s.social_media_url = 'https://twitter.com/_inside'
  s.requires_arc = true
  
  s.osx.deployment_target = "10.10"

  s.source_files = 'WWDCPlayer/*.{swift}'
  s.resources = 'WWDCPlayer/Resources/*'
end
