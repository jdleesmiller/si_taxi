#
# Extensions for NArray.
# 
class NArray
  #
  # Cumulative sum along dimension +dim+; modifies this array in place.
  #
  # @param [Number] dim non-negative
  #
  # @return [NArray] self
  #
  def cumsum_general! dim=0
    if self.dim > dim
      # For example, if this is a matrix and dim = 0, mask_0 selects the first
      # column of the matrix and mask_1 selects the second column; then we just
      # shuffle them along and accumulate.
      mask_0 = (0...self.dim).map{|d| d == dim ? 0 : true}
      mask_1 = (0...self.dim).map{|d| d == dim ? 1 : true}
      while mask_1[dim] < self.shape[dim]
        self[*mask_1] += self[*mask_0]
        mask_0[dim] += 1
        mask_1[dim] += 1
      end
    end
    self
  end

  #
  # Cumulative sum along dimension +dim+.
  #
  # @param [Number] dim non-negative
  #
  # @return [NArray] self
  #
  def cumsum_general dim=0
    self.dup.cumsum_general!(dim)
  end

  # The built-in cumsum only does vectors (dim 1).
  alias cumsum_narray cumsum
  alias cumsum cumsum_general
  alias cumsum_narray! cumsum!
  alias cumsum! cumsum_general!

  #
  # Replicate this array to make a tiled array (repmat).
  #
  # @param [Array<Number>] reps number of times to repeat in each dimension;
  # note that reps.size is allowed to be different self.dim
  #
  # @return [NArray] with same typecode as self 
  #
  def tile *reps
    if self.dim == 0 || reps.member?(0)
      # Degenerate case: 0 dimensions or dimension 0
      res = NArray.new(self.typecode, 0)
    else
      if reps.size <= self.dim 
        # Repeat any extra dims once.
        reps = reps + [1]*(self.dim - reps.size) 
        tile = self
      else
        # Have to add some more dimensions (with implicit shape[dim] = 1).
        tile_shape = self.shape + [1]*(reps.size - self.dim) 
        tile = self.reshape(*tile_shape)
      end

      # Allocate tiled matrix.
      res_shape = (0...tile.dim).map{|i| tile.shape[i] * reps[i]}
      res = NArray.new(self.typecode, *res_shape)

      # Copy tiles.
      # This probably isn't the most efficient way of doing this; just doing
      # res[] = tile doesn't seem to work in general
      title_positions = SiTaxi::Utility::cartesian_product(
        *reps.map{|n| (0...n).to_a})
      title_positions.each do |tile_pos|
        tile_slice = (0...tile.dim).map{|i|
          (tile.shape[i] * tile_pos[i])...(tile.shape[i] * (tile_pos[i]+1))}
        res[*tile_slice] = tile
      end
    end
    res
  end

  #
  # Sample from an array that represents a probability mass function (pmf); the
  # entries along dimension +dim+ must be non-negative numbers that sum to one
  # (but there may be some rounding error).
  #
  def sample_pmf dim=0, r=nil
    if self.dim > dim
      # Generate random sample.
      r_shape = (0...self.dim).map {|i| i == dim ? 1 : self.shape[i]}
      r = NArray.new(self.typecode, *r_shape).random! unless r

      # Allocate space for results -- same size as the random sample.
      res = NArray.int(*r_shape)

      # For every other dimension, accumulate mass along dim until we pass the
      # random threshold for that subarray.
      slices = SiTaxi::Utility::cartesian_product(*r_shape.map{|n|(0...n).to_a})
      slices.each do |slice|
        pr_cum      = 0
        r_thresh    = r[*slice]
        res[*slice] = self.shape[dim] - 1
        self_slice = slice.dup
        for self_slice[dim] in 0...self.shape[dim]
          pr_cum += self[*self_slice]
          if r_thresh < pr_cum
            res[*slice] = self_slice[dim]
            break
          end
        end
      end

      res[*(0...self.dim).map {|i| i == dim ? 0 : true}]
    else
      raise 'self.dim must be > dim'
    end
  end

  #
  # Convert a linear (1D) index into subscripts for an array with the given
  # shape.
  #
  # There must be a function in NArray to do this, but I can't find it.
  #
  # This is analogous to the matlab function ind2sub.
  #
  def index_to_subscript index
    raise IndexError.new("out of bounds: index=#{index} for shape=#{
      self.shape.inspect}") if index >= self.size
    self.shape.map {|s| index, r = index.divmod(s); r }
  end

  #
  # Sample from array in which <tt>self[i,j,...]</tt> the probability of
  # choosing the element <tt>[i,j,...]</tt>.
  #
  # Self must be non-empty.
  #
  # @return [Array] same length as <tt>self.shape<tt>
  #
  def sample r=nil
    self.index_to_subscript(self.flatten.sample_pmf(0, r))
  end
end


