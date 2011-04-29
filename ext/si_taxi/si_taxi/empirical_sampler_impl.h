#ifndef SI_TAXI_EMPIRICAL_SAMPLER_IMPL_H_
#define SI_TAXI_EMPIRICAL_SAMPLER_IMPL_H_

namespace si_taxi {
template <typename T>
EmpiricalSampler<T>::EmpiricalSampler(
    const T& t, bool from_pmf, double cdf_tol) : cdf(t) {

  // if given a pmf, compute cumulative sum to get cdf
  if (from_pmf) {
    double sum = 0;
    for (size_t i = 0; i < cdf.size(); ++i) {
      sum += cdf[i];
      cdf[i] = sum;
    }
  }

  // the sum is susceptible to rounding errors, which might give us a cdf in
  // which the probability of the last element is slightly less than 1, which
  // could cause sampling to fail (or require more checking); to avoid this,
  // we just fix the last element at exactly 1
  if (cdf.size() > 0) {
    CHECK(abs(1 - cdf[cdf.size() - 1]) < cdf_tol); // should be pretty close
    cdf[cdf.size() - 1] = 1.0;
  }
}

template<typename T>
size_t EmpiricalSampler<T>::sample() const {
  // do a binary search on the CDF; it should not be possible for us to run
  // off the end, because we set the last entry to exactly 1.0; we want a
  // random number in (0, 1], so lower_bound won't pick entries with zero
  // probability at the start.
  double r = 1 - genrand_c01o<double>(si_taxi::rng);
  typename T::const_iterator it = lower_bound(cdf.begin(), cdf.end(), r);
  ASSERT(it != cdf.end());
  return it - cdf.begin();
}

}

#endif // guard
