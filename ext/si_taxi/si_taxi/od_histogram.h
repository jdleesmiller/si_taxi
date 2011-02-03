#ifndef SI_TAXI_OD_HISTOGRAM_H_
#define SI_TAXI_OD_HISTOGRAM_H_

#include "si_taxi.h"

#include <boost/numeric/ublas/banded.hpp>
//#include <boost/numeric/ublas/matrix_proxy.hpp>

using namespace std;

namespace si_taxi {

/**
 * A histogram that counts the occurrence of origin-destination pairs.
 */
struct ODHistogram
{
  explicit ODHistogram(size_t num_stations) :
      _matrix(num_stations, num_stations, 0) { }

  /**
   * Number of stations that this histogram can handle.
   */
  inline size_t num_stations() const {
    return _matrix.size1();
  }

  /**
   * Increment the entry for the given origin and destination.
   */
  inline void increment(size_t origin, size_t destin) {
    accumulate(origin, destin, 1);
  }

  /**
   * Add weight to the entry for the given origin and destination.
   */
  inline void accumulate(size_t origin, size_t destin, int weight) {
    _matrix(origin, destin) += weight;
  }

  /**
   * The largest weight accumulated.
   *
   * Note: all entries must be non-negative, or the result is undefined.
   */
  int max_weight() const {
    int w_max = -numeric_limits<int>::infinity();
    for (size_t i = 0; i < num_stations(); ++i) {
      for (size_t j = 0; j < num_stations(); ++j) {
        if (_matrix(i, j) > w_max) {
          w_max = _matrix(i, j);
        }
      }
    }
    return w_max;
  }

  /**
   * The largest weight accumulated in the given row.
   */
  int max_weight_in_row(size_t i) const {
    int w_max = -numeric_limits<int>::infinity();
    for (size_t j = 0; j < num_stations(); ++j) {
      if (_matrix(i, j) > w_max) {
        w_max = _matrix(i, j);
      }
    }
    return w_max;
  }

  /**
   * The largest weight accumulated in the given column.
   */
  int max_weight_in_col(size_t j) const {
    int w_max = -numeric_limits<int>::infinity();
    for (size_t i = 0; i < num_stations(); ++i) {
      if (_matrix(i, j) > w_max) {
        w_max = _matrix(i, j);
      }
    }
    return w_max;
  }

  /**
   * Sum up along row (including element on diagonal).
   */
  int row_sum(size_t i) const {
    int sum = 0;
    for (size_t j = 0; j < _matrix.size2(); ++j) {
      sum += _matrix(i,j);
    }
    return sum;
  }

  /**
   * Set diagonal elements such that the elements in each row sum to the given
   * totals. The old values on the diagonal are discarded.
   */
  void set_diagonal_for_row_sums(
      const boost::numeric::ublas::diagonal_matrix<int> &row_sums) {
    assert(_matrix.size1() == row_sums.size1());
    assert(_matrix.size2() == row_sums.size2());

    for (size_t i = 0; i < _matrix.size1(); ++i) {
      int curr_row_sum = 0;
      for (size_t j = 0; j < _matrix.size2(); ++j) {
        if (i != j) {
          curr_row_sum += _matrix(i,j);
        }
      }
      _matrix(i,i) = row_sums(i,i) - curr_row_sum;
    }
  }

  /**
   * Divide each entry by the sum of all entries in its row.
   */
  void normalize_rows() {
    for (size_t i = 0; i < _matrix.size1(); ++i) {
      double sum = this->row_sum(i);
      for (size_t j = 0; j < _matrix.size2(); ++j) {
        _matrix(i,j) /= sum;
      }
    }
  }

  /**
   * The underlying matrix of counts.
   */
  inline const boost::numeric::ublas::matrix<int> &od_matrix() const {
    return _matrix;
  }

protected:
  boost::numeric::ublas::matrix<int> _matrix;
};

}

#endif // guard
