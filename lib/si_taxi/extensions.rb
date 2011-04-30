#
# Extensions for Array.
#
class Array
  #
  # The cumulative sum (partial sum) of this array.
  #
  # @param sum value to start summing from
  #
  # @return [Array]
  #
  # @example
  #   [1,2,3].cumsum #=> [1,3,6]
  #
  def cumsum sum=0
    self.map{|x| sum += x}
  end unless method_defined?(:cumsum)
end

#
# Extensions for NArray.
#
# Note: cumsum and tile were merged into NArray on 25 April, 2011.
# 
class NArray
  #
  # Convert a linear (1D) index into subscripts for an array with the given
  # shape; this is the matlab function ind2sub.
  #
  # (TODO: There must be a function in NArray to do this, but I can't find it.)
  #
  # @param [Integer] index non-negative
  #
  # @return [Array<Integer>] subscript corresponding to the given linear index;
  #         this is the same size as {#shape}
  #
  def index_to_subscript index
    raise IndexError.new("out of bounds: index=#{index} for shape=#{
      self.shape.inspect}") if index >= self.size

    self.shape.map {|s| index, r = index.divmod(s); r }
  end

  #
  # Sample from an array that represents an empirical probability mass function
  # (pmf). It is assumed that this is an array of probabilities, and that the
  # sum over the whole array is one (up to rounding error). An index into the
  # array is chosen in proportion to its probability.
  #
  # @example select a subscript uniform-randomly
  #   NArray.float(3,3,3).fill!(1).div!(3*3*3).sample_pmf #=> [2, 2, 0]
  #
  # @param [NArray] r if you have already generated the random sample, you can
  #        pass it in here; if nil, a random sample will be generated; this is
  #        used for testing; must be have shape <tt>[1]</tt> if specified
  #
  # @return [Array<Integer>] subscripts of a randomly selected into the array;  
  #         this is the same size as {#shape}
  #
  def sample_pmf r=nil
    self.index_to_subscript(self.flatten.sample_pmf_dim(0, r))
  end

  #
  # Sample from an array in which the given dimension, +dim+, represents an
  # empirical probability mass function (pmf). It is assumed that the entries
  # along +dim+ are probabilities that sum to one (up to rounding error).
  #
  # @example a matrix in which dim 0 sums to 1
  #   NArray[[0.1,0.2,0.7],
  #          [0.3,0.5,0.2],
  #          [0.0,0.2,0.8],
  #          [0.7,0.1,0.2]].sample_pmf(1)
  #          #=> NArray.int(2) [ 1, 1, 2, 0 ] # random indices into dimension 1
  #
  # @param [Integer] dim dimension to sample along
  #
  # @param [NArray] r if you have already generated the random sample, you can
  #        pass it in here; if nil, a random sample will be generated; this is
  #        used for testing; see also sample_cdf_dim
  #
  # @return [NArray] integer subscripts 
  #
  def sample_pmf_dim dim=0, r=nil
    self.cumsum(dim).sample_cdf_dim(dim, r)
  end

  #
  # Sample from an array in which the given dimension, +dim+, represents an
  # empirical cumulative distribution function (cdf). It is assumed that the
  # entries along +dim+ are sums of probabilities, and that the last entry along
  # dim should be 1 (up to rounding error)
  #
  # @param [Integer] dim dimension to sample along
  #
  # @param [NArray] r if you have already generated the random sample, you can
  #        pass it in here; if nil, a random sample will be generated; this is
  #        used for testing; see also sample_cdf_dim
  #
  # @return [NArray] integer subscripts 
  #
  def sample_cdf_dim dim=0, r=nil
    raise 'self.dim must be > dim' unless self.dim > dim

    # generate random sample, unless one was given for testing
    r_shape = (0...self.dim).map {|i| i == dim ? 1 : self.shape[i]}
    r = NArray.new(self.typecode, *r_shape).random! unless r

    # allocate space for results -- same size as the random sample
    res = NArray.int(*r_shape)

    # for every other dimension, look for the first element that is over the
    # threshold
    nested_for_zero_to(r_shape) do |slice|
      r_thresh    = r[*slice]
      res[*slice] = self.shape[dim] - 1 # default to last
      self_slice = slice.dup
      for self_slice[dim] in 0...self.shape[dim]
        if r_thresh < self[*self_slice]
          res[*slice] = self_slice[dim]
          break
        end
      end
    end

    res[*(0...self.dim).map {|i| i == dim ? 0 : true}]
  end
end

