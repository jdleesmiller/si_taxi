#include "stdafx.h"
#include "utility.h"
#include "od_matrix_wrapper.h"
#include "random.h"
#include "empirical_sampler.h"

#include <boost/math/distributions/poisson.hpp>

using namespace std;

namespace si_taxi {

ODMatrixWrapper::ODMatrixWrapper(
    const boost::numeric::ublas::matrix<double> &od) : _od(od) {
  CHECK(_od.size1() == _od.size2());
  size_t n = _od.size1();
  boost::numeric::ublas::scalar_vector<double> ones(n);
  _expected_interarrival_time = 1.0 / inner_prod(prod(_od, ones), ones);
  _rate_from = prod(_od, ones);
  _rate_to = prod(ones, _od);
  _trip_prob = _od * _expected_interarrival_time;

  // flatten the matrix for more efficient sampling; the sampling step is a
  // performance hot spot for (surprise) the sampling and voting algorithm;
  // partial_sum is cumsum (cumulative sum)
  vector<double> cdf(_trip_prob.data().size());
  std::partial_sum(_trip_prob.data().begin(), _trip_prob.data().end(),
      cdf.begin());
  _sampler = EmpiricalSampler(cdf);
}

// Boost's Poisson distribution doesn't like a zero rate.
static double poisson_pmf(double lambda, double n) {
  if (lambda == 0) {
    return n == 0.0 ? 1.0 : 0.0;
  } else {
    boost::math::poisson p(lambda);
    return boost::math::pdf(p, n);
  }
}

// Boost's Poisson distribution doesn't like a zero rate.
static double poisson_cdf_complement(double lambda, double n) {
  if (lambda == 0) {
    return n < 0 ? 1.0 : 0.0; // strictly > n arrivals with zero rate
  } else {
    boost::math::poisson p(lambda);
    return boost::math::cdf(boost::math::complement(p, n));
  }
}

double ODMatrixWrapper::poisson_origin_pmf(size_t i, double n) const {
  return poisson_pmf(this->rate_from(i), n);
}

double ODMatrixWrapper::poisson_destin_pmf(size_t j, double n) const {
  return poisson_pmf(this->rate_to(j), n);
}

double ODMatrixWrapper::poisson_trip_pmf(size_t i, size_t j, double n) const {
  return poisson_pmf(this->at(i, j), n);
}

double ODMatrixWrapper::poisson_origin_cdf_complement(
    size_t i, double n) const {
  return poisson_cdf_complement(this->rate_from(i), n);
}

double ODMatrixWrapper::poisson_trip_cdf_complement(
    size_t i, size_t j, double n) const {
  return poisson_cdf_complement(this->at(i, j), n);
}

double ODMatrixWrapper::multinomial_trip_pmf(size_t i, const std::vector<int> &x) const
{
  // based on dmultinom from R 2.13.1, which uses lgamma
  CHECK(x.size() == num_stations());

  // handle zeros as a special case
  bool all_probs_zero = true;
  bool all_counts_zero = true;
  for (size_t j = 0; j < x.size(); ++j) {
    CHECK(x[j] >= 0);
    if (_od(i, j) == 0 && x[j] > 0)
      return 0;
    if (x[j] > 0)
      all_counts_zero = false;
    if (_od(i, j) > 0)
      all_probs_zero = false;
  }
  if (all_probs_zero)
    return all_counts_zero ? 1 : 0;

  int N = accumulate(x.begin(), x.end(), 0);
  double log_p = boost::math::lgamma(N + 1);
  for (size_t j = 0; j < x.size(); ++j) {
    double p_j = _od(i, j) / _rate_from(i);
    int x_j = x[j];
    if (p_j != 0 && x_j != 0) {
      log_p += x_j * log(p_j) - boost::math::lgamma(x_j + 1);
    }
  }
  return exp(log_p);
}

void ODMatrixWrapper::sample(size_t &origin, size_t &destin,
    double &interval) const {
  // Having 64-bit portability problems with variate_generator and
  // exponential_distribution, so I am just doing this manually for now.
  // JLM 20100425
  double u = genrand_c01o<double>(si_taxi::rng);
  interval = -log(1 - u) * _expected_interarrival_time;

  size_t n = _od.size1();
  size_t l = _sampler.sample();
  origin = l / n;
  destin = l % n;
  ASSERT(origin < n);
  ASSERT(origin != destin);
}

}
