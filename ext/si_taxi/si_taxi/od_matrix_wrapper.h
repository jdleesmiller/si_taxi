#ifndef SI_TAXI_OD_MATRIX_WRAPPER_H_
#define SI_TAXI_OD_MATRIX_WRAPPER_H_

#include "si_taxi.h"
#include "empirical_sampler.h"

namespace si_taxi {

/**
 * Cache some commonly used figures for an OD matrix.
 *
 * It is assumed that there is at least one non-zero entry in the matrix and
 * that all entries are non-negative. Rows or columns of zeros are OK.
 *
 * This class doesn't require any particular units for the entries (depends
 * where it's used).
 */
struct ODMatrixWrapper
{
  ODMatrixWrapper(const boost::numeric::ublas::matrix<double> &od);

  inline size_t num_stations() const {
    return _od.size1();
  }

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
   * Probability that the next trip is from i to j, for all stations i and j.
   */
  inline const boost::numeric::ublas::matrix<double> &trip_prob_matrix() const {
    return _trip_prob;
  }

  /**
   * Sum of row i (total vehicle trips per unit time out of station i).
   */
  inline double rate_from(size_t i) const {
    return _rate_from(i);
  }

  /**
   * Sum of column j (total vehicle trips per unit time into station j).
   */
  inline double rate_to(size_t j) const {
    return _rate_to(j);
  }

  /**
   * Probability of exactly n arrivals (per unit time) at station i.
   */
  double poisson_origin_pmf(size_t i, double n) const;

  /**
   * Probability of exactly n trips (per unit time) to station j.
   */
  double poisson_destin_pmf(size_t j, double n) const;

  /**
   * Probability of exactly n requests (per unit time) from station i to
   * station j.
   */
  double poisson_trip_pmf(size_t i, size_t j, double n) const;

  /**
   * Probability of strictly greater than n arrivals (per unit time) at station
   * i.
   */
  double poisson_origin_cdf_complement(size_t i, double n) const;

  /**
   * Probability of strictly greater than n requests (per unit time) from
   * station i to station j.
   */
  double poisson_trip_cdf_complement(size_t i, size_t j, double n) const;

  /**
   * Probability of the given numbers of trips from i to each destination,
   * given that the total number of trips from i is known.
   *
   * @param x trip counts; size() == num_stations()
   */
  double multinomial_trip_pmf(size_t i, const std::vector<int> &x) const;

  /**
   * Generate a request. The origin and destination are chosen according to
   * the trip_prob matrix, and the interval is exponentially distributed
   * according to the expected interarrival time.
   *
   * The interval is in the same units as the expected_interarrival_time; what
   * they actually are depends on the matrix that was passed in.
   *
   * The result is undefined for an empty matrix.
   */
  void sample(size_t &origin, size_t &destin, double &interval) const;

private:
  boost::numeric::ublas::matrix<double> _od;
  double _expected_interarrival_time;
  boost::numeric::ublas::vector<double> _rate_from;
  boost::numeric::ublas::vector<double> _rate_to;
  boost::numeric::ublas::matrix<double> _trip_prob;
  EmpiricalSampler _sampler;
};

}

#endif // guard
