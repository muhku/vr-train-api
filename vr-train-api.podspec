Pod::Spec.new do |s|
	s.name                  = 'vr-train-api'
	s.version               = '1.0.1'
	s.license               = 'BSD'
	s.summary               = 'Finnish Railways (vr.fi) train data API for iOS and OS X applications'
	s.homepage              = 'https://github.com/muhku/vr-train-api'
	s.author                = { 'Matias Muhonen' => 'mmu@iki.fi' }
	s.source                = { :git => 'https://github.com/muhku/vr-train-api.git', :tag => s.version.to_s }
	s.ios.deployment_target = '6.0'
	s.osx.deployment_target = '10.7'
	s.source_files          = 'LibTrainSpot/*.{h,m}'
        s.resources             = 'LibTrainSpot/*.txt'
	s.libraries	        = 'xml2'
	s.ios.frameworks        = 'MapKit', 'CoreLocation'
	s.xcconfig              = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
	s.requires_arc          = true
end
