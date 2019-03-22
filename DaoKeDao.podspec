Pod::Spec.new do |s|
    s.name             = "DaoKeDao"
    s.version          = "0.0.2"
    s.summary          = "The message module for DIM."
    s.homepage         = "https://github.com/Ceezy/dkd-objc"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { "Ceezy Chen" => "ceezychen@gmail.com" }
    s.source           = { :git => "https://github.com/Ceezy/dkd-objc.git", :tag => s.version }
#    s.social_media_url = ''

    s.platform     = :ios, '11.0'

    s.public_header_files = 'Classes/DaoKeDao.h'
    s.source_files = 'Classes/DaoKeDao.h'

    s.frameworks = 'Foundation'

    s.subspec 'extends' do |ss|
        ss.source_files = 'Classes/extends/*.{h,m}'
    end

    s.subspec 'types' do |ss|
        ss.source_files = 'Classes/types/*.{h,m}'
        ss.public_header_files = 'Classes/types/*.h'
	ss.dependency 'DaoKeDao/extends'
    end

    s.subspec 'message' do |ss|
        ss.source_files = 'Classes/message/*.{h,m}', 'Classes/content/*.{h,m}'
        ss.public_header_files = 'Classes/message/*.h', 'Classes/content/*.h'
	ss.dependency 'DaoKeDao/extends'
	ss.dependency 'DaoKeDao/types'
    end
end
