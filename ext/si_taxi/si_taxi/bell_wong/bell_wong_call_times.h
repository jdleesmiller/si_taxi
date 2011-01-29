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
  inline double at(size_t i) const {
    return call_time.at(i);
  }

  /**
   * Update call time of ev_destin to reflect the given empty vehicle trip.
   *
   * If the trip is trivial (ev_origin = ev_destin), the trip is ignored.
   */
  void update(size_t ev_origin, size_t ev_destin);

protected:
  /// Simulator to track call times for.
  BWSim &sim;
};

/**
 * The original Bell and Wong Nearest Neighbours (BWNN) heuristic.
 */
struct BWNNHandlerWithCallTimeUpdates : public BWNNHandler {
  explicit inline BWNNHandlerWithCallTimeUpdates(BWSim &sim,
      BWCallTimeTracker &call_time) :
	      BWNNHandler(sim), _call_time(call_time) { }
  virtual ~BWNNHandlerWithCallTimeUpdates() { }
  virtual size_t handle_pax(const BWPax &pax);

  /**
   * Call times computed so far for each station.
   *
   * Note that if call_time were a public member, it would have to have a
   * working assignment operator, which is not possible, because it has
   * reference members.
   */
  const BWCallTimeTracker &call_time() const {
    return _call_time;
  }

protected:
  /// See call_time()
  BWCallTimeTracker &_call_time;
};

}

#endif // guard
