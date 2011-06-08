#ifndef SI_TAXI_NATURAL_HISTOGRAM_H_
#define SI_TAXI_NATURAL_HISTOGRAM_H_

namespace si_taxi {

/**
 * A histogram for non-negative integers with bin size 1 that grows to
 * accommodate the largest value recorded; backed by a std::vector.
 */
struct NaturalHistogram {
  std::vector<size_t> frequency;

  inline void increment(size_t x) {
    accumulate(x, 1);
  }

  inline void accumulate(size_t x, size_t w) {
    if (x >= frequency.size())
      frequency.resize(x + 1, 0);
    frequency[x] += w;
  }

  inline void clear() {
    frequency.clear();
  }

  /**
   * Number of observations in the histogram.
   *
   * @return non-negative
   */
  uint64_t count() const;

  /**
   * Arithmetic mean of observations in the histogram.
   *
   * @return non-negative, or NaN if histogram is empty
   */
  double mean() const;

  /**
   * The nth central moment E[(X - mean)**n] of the observations in the
   * histogram.
   *
   * @param n positive
   *
   * @return non-negative, or NaN if histogram is empty
   */
  double central_moment(size_t n) const;
};

}

#endif // guard
