#include "stdafx.h"
#include "utility.h"
#include "od_matrix_wrapper.h"
#include "random.h"

#include <boost/math/distributions/poisson.hpp>

using namespace std;

/**
 * If we sum up the entries of (discrete) cumulative distribution function,
 * we expect the last entry to be exactly 1. An error is raised if it deviates
 * from 1 by more than this amount (e.g. due to numerical problems).
 */
#define CDF_TOL 1e-3

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

  // sum to get the cdf for more efficient sampling; here 'cumulative' goes
  // by rows, then by columns (row major storage order).
  _trip_cdf = _trip_prob.data();
  CHECK(_trip_cdf.size() == n*n);
  double sum = 0;
  for (size_t i = 0; i < n*n; ++i) {
    sum += _trip_cdf[i];
    _trip_cdf[i] = sum;
  }

  // the sum is susceptible to rounding errors, which might give us a 'cdf' in
  // which the probability of the last element is slightly less than 1, which
  // could cause sampling to fail (or require more checking); to avoid this,
  // we just fix the last element at exactly 1; moreover, because the demand
  // matrix has zeros on the diagonal, the second last entry must be 1, too
  if (n > 0) {
    CHECK(abs(1 - _trip_cdf[n*n - 2]) < CDF_TOL); // should be pretty close
    CHECK(abs(1 - _trip_cdf[n*n - 1]) < CDF_TOL); // should be pretty close
    _trip_cdf[n*n - 2] = 1.0;
    _trip_cdf[n*n - 1] = 1.0;
  }
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

  // do a binary search on the CDF; it should not be possible for us to run
  // off the end, because we set the last entry to exactly 1.0, and r is chosen
  // to be strictly less than 1; profiling shows that, particularly for the SV
  // algorithm, this is a performance hotspot
  double r = genrand_c01o<double>(si_taxi::rng);
  boost::numeric::ublas::unbounded_array<double>::const_iterator it=
    upper_bound(_trip_cdf.begin(), _trip_cdf.end(), r);
  ASSERT(it != _trip_cdf.end());
  size_t n = _od.size1();
  size_t l = it - _trip_cdf.begin();
  origin = l / n;
  ASSERT(origin < n);
  destin = l % n;
  ASSERT(origin != destin);
}

}
