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
  # this modifies +array+ so that it is the next value in the sequence. This is
  # a successor function for mixed-radix integers.
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
  # Enumerator over all numbers with the given (mixed) radices.
  #
  def mixed_radix_sequence radices
    array = [0] * radices.size
    Enumerator.new {|y|
      begin 
        y << array.dup
      end while spin_array(array, radices)
    }
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
  # All permutations of +length+ non-negative integers that add to +sum+. 
  #
  # @param [Integer] sum non-negative
  # @param [Integer] length positive
  #
  def integer_partitions sum, length
    if sum == 0 || length <= 1
      [[sum]*length]
    else
      (0..sum).map {|i|
        integer_partitions(sum-i, length-1).map{|s| [i] + s}
      }.flatten(1)
    end
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
  # @param [Enumerable] a all elements comparable
  #
  # @return [Boolean] true iff +a+ is sorted in non-descending order
  #
  def is_nondescending? a
    prev, *a = a
    for curr in a
      return false if prev > curr
      prev = curr
    end
    return true
  end
end

