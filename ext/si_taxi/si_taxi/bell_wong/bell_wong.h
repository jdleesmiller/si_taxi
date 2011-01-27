#ifndef SI_TAXI_BELL_WONG_H_
#define SI_TAXI_BELL_WONG_H_

#include <si_taxi/si_taxi.h>

#include <queue>

namespace si_taxi {

/**
 * A 32-bit time index is typically adequate.
 *
 * Differences of times are often computed, so a signed type is needed.
 */
typedef long BWTime;

/**
 * A simple vehicle; it is slightly more general than the Bell and Wong
 * model, because it remembers its final destination, its arrival time there,
 * and the origin station immediately before its final destination.
 *
 * Storing the origin station allows us to work out when the vehicle will be
 * on the last leg of its journey. When the travel times are known, this lets
 * us count inbound vehicles in the usual way; without this member, we
 * would count a vehicle as inbound as soon as its final destination was set,
 * which might be too early.
 */
struct BWVehicle {
  /// Index of origin station of last leg of vehicle's journey to destin.
  size_t origin;
  /// Index of final destination station.
  size_t destin;
  /// Time at which vehicle arrived or will arrive at destin; the simulation
  /// starts at time 0.
  BWTime arrive;

  BWVehicle() { }
  BWVehicle(size_t origin, size_t destin, BWTime arrive) :
    origin(origin), destin(destin), arrive(arrive) { }

  /**
   * To initialise; set 'origin' initially the same as the final destination.
   */
  BWVehicle(size_t destin, BWTime arrive) :
    origin(destin), destin(destin), arrive(arrive) { }
};

/**
 * Passenger.
 */
struct BWPax {
  size_t origin;
  size_t destin;
  BWTime arrive;

  BWPax() { }
  BWPax(size_t origin, size_t destin, BWTime arrive) :
    origin(origin), destin(destin), arrive(arrive) { }
};

struct BWReactiveHandler;  // forward declaration
struct BWProactiveHandler; // forward declaration

/**
 * Simulation.
 *
 * Can be re-used; call init between runs.
 *
 * A passenger's waiting time is recorded as soon has he arrives.
 */
struct BWSim {
  /// Current simulation time.
  BWTime now;
  /// Run the proactive handler at this interval.
  BWTime strobe;
  /// Callback for immediate assignment of request to vehicle.
  BWReactiveHandler *reactive;
  /// Callbacks that can initiate proactive empty vehicle trips.
  BWProactiveHandler *proactive;
  /// Simulation state.
  std::vector<BWVehicle> vehs;
  /// Station-station trip times in seconds; zeros on the diagonal.
  boost::numeric::ublas::matrix<int> trip_time;

  //
  // Statistics collection.
  //

  /// Histograms of passenger waiting times, in seconds, per station.
  std::vector<NaturalHistogram> pax_wait;
  /// Histograms of passenger queue lengths, in seconds, per station.
  std::vector<NaturalHistogram> queue_len;
  /// Helper for computing queue length (queue_len) stats.
  std::vector<std::priority_queue<BWTime,
    std::vector<BWTime>, std::greater<BWTime> > > pickups;
  /// Number of occupied vehicle trips observed between each pair of stations.
  boost::numeric::ublas::matrix<size_t> occupied_trips;
  /// Number of empty vehicle trips observed between each pair of stations.
  boost::numeric::ublas::matrix<size_t> empty_trips;

  BWSim() : now(0), strobe(0), reactive(NULL), proactive(NULL) { }

  /**
   * Number of stations (or zones); this is based on the trip times.
   */
  inline size_t num_stations() const {
    assert(trip_time.size1() == trip_time.size2());
    return trip_time.size1();
  }

  /**
   * Prepare for run; this clears statistics and resets time to 0.
   */
  void init();

  /**
   * Main simulation driver; run the simulation until the passenger arrives,
   * and then assign a vehicle to serve the passenger.
   */
  void handle_pax(const BWPax & pax);

  /**
   * Begin empty trip from veh's current destination to destin.
   */
  void move_empty(size_t k, size_t destin);

  /**
   * Assign vehicle k to serve pax; this requires that k finish its current
   * trip, make any required empty trip, and then make pax's trip.
   */
  void serve_pax(size_t k, const BWPax &pax);

