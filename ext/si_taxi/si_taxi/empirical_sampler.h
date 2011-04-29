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
template<typename T>
struct EmpiricalSampler {
  /**
   * @param t something that looks like a vector (must have size() and
   *        operator[]()); it can be a pmf (pass from_pmf=true), or cdf
   *
   * @param from_pmf if true, t is interpreted as a pmf
   *
   * @param cdf_tol error checking: the last entry of the cdf should be 1, by
   *        definition; if it is out by more than this amount, an error is
   *        raised
   */
  EmpiricalSampler(const T& t, bool from_pmf=true, double cdf_tol=1e-5);

  /**
   * Supremum of the values that can be returned by sample(); this is the
   * length of the cdf/pmf giving to the constructor.
   */
  inline size_t sup() const {
    return cdf.size();
  }

  /**
   * @return in [0, sup())
   */
  size_t sample() const;

private:
  T cdf;
};

}

#include "empirical_sampler_impl.h"

#endif // guard
