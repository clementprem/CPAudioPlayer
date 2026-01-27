Pod::Spec.new do |s|
  s.name             = "CPAudioPlayer"
  s.version          = "1.0.0"
  s.summary          = "A modern audio player with 7-band EQ, effects, and SwiftUI support"
  s.description      = <<-DESC
                      CPAudioPlayer is a powerful audio player library built on Apple's Audio Units framework.

                      Features:
                      * 7-band parametric equalizer
                      * iPod-style EQ presets
                      * Bass boost, treble, reverb, and delay effects
                      * Channel balance (pan) control
                      * Modern SwiftUI view with customizable appearance
                      * UIKit view for compatibility
                      * Swift wrapper for easy integration
                      DESC
  s.homepage         = "https://github.com/clementprem/CPAudioPlayer"
  s.license          = 'MIT'
  s.author           = { "Clement Prem" => "clementprem@gmail.com" }
  s.source           = { :git => "https://github.com/clementprem/CPAudioPlayer.git", :tag => s.version.to_s }
  s.swift_version    = '5.0'

  s.platform     = :ios, '14.0'
  s.requires_arc = true

  # Source files - Objective-C and Swift
  s.source_files = 'Pod/Classes/**/*.{h,m,mm}', 'Pod/Classes/Swift/**/*.swift'

  s.public_header_files = 'Pod/Classes/*.h'
  s.frameworks = 'UIKit', 'AudioToolbox', 'AVFoundation'

  s.resource_bundles = {
    'CPAudioPlayer' => ['Pod/Assets/*.png']
  }
end
