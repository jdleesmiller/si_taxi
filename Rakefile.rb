require 'rake/clean'

begin
  require 'rubygems'
  require 'bundler/setup'
  require 'gemma'

  Gemma::RakeTasks.with_gemspec_file 'si_taxi.gemspec' do |g|
#    g.test.with_test_task do |tt|
#      tt.warning = false
#    end
  end
rescue LoadError
  puts 'Install gemma (sudo gem install gemma) for more rake tasks.'
end

# Note that you currently have to set this in extconf.rb and Eclipse, too.
COVERAGE = !!ENV['SI_TAXI_COVERAGE']

$rakefile_dir = File.dirname(__FILE__)
CLOBBER.include('ext/*{.o,.so,.log,.cxx}')
CLOBBER.include('ext/si_taxi/{Debug,Coverage,Release}')
CLOBBER.include('ext/si_taxi/si_taxi/stdafx.h.gch')
CLOBBER.include(%w(ext/Makefile))
CLOBBER.include('lcov')

def num_processors
  n = ENV['NUMBER_OF_PROCESSORS'];
  return n.to_i if n
  File.new('/proc/cpuinfo').readlines.select{|l| l =~ /processor\s*:/}.size
end

SI_TAXI_DIR = File.expand_path(File.join($rakefile_dir, 'ext', 'si_taxi'))
if COVERAGE
  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Coverage', 'libsi_taxi.a')
else
  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Debug', 'libsi_taxi.a')
end

#
# SWIG
#
SI_TAXI_WRAP = 'ext/si_taxi_ext_wrap.cxx'
SI_TAXI_WRAP_DEPS = Dir['ext/*.i'] + Dir["ext/**/*.h"]
file SI_TAXI_WRAP => SI_TAXI_WRAP_DEPS do |t|
  Dir.chdir('ext') do
    sh "swig -Wall -c++ -ruby -I#{SI_TAXI_DIR} si_taxi_ext.i"
  end
end

SWIG_EXT = "ext/si_taxi_ext.#{Config::CONFIG['DLEXT']}"
SWIG_EXT_DEPS = Dir["ext/**/*.cpp}"] +
  ['ext/extconf.rb', SI_TAXI_WRAP, SI_TAXI_LIB]
desc "run extconf to build"
file SWIG_EXT => SWIG_EXT_DEPS do |t|
  Dir.chdir('ext') do
    ruby "extconf.rb"
    sh "make -j#{num_processors}"
  end
end

desc 'generate wrapper with swig'
task :swig => SWIG_EXT 

# note: this doesn't seem to work in lcov 1.8; works with lcov 1.9, though
LCOV_DIR = '../ext'
LCOV_BASE_DIR = '../ext/si_taxi/Coverage/'

desc 'zero coverage counters'
task 'lcov:zero' do
  mkdir_p 'lcov' 
  Dir.chdir('lcov') do
    sh "lcov --directory #{LCOV_DIR} --zerocounters"
  end
end

# NOTE: to avoid lots of spurious leaks, it should be possible to install 
# ruby with
#   rvm install 1.9.2 -C --with-valgrind
# but I haven't actually seen this work (still get lots of spurious leaks)
desc 'run tests under valgrind'
task 'test:valgrind' do
  sh "valgrind --partial-loads-ok=yes --undef-value-errors=no rake test"
end

desc 'generate coverage report'
task 'lcov:capture' do
  mkdir_p 'lcov' 
  Dir.chdir('lcov') do
    sh "lcov --directory #{LCOV_DIR} --base-directory #{LCOV_BASE_DIR}"\
         " --capture --output-file ext.info"
    sh "genhtml ext.info"
  end
end

task :default => :test
