Gem::Specification.new do |s|

  s.name            = 'logstash-input-intercom'
  s.version         = '0.0.1'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Experimental Logstash input plugin for Intercom API."
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Cogniteev"]
  s.email           = 'techteam@cogniteev.com'
  s.homepage        = "http://www.elastic.co/guide/en/logstash/current/index.html"
  s.require_paths   = ["lib"]
  s.platform        = "java"

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','Gemfile','LICENSE']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash-core-plugin-api', '~> 1.0'
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'cogniteev-intercom', '~> 2.3'

end
