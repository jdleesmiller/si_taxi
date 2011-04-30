#ifndef SI_TAXI_EMPIRICAL_SAMPLER_H_
#define SI_TAXI_EMPIRICAL_SAMPLER_H_

namespace si_taxi {

/**
 * Efficient sampling from an empirical distribution.
 *
 * The distribution can be specified as a probability mass function (pmf) or
 * a cumulative distribution function (cdf). Sampling is always performed on
 * the cdf, because this allows us to find the right bin with a binary search.
 */
struct EmpiricalSampler {
  /**
   * Constructs a non-functional sampler; this default constructor is provided
   * for convenience only.
   */
  EmpiricalSampler() { }

  /**
   * @param cdf cumulative distribution function
   *
   * @param cdf_tol error checking: the last entry of the cdf should be 1, by
   *        definition; if it is out by more than this amount, an error is
   *        raised
   */
  EmpiricalSampler(const std::vector<double> &cdf, double cdf_tol=1e-5);

  /**
   * Create an Empirical Sampler from a probability mass function (pmf); this
   * function computes the cumulative sum (partial sum) of the pmf and then
   * calls the regular constructor.
   *
   * @param pmf probability mass function; entries must sum to one (but see
   *        the cdf_tol parameter)
   *
   * @param cdf_tol error checking: the last entry of the cdf should be 1, by
   *        definition; if it is out by more than this amount, an error is
   *        raised
   */
  static EmpiricalSampler from_pmf(const std::vector<double> &pmf,
      double cdf_tol=1e-5);

  /**
   * Supremum of the values that can be returned by sample(); this is the
   * length of the cdf/pmf giving to the constructor.
   */
  inline size_t sup() const {
    return cdf.size();
  }

  /**
   * Pick the bin in the CDF that contains the given value; you probably want
   * to call sample(), which calls this method with a random value.
   *
   * It is an error to call pick if sup() is zero (i.e. with an empty cdf).
   *
   * @param r in (0, 1]
   *
   * @return in [0, sup())
   */
  size_t pick(double r) const;

  /**
   * Pick a random bin.
   *
   * It is an error to call sample if sup() is zero (i.e. with an empty cdf).
   *
   * @return in [0, sup())
   */
  size_t sample() const;

private:
  std::vector<double> cdf;
};

}

#endif // guard
