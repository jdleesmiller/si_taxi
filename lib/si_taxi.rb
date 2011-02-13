require 'facets/array/product'
require 'facets/enumerable/sum'
require 'facets/enumerable/mash'
require 'facets/hash/slice'
require 'facets/kernel/disable_warnings'

disable_warnings do # gives one annoying warning
  require 'narray'
end

# When the gem is loaded with bundler, we get an SiTaxi constant defined, which
# causes a warning when we remap it to Si_taxi_ext below; it would be better to
# fix it so that the module was called SiTaxi, but I haven't been able to get
# that working.
Object.instance_eval { remove_const :SiTaxi if const_defined? :SiTaxi }

# Load extension module as SiTaxi before doing anything else.
require 'si_taxi_ext'
SiTaxi = Si_taxi_ext

require 'si_taxi/version'
require 'si_taxi/utility'
require 'si_taxi/abstract_networks'
require 'si_taxi/bell_wong'
require 'si_taxi/lp_solve'
require 'si_taxi/fluid_limit'
require 'si_taxi/natural_histogram'

module SiTaxi
  #
  # Try to get a stack trace if the extension segfaults.
  #
  SiTaxi.register_sigsegv_handler

  # A suitable (random) int seed.
  def rand_seed
    rand(0x7fffffff)
  end

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

  #
  # Cartesian product of Enumerables.
  #
  # @return [Array<Array>] the product
  #
  def cartesian_product *enums
    if enums.empty?
      nil
    else
      enums.first.product(*enums.drop(1))
    end
  end
  
  #
  # Array of hashes with one for each entry in the Cartesian product of the
  # Array-valued values of h.
  #
  # Example:
  #  hash_cartesian_product({:a=>[1,2], :b => 1})
  # gives
  #  [{:a => 1, :b => 1}, {:a => 2, :b => 1}]
  #
  def hash_cartesian_product h
    multi_valued_keys = h.keys.select {|k| h[k].is_a? Array}
    multi_valued_vals = multi_valued_keys.map {|k| h[k]}

    result = []
    (cartesian_product(*multi_valued_vals) || [[]]).each do |arg|
      a = h.dup
      multi_valued_keys.zip(arg).each do |k, arg_k|
        a[k] = arg_k
      end
      result << a
    end
    result
  end

  #
  # Return nil if x is NaN (not a number).
  #
  # @return [Float, nil]
  #
  def self.nil_if_nan x
    x unless x.nan?
  end
end

