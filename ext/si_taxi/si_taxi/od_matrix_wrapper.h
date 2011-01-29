#ifndef SI_TAXI_OD_MATRIX_WRAPPER_H_
#define SI_TAXI_OD_MATRIX_WRAPPER_H_

#include "si_taxi.h"

namespace si_taxi {

/**
 * Cache some commonly used figures for an OD matrix.
 *
 * This class doesn't require any particular units for the entries (depends
 * where it's used).
 */
struct ODMatrixWrapper
{
  ODMatrixWrapper(const boost::numeric::ublas::matrix<double> &od);

  /**
   * Expected time between requests (between any pair of stations), in time
   * units.
   */
  inline double expected_interarrival_time() const {
    return _expected_interarrival_time;
  }

  /**
   * The underlying OD matrix, with entries, in vehicle trips per unit time.
   */
  inline const boost::numeric::ublas::matrix<double> &od_matrix() const {
    return _od;
  }

  /**
   * Entry from the underlying matrix, in vehicle trips unit time.
   */
  inline double at(size_t i, size_t j) const {
    return _od(i, j);
  }

  /**
   * Probability that the next trip is from i to j.
   */
  inline double trip_prob(size_t i, size_t j) const {
    return _trip_prob(i, j);
  }

  /**
   * Sum of row i (total vehicle trips per unit time out of station i).
   */
  inline double rate_from(size_t i) const {
    return _rate_from(i);
  }

private:
  boost::numeric::ublas::matrix<double> _od;
  boost::numeric::ublas::matrix<double> _trip_prob;
  boost::numeric::ublas::vector<double> _rate_from;
  double _expected_interarrival_time;
};

}

#endif // guard
