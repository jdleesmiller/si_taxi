#
# USAGE
#
# ruby extconf.rb [--with-boost=<path>] [--debug|--coverage]
#
# --with-boost: path to the boost includes (e.g. /usr/local/include/boost-1_39/)
# --debug: build only the debug extension
# --coverage: build only the coverage extension
#
require 'mkmf'
require 'getoptlong'

boost_inc = nil
target = 'Release'
getopt = GetoptLong.new(
  ['--with-boost', '-b', GetoptLong::REQUIRED_ARGUMENT],
  ['--debug', '-d', GetoptLong::NO_ARGUMENT],
  ['--coverage', '-c', GetoptLong::NO_ARGUMENT])
getopt.each do |opt, arg|
  case opt
  when '--with-boost' then
    boost_inc = arg
  when '--debug' then
    target = 'Debug'
  when '--coverage' then
    target = 'Coverage'
  else
    raise "unknown option #{opt}"
  end
end

# Note that you currently have to set this in the Rakefile and Eclipse, too.
#COVERAGE = !!ENV['SI_TAXI_COVERAGE']

SI_TAXI_DIR = File.expand_path(File.join(File.dirname(__FILE__),'si_taxi'))
#if COVERAGE
#  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Coverage')
#else
#  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Debug')
#end

# need to load C++ standard header; CPP = C PreProcessor by default
Config::CONFIG['CPP'] = 'g++ -E'
$LIBS += " -lstdc++"

# need gcov for a coverage build
$LIBS += " -lgcov" if target == 'Coverage'

# if we were given a boost path, just use it; otherwise, look for one
if boost_inc
  $INCFLAGS << "-I#{boost_inc}".quote
else
  find_header('boost/config.hpp') or raise "missing boost"
end

# More machine-specific code... have to do something about this.
#BOOST_DIRS = []
#if File.exists?('/usr/local/include/boost-1_39/')
#  $INCFLAGS << " " << "-I/usr/local/include/boost-1_39".quote
#
#  # this finds the system header (old version of boost); probably could devise
#  # a test that would fail, so it would look at BOOST_DIRS; maybe one day
#  #BOOST_DIRS << '/usr/local/include/boost-1_39/'
#end

find_header('si_taxi/si_taxi.h', SI_TAXI_DIR) or raise "missing si_taxi.h"

si_taxi_lib = File.join(SI_TAXI_DIR, target)
find_library('si_taxi', 'si_taxi_hello_world', si_taxi_lib) or
  raise 'could not find libsi_taxi.a'

create_makefile("si_taxi_ext")

