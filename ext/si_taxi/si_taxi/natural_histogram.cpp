#include "stdafx.h"
#include "utility.h"
#include "natural_histogram.h"

using namespace std;

uint64_t si_taxi::NaturalHistogram::count() const {
  return std::accumulate(frequency.begin(), frequency.end(), (uint64_t)0);
}

double si_taxi::NaturalHistogram::mean() const {
  uint64_t sum = 0;
  for (size_t i = 0; i < frequency.size(); ++i) {
    sum += (uint64_t) i * (uint64_t) frequency[i];
  }
  return sum / (double)count();
}

double si_taxi::NaturalHistogram::central_moment(size_t n) const {
  double cnt = (double)count();
  if (cnt == 0.0) {
    return numeric_limits<double>::quiet_NaN();
  } else {
    double mu = mean();
    double avg = 0.0;
    for (size_t i = 0; i < frequency.size(); ++i) {
      avg += frequency[i] * pow(i - mu, (double)n) / cnt;
    }
    return avg;
  }
}
