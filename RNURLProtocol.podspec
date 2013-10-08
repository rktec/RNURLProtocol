Pod::Spec.new do |s|
  s.name     = 'RNURLProtocol'
  s.version  = '0.2.0'
  s.platform = :ios
  s.license  = 'MIT'
  s.summary  = 'A drop-in solution of caching for NSURLConnection (including UIWebView and more)'
  s.homepage = 'https://github.com/rktec/RNURLProtocol'
  s.author   = { 'Rakuraku Jyo' => 'jyo.rakuraku@gmail.com' }
  s.source   = { :git => 'https://github.com/rktec/RNURLProtocol.git', :tag => '0.2.0' }
  s.description = 'A drop-in solution of caching for NSURLConnection (including UIWebView and more)'
  s.source_files = 'RNURLProtocol.{h,m}'
  s.requires_arc = true
  s.dependency 'ISDiskCache'
end
