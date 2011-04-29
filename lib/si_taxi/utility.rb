module SiTaxi::Utility
  module_function

  #
  # One way to encode a sparse matrix is as a hash of hashes; another way is to
  # use an array of arrays. This method orders the keys of +h+ in order to
  # produce the array-of-arrays matrix; this is perhaps best illustrated with an
  # example.
  #
  # Example:
  #  h = {'a'=>{'a'=>1, 'c'=>3}, 'b'=>{'a'=>4, 'b'=>5, 'c'=>6}, 'c'=>{'b'=>8}}
  # is converted to
  #  [[1, z, 3],
  #   [4, 5, 6],
  #   [z, 8, z]]
  # where +z+ is used where an element is missing. Note that the keys in +h+
  # will usually be numeric, denoting rows and columns of the sparse matrix.
  #
  def hash_of_hashes_to_array_of_arrays h, z=nil
    ks = h.keys.sort
    ks.map{|k0| ks.map{|k1| h[k0][k1] || z}}
  end

  #
  # Cycle through all possible arrays with entries less than the given maxima;
  # this modifies +array+ so that it is the next value in the sequence.
  #
  # @param [Array<Integer>] array modified in place
  # @param [Integer, Array<Integer>] array_max maximum for each entry in array
  #
  # @return [Boolean]
  #
  def spin_array array, array_max
    if array_max.is_a? Array
      for i in 0...(array.size)
        array[i] += 1
        if array[i] <= array_max[i] then
          return true
        else
          array[i] = 0
        end
      end
      return false
    else
      for i in 0...(array.size)
        array[i] += 1
        if array[i] <= array_max then
          return true
        else
          array[i] = 0
        end
      end
      return false
    end
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
  def nil_if_nan x
    x unless x.nan?
  end

  #
  # Random sample from cumulative distribution function. This uses a binary
  # search, so it is reasonably efficient when +cdf+ is long.
  #
  # @param [Array<Float>] cdf in ascending order with last value >= 1.0
  #
  # @param [Float] r random value to use; must be in (0, 1]; if omitted, a
  #        random value is generated using Kernel::rand
  #
  def sample_cdf cdf, r=1-rand
    lower = -1
    upper = cdf.size
    while upper - lower > 1
      mid = (lower + upper) / 2
      if cdf[mid] < r
	lower = mid
      else 
	upper = mid
      end
    end
    return upper
  end
end

