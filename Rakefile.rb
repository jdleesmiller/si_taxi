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

$rakefile_dir = File.dirname(__FILE__)
CLOBBER.include('ext/*{.o,.so,.log,.cxx}')
CLOBBER.include('ext/si_taxi/{Debug,Coverage,Profile,Release}')
CLOBBER.include('ext/si_taxi/si_taxi/stdafx.h.gch')
CLOBBER.include(%w(ext/Makefile))
CLOBBER.include('lcov')

def num_processors
  n = ENV['NUMBER_OF_PROCESSORS'];
  return n.to_i if n
  File.new('/proc/cpuinfo').readlines.select{|l| l =~ /processor\s*:/}.size
end

SI_TAXI_DIR = File.expand_path(File.join($rakefile_dir, 'ext', 'si_taxi'))

#
# SWIG
#
SI_TAXI_WRAP = 'ext/siTaxi_wrap.cxx'
SI_TAXI_WRAP_DEPS = Dir['ext/*.i'] + Dir["ext/**/*.h"]
file SI_TAXI_WRAP => SI_TAXI_WRAP_DEPS do |t|
  Dir.chdir('ext') do
    sh "swig -Wall -c++ -ruby -I#{SI_TAXI_DIR} siTaxi.i"
  end
end

SWIG_EXT_DEPS = Dir["ext/**/*.cpp}"] + ['ext/extconf.rb', SI_TAXI_WRAP]
desc 'generate wrapper with swig'
task :ext, [:args] => SWIG_EXT_DEPS do |t, args|
  args = args[:args] || ''
  # HACK: save typing...
  if `uname -n`.chomp == 'enm-jdlm'
    args += ' --with-boost=/usr/local/include/boost-1_39'
  end
  Dir.chdir('ext') do
    ruby "extconf.rb #{args}"
    sh "make -j#{num_processors}"
  end
end

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

desc 'generate coverage report'
task 'lcov:capture' do
  mkdir_p 'lcov' 
  Dir.chdir('lcov') do
    sh "lcov --directory #{LCOV_DIR} --base-directory #{LCOV_BASE_DIR}"\
         " --capture --output-file ext.info"
    sh "genhtml ext.info"
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

desc 'build libsi_taxi'
task 'eclipse:build' do
  si_taxi_project = File.join(File.expand_path('.'), 'ext', 'si_taxi')
  # note that eclipse must be on the PATH
  sh "eclipse -nosplash"\
    " -application org.eclipse.cdt.managedbuilder.core.headlessbuild"\
    " -import #{si_taxi_project}"\
    " -build si_taxi"
end

task :default => :test
