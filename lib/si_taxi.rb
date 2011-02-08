require 'facets/enumerable/sum'
require 'facets/kernel/disable_warnings'

# When the gem is loaded with bundler, we get an SiTaxi constant defined, which
# causes a warning when we remap it to Si_taxi_ext below; it would be better to
# fix it so that the module was called SiTaxi, but I haven't been able to get
# that working.
Object.instance_eval { remove_const :SiTaxi if const_defined? :SiTaxi }

# Load extension module as SiTaxi before doing anything else.
require 'si_taxi_ext'
SiTaxi = Si_taxi_ext

require 'si_taxi/version'
require 'si_taxi/bell_wong'
require 'si_taxi/fluid_limit'
require 'si_taxi/lp_solve'
require 'si_taxi/natural_histogram'

module SiTaxi
  #
  # Try to get a stack trace if the extension segfaults.
  #
  SiTaxi.register_sigsegv_handler
end

