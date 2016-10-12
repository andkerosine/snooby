# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name     = 'snooby'
  gem.version  = '0.1.5'
  gem.licenses = ['GPL-3.0']
  gem.authors  = ["Donnie Akers"]
  gem.email    = ["andkerosine@gmail.com"]
  gem.homepage = "https://github.com/ankerosine/snooby"
  gem.summary  = "Snooby wraps the reddit API in happy, convenient Ruby."

  gem.files         = `git ls-files`.split($/)
  gem.require_paths = ['lib']

  gem.required_ruby_version = '>= 1.9.3'

  gem.add_runtime_dependency('json', '~> 2.0')
  gem.add_runtime_dependency('net-http-persistent', '>= 2.5')
end
