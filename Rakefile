
require 'rubygems'

require 'rake'
require 'rake/clean'
require 'rake/rdoctask'
require 'spec/rake/spectask'

# rspec

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ["--color"]
end

desc "Show specdoc"
Spec::Rake::SpecTask.new('specdoc') do |t|
  t.spec_opts = ["--color", "--format=specdoc"]
end

# rdoc

desc "Generate documentation"
Rake::RDocTask.new do |rdoc|
  rdoc.title = "Ascii85"
  rdoc.rdoc_dir = 'doc/'
  rdoc.options += [
    '--charset=utf8',
    '--line-numbers',
  ]
  rdoc.rdoc_files.add(FileList['lib/**/*.rb'])
end

# default task is spec
task :default => :spec
