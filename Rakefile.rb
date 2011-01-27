require 'rake/clean'

begin
  require 'rubygems'
  require 'gemma'

  Gemma::RakeTasks.with_gemspec_file 'si_taxi.gemspec'
rescue LoadError
  puts 'Install gemma (sudo gem install gemma) for more rake tasks.'
end

$rakefile_dir = File.dirname(__FILE__)
CLOBBER.include('ext/*{.o,.so,.log,.cxx}')
CLOBBER.include('ext/si_taxi/Debug')
CLOBBER.include(%w(ext/Makefile))

def num_processors
  n = ENV['NUMBER_OF_PROCESSORS'];
  return n.to_i if n
  File.new('/proc/cpuinfo').readlines.select{|l| l =~ /processor\s*:/}.size
end

SI_TAXI_DIR = File.expand_path(File.join($rakefile_dir, 'ext', 'si_taxi'))
SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Debug', 'libsi_taxi.a')

#
# SWIG
#
SI_TAXI_WRAP = 'ext/si_taxi_ext_wrap.cxx'
SI_TAXI_WRAP_DEPS = Dir['ext/*.i'] + Dir["ext/**/*.h"]
file SI_TAXI_WRAP => SI_TAXI_WRAP_DEPS do |t|
  Dir.chdir('ext') do
    sh "swig -c++ -ruby -I#{SI_TAXI_DIR} si_taxi_ext.i"
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

task :default => :test
