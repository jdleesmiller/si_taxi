require 'mkmf'

SI_TAXI_DIR = File.expand_path(File.join(File.dirname(__FILE__),'si_taxi'))
SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Coverage')
#SI_TAXI_LIB = File.join(SI_TAXI_DIR, 'Debug')

# CPP = C PreProcessor by default; we need to find a C++ header.
Config::CONFIG['CPP'] = 'g++ -E'

# Need to load C++ standard header.
$LIBS += " -lstdc++"

# For coverage:
$LIBS += " -lgcov"

# More machine-specific code... have to do something about this.
BOOST_DIRS = []
if File.exists?('/usr/local/include/boost-1_39/')
  BOOST_DIRS << '/usr/local/include/boost-1_39/'
end

find_header('boost/config.hpp', *BOOST_DIRS) or raise 
find_header('si_taxi/si_taxi.h', SI_TAXI_DIR) or raise "couldn't find si_taxi.h"
find_library('si_taxi', 'si_taxi_hello_world', SI_TAXI_LIB) or
  raise 'could not find libsi_taxi.a'

create_makefile("si_taxi_ext")

