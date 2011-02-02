#ifndef SI_TAXI_BELL_WONG_ANDREASSON_H_
#define SI_TAXI_BELL_WONG_ANDREASSON_H_

#include "bell_wong.h"
#include "call_times.h"

namespace si_taxi {

/**
 * Tries to reproduce the results from Andreasson 1994 and Andreasson 1998 (not
 * much we can do about Andreasson 2003, because it requires dynamic rerouting).
 */
struct BWAndreassonHandler : public BWProactiveHandler {
  /**
   * @param sim
   * @param od with entries in vehicles per second
   */
  BWAndreassonHandler(BWSim &sim, BWCallTimeTracker &call_time,
      boost::numeric::ublas::matrix<double> od);

  /**
   * Override.
   */
  virtual void handle_pax_served(size_t empty_origin);

  /**
   * Override.
   */
  virtual void handle_idle(BWVehicle &veh);

  /**
   * As Sim::num_vehicles_inbound, but only count vehicles within the call time
   * for station i.
   */
  int num_vehicles_inbound_in_call_time(size_t i) const;

  /**
   * As Sim::num_vehicles_immediately_inbound, but only count vehicles within
   * the call time for station i.
   */
  int num_vehicles_immediately_inbound_in_call_time(size_t i) const;

  /**
   * Compute supply at station i; see surplus for details.
   */
  int supply_at(size_t i) const;

  /**
   * Compute demand at station i; see surplus for details.
   */
  double demand_at(size_t i) const;

  /**
   * Compute surplus (supply - demand). The definition of supply depends on the
   * immediate_inbound_only and use_call_times_for_inbound flags; see
   * num_vehicles_inbound_in_call_time and
   * num_vehicles_immediately_inbound_in_call_time for comments. The definition
   * of demand depends on the use_call_times_for_targets flag; if it is set,
   * the call_time array and OD matrix are used; otherwise, the targets array
   * is used.
   */
  double surplus(size_t i) const;

  /**
   * Nearest origin with expected surplus not higher than min_surplus;
   * this could be the surplus at the origin station, in which case we behave
   * like the 1998 paper, or it could be surplus_threshold, in which case we get
   * the 1994 paper (nearest station with a surplus).
   *
   * If an eligible "preferred" station can be found, it will be used; this
   * allows the use of the call lists in the 1998 paper.
   *
   * @return numeric_limits<size_t>::max() if no suitable origin found
   */
  size_t find_call_origin(size_t j, double min_surplus) const;

  /**
   * Station with the largest expected deficit. This is interpreted as meaning
   * that we won't send to a station that has an expected surplus (>= 0).
   *
   * If an eligible "preferred" station can be found, it will be used; this
   * allows the use of the send lists in the 1998 paper.
   *
   * Instead of sending only to stations with surplus < 0, we could send to
   * stations with surplus < surplus_threshold, but the former seems closer to
   * the wording in Andreasson 1998. The difference should be minor, anyway.
   *
   * @return numeric_limits<size_t>::max() if no suitable destination found
   */
  size_t find_send_destin(size_t i) const;

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

  /**
   * In vehicle trips / second; only used if use_call_times_for_targets.
   *
   * Note that if call_time were a public member, it would have to have a
   * working assignment operator, which is not possible, because it has
   * reference members.
   */
  const ODMatrixWrapper &od() const {
    return _od;
  }

protected:
  /// See call_time()
  BWCallTimeTracker &_call_time;
  /// See od()
  ODMatrixWrapper _od;

public:
  /// see surplus(...)
  bool immediate_inbound_only;
  /// see surplus(...)
  bool use_call_times_for_inbound;
  /// see surplus(...)
  bool use_call_times_for_targets;
  /// try to send when an empty vehicle is idle at a station with a surplus
  bool send_when_over;
  /// see find_call_origin
  bool call_only_from_surplus;
  /// station wants to call if its surplus is less than this threshold
  double surplus_threshold;
  /// used unless use_call_times_for_targets is true; see surplus(...)
  std::vector<int> targets;
  /// To implement call/send lists, e.g. based on fluid limit solution
  boost::numeric::ublas::matrix<bool> preferred;
  /// Stations that tried to call but couldn't find any available vehicles.
  std::queue<int> call_queue;
};

}

#endif // guard
