#ifndef SI_TAXI_BELL_WONG_SURPLUS_DEFICIT_H_
#define SI_TAXI_BELL_WONG_SURPLUS_DEFICIT_H_

#include "bell_wong.h"
#include "call_times.h"

namespace si_taxi {

/**
 * The "Surplus/Deficit" heuristic in the TRB2011 paper.
 */
struct BWSurplusDeficitHandler: public BWProactiveHandler {
  /**
   * @param sim
   * @param od with entries in vehicles per second
   */
  BWSurplusDeficitHandler(BWSim &sim, BWCallTimeTracker &call_time,
      boost::numeric::ublas::matrix<double> od);

  /**
   * Override.
   */
  virtual void init();

  /**
   * Override.
   *
   * For each station i with idle vehicles, in descending order by number
   * of idle vehicles, if the surplus of vehicles at i is greater than or equal
   * to one, an idle vehicle at i is sent to the nearest station with surplus
   * less than zero (if any).
   */
  virtual void handle_pax_served(size_t empty_origin);

  /**
   * Override.
   *
   * When a vehicle becomes idle at station i, the actions for handle_pax_served
   * are taken for station i only.
   */
  virtual void handle_idle(BWVehicle &veh);

  /**
   * The surplus of vehicles at station i is the number of inbound vehicles
   * minus the expected number of requests over the call time.
   */
  double surplus_at(size_t i) const;

  /**
   * Send an idle vehicle at origin station to the nearest station with surplus
   * less than zero. It is assumed that there is an idle vehicle at origin.
   */
  void send_idle_veh_to_nearest_deficit(size_t origin);

  /**
   * Call times computed so far for each station.
   *
   * Note that if _call_time were a public member, it would have to have a
   * working assignment operator, which is not possible, because it has
   * reference members.
   */
  const BWCallTimeTracker &call_time() const {
    return _call_time;
  }

  /**
   * In vehicle trips / second.
   *
   * Note that if _od were a public member, it would have to have a
   * working assignment operator, which is not possible, because it has
   * reference members.
   */
  const ODMatrixWrapper &od() const {
    return _od;
  }

protected:
  /// see call_time()
  BWCallTimeTracker &_call_time;
  /// see od()
  ODMatrixWrapper _od;
};

}

#endif // guard
