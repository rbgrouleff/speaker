require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "pry"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :console do
  require 'speaker'
  Pry.start
end

file 'foo.o' => ['foo.c'] do |t|
  sh "clang -Wall -c #{t.prerequisites.join(' ')}"
end

file 'libfoo.dylib' => ['foo.o'] do |t|
  sh "clang -framework AudioUnit -dynamiclib -o #{t.name} #{t.prerequisites.join(' ')}"
end

desc "Building the foo library"
task :build_lib => 'libfoo.dylib'
