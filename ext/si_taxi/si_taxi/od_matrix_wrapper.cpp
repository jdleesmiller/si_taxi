#include "stdafx.h"
#include "utility.h"
#include "od_matrix_wrapper.h"

using namespace std;

namespace si_taxi {

ODMatrixWrapper::ODMatrixWrapper(
    const boost::numeric::ublas::matrix<double> &od) : _od(od) {
    ASSERT(_od.size1() == _od.size2());
    boost::numeric::ublas::scalar_vector<double> ones(_od.size1());
    _expected_interarrival_time = 1.0 / inner_prod(prod(_od, ones), ones);
    _rate_from = prod(_od, ones);
    _trip_prob = _od * _expected_interarrival_time;
  }
}
