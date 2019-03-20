Pod::Spec.new do |s|
    s.name             = "DaoKeDao"
    s.version          = "0.0.1"
    s.summary          = "The message module for DIM."
    s.homepage         = "https://github.com/Ceezy/dkd-objc"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { "Ceezy Chen" => "ceezychen@gmail.com" }
    s.source           = { :git => "https://github.com/Ceezy/dkd-objc", :tag => s.version }
#    s.social_media_url = ''

    s.platform     = :ios, '11.0'
    s.requires_arc = 'Classes/**/*'

    s.public_header_files = 'Classes/DaoKeDao.h'
    s.source_files = 'Classes/DaoKeDao.h'

#    s.frameworks = 'UIKit', 'Foundation', 'AVFoundation', 'AdSupport'

    s.subspec 'content' do |ss|
        ss.source_files = 'Classes/content/*.{h,m}'
        ss.public_header_files = 'Classes/content/*.h'
    end

    s.subspec 'extends' do |ss|
        ss.source_files = 'Classes/extends/*.{h,m}'
        ss.public_header_files = 'Classes/extends/*.h'
    end

    s.subspec 'message' do |ss|
        ss.source_files = 'Classes/message/*.{h,m}'
        ss.public_header_files = 'Classes/message/*.h'
    end

    s.subspec 'types' do |ss|
        ss.source_files = 'Classes/types/*.{h,m}'
        ss.public_header_files = 'Classes/types/*.h'
    end
end
