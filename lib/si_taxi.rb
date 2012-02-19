require 'facets/array/product'
require 'facets/enumerable/mash'
require 'facets/enumerable/purge'
require 'facets/enumerable/sum'
require 'facets/hash/mash'
require 'facets/hash/slice'
require 'facets/kernel/disable_warnings'
require 'facets/kernel/in'
disable_warnings do # gives one annoying warning
  require 'facets/set' # for power_set
end

disable_warnings do # gives one annoying warning
  require 'narray'
end

disable_warnings do # gives one annoying warning
  require 'hpricot'
end

# Load extension module before doing anything else.
require 'siTaxi'

require 'si_taxi/version'
require 'si_taxi/extensions'
require 'si_taxi/utility'
require 'si_taxi/abstract_networks'
require 'si_taxi/data_files'
require 'si_taxi/drawable_network'
require 'si_taxi/bell_wong'
require 'si_taxi/lp_solve'
require 'si_taxi/fluid_limit'
require 'si_taxi/natural_histogram'
require 'si_taxi/cross_entropy'

require 'si_taxi/mdp_model'
require 'si_taxi/mdp_model_a'
require 'si_taxi/mdp_model_b'
require 'si_taxi/mdp_model_c'
require 'si_taxi/mdp_sim'

module SiTaxi
  #
  # Try to get a stack trace if the extension segfaults.
  #
  SiTaxi.register_sigsegv_handler

  # A suitable (random) int seed.
  def rand_seed
    rand(0x7fffffff)
  end
  module_function :rand_seed

  #
  # The signum (sign) function.
  #
  # @param [Numeric] x
  #
  # @return [-1,0,1]
  #
  def signum x
    return -1 if x < 0
    return 1 if x > 0
    return 0
  end
  
  #
  # The range (x:step:y) from Matlab (the colon operator).
  # http://www.mathworks.com/support/solutions/data/1-4FLI96.html
  # It has been modified slightly so that it tries to use integer types (instead
  # of floating point types) if all of the range entries are integral.
  #
  def range *p
    a, d, b = nil
    if p.size == 2
      a, b = p
      d = 1
    else
      a, d, b = p
    end

    tol = 2.0*Float::EPSILON*[a.abs,b.abs].max;
    sig = signum(d)

    # exceptional cases
    # ignoring the infinite cases... breaks with Fixnums.
    #return [0.0/0.0] unless a.finite? && d.finite? && b.finite?
    return [] if d == 0 || a < b && d < 0 || b < a && d > 0

    # n = number of intervals = length(v) - 1.
    n = nil
    if a == a.floor && d == 1
      # Consecutive integers.
      n = b.floor - a;
    elsif a == a.floor && d == d.floor
      # Integers with spacing > 1.
      q = (a/d).floor;
      r = a - q*d;
      n = ((b-r)/d).floor - q;
    else
      # General case.
      n = ((b-a)/d).round;
      n -= 1 if sig*(a+n*d - b) > tol
    end

    # c = right hand end point.
    c = a + n*d;
    if sig*(c-b) > -tol
      c = b;
    end

    # v should be symmetric about the mid-point.
    v = Array.new(n+1, 0);
    for k in 0..(n/2).floor
      v[k] = a + k*d
      v[n-k] = c - k*d
    end
    if n % 2 == 0
      # Keep the mp as an integer if we can
      mp = (a+c)/2.0
      mp = mp.floor if mp.floor == mp && (a+c).is_a?(Fixnum)
      v[n / 2] = mp
    end

    return v
  end
end

