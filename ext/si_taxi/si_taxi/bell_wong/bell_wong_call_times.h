#ifndef SI_TAXI_BELL_WONG_CALL_TIMES_H_
#define SI_TAXI_BELL_WONG_CALL_TIMES_H_

#include "bell_wong.h"
#include <si_taxi/od_matrix_wrapper.h>

namespace si_taxi {

/**
 * Keep track of the average empty vehicle call time for each station -- that
 * is, the average trip time for all non-trivial empty vehicle trips to the
 * station. (Non trivial means that we don't count trips with 0 length.)
 *
 * Call times are initialised to the shortest trip time from any upstream
 * station.
 */
struct BWCallTimeTracker {
  /**
   * @param sim
   */
  BWCallTimeTracker(BWSim &sim);

  /// Running average of empty vehicle call times for each station.
  std::vector<double> call_time;
  /// Number of calls recorded for each station.
  std::vector<int> call;

  /**
   * Shorthand to get call time of station i.
   */
  inline double operator[](size_t i) const {
    return call_time.at(i);
  }

  /**
   * Update call time of ev_destin to reflect the given empty vehicle trip.
   */
  void update(size_t ev_origin, size_t ev_destin);

protected:
  /// Simulator to track call times for.
  BWSim &sim;
};

}

#endif // guard
