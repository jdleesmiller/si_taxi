class SiTaxi::NaturalHistogram
  #
  # Create from sparse value => frequency hash.
  #
  # @param [Hash] hash from values to frequencies; both values and frequencies
  # must be non-negative integers (and they must fit within the machine word).
  #
  # @return [NaturalHistogram] not nil
  #
  def self.from_h hash
    hist = SiTaxi::NaturalHistogram.new
    for val, freq in hash
      hist.accumulate(val, freq)
    end
    hist
  end
  
  #
  # Create histogram that is the union of the given histograms.
  #
  # @param [NaturalHistogram] hists
  #
  # @return [NaturalHistogram] not nil
  #
  def self.merge *hists
    result = SiTaxi::NaturalHistogram.new
    hists.each do |hist|
      result.merge!(hist)
    end
    result
  end

  def inspect
    self.frequency.to_a.inspect
  end

  # As array.
  def to_a
    self.frequency.to_a
  end

  # Sparse hash.
  def to_h
    h = {}
    self.frequency.each_with_index do |freq,val|
      h[val] = freq if freq > 0
    end
    h
  end

  #
  # Merge the given histogram into this histogram.
  #
  # @param [NaturalHistogram] hist
  #
  # @return [self]
  #
  def merge! hist
    self.frequency.reserve(hist.size) # avoid repeated reallocation if growing
    for i in 0...hist.size
      freq = hist.frequency[i] # avoid calling swig for zero frequencies
      self.accumulate(i, freq) if freq > 0
    end
    self
  end

  #
  # Number of bins.
  #
  # @return [Integer] non-negative
  #
  def size
    self.frequency.size
  end

  #
  # The total of the observations in the histogram.
  #
  # @return [Numeric] 0 if histogram is empty
  #
  def total
    total = 0
    for i in 0...size
      total += i * self.frequency[i]
    end
    total
  end

  #
  # The sample variance of the observations in the histogram.
  # Unlike {#variance}, this includes the sample size correction.
  #
  # @return [Float] NaN if count is less than 2
  #
  def sample_variance
    cnt = self.count
    cnt / (cnt - 1.0) * self.variance
  end

  #
  # The variance E[(X - mean)**2] of the observations in the histogram.
  #
  # @return [Float] NaN if histogram is empty
  #
  def variance
    central_moment(2)
  end

  #
  # The largest observation in the histogram.
  #
  # @return [Float] NaN if histogram is empty
  #
  def max
    if size == 0
      0/0.0
    else
      self.size - 1
    end
  end

  #
  # Return the smallest observation x s.t. the fraction of all observations
  # less than x is at least q (e.g. q = 0.9 returns the 90% percentile). When
  # q = 0, the minimum observation is returned, and when q = 1, the maximum
  # observation is returned.
  #
  # @param [Float] q in [0, 1]
  # 
  # @return [Numeric, nil] nil if histogram is empty
  #
  def quantile q
    cut = (q.to_f * count).ceil
    obs = 0
    for i in 0...size
      obs += self.frequency[i]
      return i if obs > 0 && obs >= cut
    end
    return nil
  end
end

