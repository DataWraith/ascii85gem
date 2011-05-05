# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "Ascii85/version"

Gem::Specification.new do |s|
  s.name        = "Ascii85"
  s.version     = Ascii85::VERSION
  s.platform    = Gem::Platform::RUBY
  s.author      = "Johannes Holzfuß"
  s.email       = "DataWraith@web.de"
  s.license     = 'MIT'
  s.homepage    = "http://rubyforge.org/projects/ascii85/"
  s.summary     = %q{Ascii85 encoder/decoder}
  s.description = %q{Ascii85 provides methods to encode/decode Adobe's binary-to-text encoding of the same name.}

  s.rubyforge_project = "Ascii85"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "rspec",   ">= 2.4.0"

  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths    = ["lib"]
  s.extra_rdoc_files = ['README.rdoc']
end
