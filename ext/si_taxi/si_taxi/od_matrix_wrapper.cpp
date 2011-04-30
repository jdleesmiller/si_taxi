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
