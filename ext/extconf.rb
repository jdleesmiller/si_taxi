require 'mkmf'

# Note that you currently have to set this in the Rakefile and Eclipse, too.
COVERAGE = !!ENV['SI_TAXI_COVERAGE']

SI_TAXI_DIR = File.expand_path(File.join(File.dirname(__FILE__),'si_taxi'))
if COVERAGE
  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Coverage')
else
  SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Debug')
end

# CPP = C PreProcessor by default; we need to find a C++ header.
Config::CONFIG['CPP'] = 'g++ -E'

# Need to load C++ standard header.
$LIBS += " -lstdc++"
$LIBS += " -lgcov" if COVERAGE

# More machine-specific code... have to do something about this.
BOOST_DIRS = []
if File.exists?('/usr/local/include/boost-1_39/')
  $INCFLAGS << " " << "-I/usr/local/include/boost-1_39".quote

  # this finds the system header (old version of boost); probably could devise
  # a test that would fail, so it would look at BOOST_DIRS; maybe one day
  #BOOST_DIRS << '/usr/local/include/boost-1_39/'
  #find_header('boost/config.hpp', *BOOST_DIRS) or raise "missing boost"
end

find_header('si_taxi/si_taxi.h', SI_TAXI_DIR) or raise "missing si_taxi.h"
find_library('si_taxi', 'si_taxi_hello_world', SI_TAXI_LIB) or
  raise 'could not find libsi_taxi.a'

create_makefile("si_taxi_ext")

