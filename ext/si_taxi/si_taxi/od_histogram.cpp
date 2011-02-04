#include "stdafx.h"
#include "utility.h"
#include "od_histogram.h"

using namespace std;

namespace si_taxi {

int ODHistogram::max_weight() const {
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

int ODHistogram::max_weight_in_row(size_t i) const {
  int w_max = -numeric_limits<int>::infinity();
  for (size_t j = 0; j < num_stations(); ++j) {
    if (_matrix(i, j) > w_max) {
      w_max = _matrix(i, j);
    }
  }
  return w_max;
}

#if 0
int ODHistogram::max_weight_in_col(size_t j) const {
  int w_max = -numeric_limits<int>::infinity();
  for (size_t i = 0; i < num_stations(); ++i) {
    if (_matrix(i, j) > w_max) {
      w_max = _matrix(i, j);
    }
  }
  return w_max;
}

int ODHistogram::row_sum(size_t i) const {
  int sum = 0;
  for (size_t j = 0; j < _matrix.size2(); ++j) {
    sum += _matrix(i,j);
  }
  return sum;
}
#endif

std::ostream &operator<<(std::ostream &os, const ODHistogram &hist) {
  return os << hist.od_matrix();
}

}
