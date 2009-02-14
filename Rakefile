
require 'rubygems'

require 'hoe'
require 'rake'
require 'rake/clean'
require 'rake/rdoctask'
require 'spec/rake/spectask'

require 'lib/ascii85.rb'


# rspec

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ["--color"]
end

desc "Show specdoc"
Spec::Rake::SpecTask.new('specdoc') do |t|
  t.spec_opts = ["--color", "--format=specdoc"]
end


# Hoe

Hoe.new('Ascii85', Ascii85::VERSION) do |p|
  p.author  = "Johannes Holzfuß"
  p.email   = "Drangon@gmx.de"
  p.summary = "Ascii85 encoder/decoder"

  p.description = "Provides methods to encode/decode Adobe's Ascii85. " +
                  "(see en.wikipedia.org/wiki/Ascii85)"

  p.remote_rdoc_dir = ''

  p.testlib    = "spec"
  p.test_globs = "spec/ascii85_spec.rb"
end


# default task is spec
task :default => :spec