  /**
   * Called in each time frame; records queue lengths at each station.
   */
  void record_queue_lengths();

  /**
   * Record statistics for given passenger.
   */
  void record_pax_served(const BWPax &pax, size_t empty_origin, BWTime pickup);

  /**
   * Number of vehicles that have destination i; these may be moving to i or
   * idle at i.
   */
  int num_vehicles_inbound(size_t i) const;

  /**
   * Number of vehicles that have destination i and have passed the origin
   * station of their last assigned trip; these may be moving to i or idle at
   * i. The result differs from num_vehicles_inbound when a vehicle has been
   * assigned a new trip before it has finished its current trip. The idea here
   * is to better match the definition of inbound that one usually finds in PRT
   * simulators.
   */
  int num_vehicles_immediately_inbound(size_t i) const;

  /**
   * Index of an idle vehicle at origin, or numeric_limits<size_t>::max() if
   * there are no idle vehicles at origin. If there are several idle vehicles,
   * the one with the lowest index is chosen.
   */
  size_t idle_veh_at(size_t i) const;
};

struct BWReactiveHandler {
  explicit inline BWReactiveHandler(BWSim &sim) : sim(sim) { }
  virtual ~BWReactiveHandler() { }

  /**
   * Assign a vehicle to serve the given passenger.
   *
   * @param sim current system state
   *
   * @param pax passenger that just arrived; note pax.arrive == sim.now
   *
   * @return index of the vehicle to serve this request, or
   * numeric_limits<size_t>::max() to drop the passenger (or if the handler
   * has already updated the vehicle state and called the appropriate proactive
   * handler)
   */
  virtual size_t handle_pax(const BWPax &pax) = 0;

  /**
   * The simulation to which this handler is attached.
   */
  BWSim &sim;
};

struct BWProactiveHandler {
  explicit inline BWProactiveHandler(BWSim &sim) : sim(sim) { }
  virtual ~BWProactiveHandler() { }

  /**
   * Called after a passenger has arrived and been assigned a vehicle by the
   * reactive handler.
   *
   * @param sim current system state
   *
   * @param empty_origin station that the arriving passenger's assigned vehicle
   * came from (a re-supply movement may be called for)
   */
  inline virtual void handle_pax_served(size_t empty_origin)
  { }

  /**
   * Called when the given vehicle becomes idle.
   *
   * @param sim current system state
   *
   * @param veh vehicle that just became idle at veh.destin (vehicle may now be
   * moved to another station)
   */
  inline virtual void handle_idle(BWVehicle &veh) { }

  /**
   * Called when the strobe triggers (for periodic empty redistribution).
   *
   * @param sim current system state
   */
  inline virtual void handle_strobe() { }

  /**
   * The simulation to which this handler is attached.
   */
  BWSim &sim;
};

/**
 * The original Bell and Wong Nearest Neighbours (BWNN) heuristic.
 */
struct BWNNHandler : public BWReactiveHandler {
  explicit inline BWNNHandler(BWSim &sim) : BWReactiveHandler(sim) { }
  virtual ~BWNNHandler() { }
  virtual size_t handle_pax(const BWPax &pax);
};

/**
 * Static version of BWNN for comparison; this heuristic "cheats:" it is allowed
 * to move idle vehicles in the past.
 */
struct BWSNNHandler : public BWReactiveHandler {
  explicit inline BWSNNHandler(BWSim &sim) : BWReactiveHandler(sim) { }
  virtual ~BWSNNHandler() { }

  /**
   * Choose vehicle to handle pax using SNN heuristic.
   *
   * @return index of chosen vehicle (k_star)
   */
  static size_t choose_veh(const BWPax &pax, const std::vector<BWVehicle> &vehs,
      const boost::numeric::ublas::matrix<int> &trip_time);

  /**
   * Update chosen vehicle (see choose_veh) to serve pax.
   *
   * @return the passenger's pickup time
   */
  static BWTime update_veh(const BWPax &pax, std::vector<BWVehicle> &vehs,
      const boost::numeric::ublas::matrix<int> &trip_time, size_t k_star);

  virtual size_t handle_pax(const BWPax &pax);
};

}

#endif
