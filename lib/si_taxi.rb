# Load extension module as SiTaxi before doing anything else.
require 'si_taxi_ext'
SiTaxi = Si_taxi_ext

require 'si_taxi/version'
require 'si_taxi/bell_wong'

module SiTaxi
  #
  # Try to get a stack trace if the extension segfaults.
  #
  SiTaxi.register_sigsegv_handler

  class NaturalHistogram
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
  end
end

