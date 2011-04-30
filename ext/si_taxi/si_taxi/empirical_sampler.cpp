#include "stdafx.h"
#include "empirical_sampler.h"
#include "utility.h"
#include "random.h"

namespace si_taxi {

EmpiricalSampler::EmpiricalSampler(
    const std::vector<double> &cdf, double cdf_tol) : cdf(cdf)
{
  // the sum is susceptible to rounding errors, which might give us a cdf in
  // which the probability of the last element is slightly less than 1, which
  // could cause sampling to fail (or require more checking); to avoid this,
  // we just fix the last element at exactly 1
  if (this->cdf.size() > 0) {
    CHECK(fabs(1.0 - this->cdf[this->cdf.size() - 1]) < cdf_tol);
    this->cdf[this->cdf.size() - 1] = 1.0;
  }
}

EmpiricalSampler EmpiricalSampler::from_pmf(
    const std::vector<double> &pmf, double cdf_tol)
{
  std::vector<double> cdf(pmf.size());
  std::partial_sum(pmf.begin(), pmf.end(), cdf.begin());
  return EmpiricalSampler(cdf, cdf_tol);
}

size_t EmpiricalSampler::pick(double r) const {
  // do a binary search on the CDF; it should not be possible for us to run
  // off the end, because we set the last entry to exactly 1.0
  std::vector<double>::const_iterator it =
      lower_bound(cdf.begin(), cdf.end(), r);
  ASSERT(it != cdf.end());
  return it - cdf.begin();
}

size_t EmpiricalSampler::sample() const {
  // we want a random number in (0, 1], so lower_bound won't pick entries
  // with zero probability at the start of the cdf; this is why we use 1 -
  // a random value, which is in range [0, 1)
  return pick(1 - genrand_c01o<double>(si_taxi::rng));
}

}
