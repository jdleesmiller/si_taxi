#include "stdafx.h"
#include "utility.h"
#include "od_matrix_wrapper.h"
#include "random.h"

#include <boost/math/distributions/poisson.hpp>

using namespace std;

namespace si_taxi {

ODMatrixWrapper::ODMatrixWrapper(
    const boost::numeric::ublas::matrix<double> &od) : _od(od) {
  CHECK(_od.size1() == _od.size2());
  boost::numeric::ublas::scalar_vector<double> ones(_od.size1());
  _expected_interarrival_time = 1.0 / inner_prod(prod(_od, ones), ones);
  _rate_from = prod(_od, ones);
  _rate_to = prod(ones, _od);
  _trip_prob = _od * _expected_interarrival_time;
}

double ODMatrixWrapper::poisson_arrival_pmf(size_t i, double n) const {
  boost::math::poisson p(this->rate_from(i));
  return boost::math::pdf(p, n);
}

double ODMatrixWrapper::poisson_arrival_cdf_complement(
    size_t i, double n) const {
  boost::math::poisson p(this->rate_from(i));
  return boost::math::cdf(boost::math::complement(p, n));
}

void ODMatrixWrapper::sample(size_t &origin, size_t &destin,
    double &interval) const {
  // Having 64-bit portability problems with variate_generator and
  // exponential_distribution, so I am just doing this manually for now.
  // JLM 20100425
  double u = genrand_c01o<double>(si_taxi::rng);
  interval = -log(1 - u) * _expected_interarrival_time;
  sample_matrix(si_taxi::rng, _trip_prob, origin, destin);
}

}
