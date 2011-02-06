module SiTaxi
  class NaturalHistogram
    #
    # Create from sparse value => frequency hash.
    #
    # @param [Hash] hash from values to frequencies; both values and frequencies
    # must be non-negative integers (and they must fit within the machine word).
    #
    # @return [NaturalHistogram] not nil
    #
    def self.from_h hash
      hist = NaturalHistogram.new
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
      result = NaturalHistogram.new
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
      for i in 0...hist.size
        self.accumulate(i, hist.frequency[i])
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
    # The number of observations in the histogram.
    #
    # @return [Integer] non-negative 
    #
    def count
      self.to_a.sum
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
    # The average of the observations in the histogram.
    #
    # @return [Float] NaN if histogram is empty
    #
    def mean
      total / count.to_f
    end

    #
    # The sample variance of the observations in the histogram.
    # Unlike {#variance}, this includes the sample size correction.
    #
    # @return [Float] NaN if count is less than 2
    #
    def sample_variance
      self.count / (self.count - 1.0) * self.variance
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
    # The nth central moment E[(X - mean)**n] of the observations in the
    # histogram.
    #
    # @param [Integer] n positive
    #
    # @return [Float] NaN if histogram is empty
    #
    def central_moment n
      if size == 0
        0/0.0
      else
        mu = self.mean
        cnt = self.count
        avg = 0
        for i in 0...size
          avg += self.frequency[i] * (i - mu)**n / cnt
        end
        avg
      end
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
end


