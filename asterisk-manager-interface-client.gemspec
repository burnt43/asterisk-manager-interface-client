Gem::Specification.new do |s|
  s.name        = 'asterisk-manager-interface-client'
  s.version     = '0.0.1'
  s.summary     = ''
  s.description = ''
  s.authors     = ['James Carson']
  s.email       = 'jms.crsn@gmail'
  s.homepage    = 'http://tmpurl.com'
  s.files       = ['lib/asterisk-manager-interface-client.rb']
  s.license     = 'MIT'
  s.add_runtime_dependency 'active_support/inflector'
  s.add_runtime_dependency 'hashie'
  s.add_runtime_dependency 'socket'
end