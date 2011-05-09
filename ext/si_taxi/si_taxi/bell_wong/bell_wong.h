#ifndef SI_TAXI_BELL_WONG_H_
#define SI_TAXI_BELL_WONG_H_

#include <si_taxi/si_taxi.h>
#include <si_taxi/od_matrix_wrapper.h>

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

/**
 * Abstract base class for an object that generates a (notionally) infinite
 * sequence of requests. For example, BWPoissonPaxStream generates an infinite
 * sequence of passenger requests with exponentially distributed interarrival
 * times.
 */
struct BWPaxStream {
  virtual ~BWPaxStream() { }

  /**
   * Generate the next passenger in the sequence.
   */
  virtual BWPax next_pax() = 0;

  /**
   * Set the time of the next passenger arrival. This rebases the sequence
   * at time 'now.'
   */
  virtual void reset(double now) = 0;
};

struct BWReactiveHandler;  // forward declaration
struct BWProactiveHandler; // forward declaration
struct BWSimStats;         // forward declaration

/**
 * Simulation.
 *
 * Can be re-used; call init between runs.
 *
 * A passenger's waiting time is recorded as soon has he arrives, so the sim
 * does not maintain queues of passengers.
 *
 * The general order of operations is, for time step t:
 * 1) Passengers arriving at time t are assigned a vehicle (handle_pax), and
 *    proactive->handle_pax_served is called for each one in turn.
 * 2) Computed queue lengths are recorded.
 * 3) Then proactive->handle_idle is called for each vehicle that has become
 *    idle at time t (in ascending order by vehicle index).
 * 4) The strobe handler runs if strobe > 0 and t % strobe == 0.
 * 5) Repeat for time step t + 1.
 *
 * A few notes/cautions:
 * 1) If vehicles are initially created with arrive = 0, proactive->handle_idle
 *    is called for all vehicles at the start of the sim, _except_ for those
 *    that were assigned trips due to passengers arriving at time 0.
 * 2) The strobe also fires when t = 0.
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
  /// Statistics collection.
  BWSimStats *stats;

  BWSim() : now(0), strobe(0), reactive(NULL), proactive(NULL), stats(NULL) { }

  /**
   * Number of stations (or zones); this is based on the trip times.
   */
  inline size_t num_stations() const {
    return trip_time.size1();
  }

  /**
   * Prepare for run; this clears statistics and resets time to 0. It also calls
   * init on the proactive and reactive handlers. Note that all of these have
   * to be set before you call this method. It does NOT reset the vehicle state,
   * however; this is the responsibility of the caller.
   */
  void init();

  /**
   * Add num_veh vehicles, one to each station, starting at the given station.
   *
   * @param num_veh
   *
   * @param station
   */
  void add_vehicles_in_turn(size_t num_veh, size_t station=0);

  /**
   * Park all existing vehicles; park one vehicle at each station, starting at
   * the given station. Whereas add_vehicles_in_turn adds new vehicles, this
   * just moves the old ones.
   *
   * @param station in [0, num_stations())
   */
  void park_vehicles_in_turn(size_t station=0);

  /**
   * Run the simulation from now (inclusive) to time t (exclusive) *without*
   * any more passenger arrivals.
   *
   * When the method returns, now is set to t; if called with t == now, this
   * method does nothing.
   *
   * @param t at least now
   */
  void run_to(BWTime t);

  /**
   * Main simulation driver; run the simulation until the passenger arrives,
   * and then assign a vehicle to serve the passenger.
   */
  void handle_pax(const BWPax & pax);

  /**
   * Generate and handle num_pax passengers.
   *
   * This is here for efficiency reasons: it avoids the overhead of calling
   * handle_pax through the wrapper for each passenger.
   *
   * @param num_pax non-negative; number of requests to generate
   * @param pax_stream not null
   */
  void handle_pax_stream(size_t num_pax, BWPaxStream *pax_stream);

  /**
   * Begin empty trip from veh k's current destination to destin.
   */
  void move_empty(size_t k, size_t destin);

  /**
   * Begin an empty trip from the given origin to the given destination.
   * This method finds an idle vehicle at origin to do the trip (takes the
   * one with the lowest index). If origin and destin are the same, nothing
   * happens (but an idle vehicle must still be at origin).
   *
   * @return index of the idle vehicle chosen for the trip (even if origin ==
   * destin and no actual trip occurs); numeric_limits<size_t>::max() if
   * origin == destin and there are no idle vehicles at origin.
   */
  size_t move_empty_od(size_t origin, size_t destin);

  /**
   * Assign vehicle k to serve pax; this requires that k finish its current
   * trip, make any required empty trip, and then make pax's trip.
   */
  void serve_pax(size_t k, const BWPax &pax);

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
   * Number of vehicles that will be idle at i at time t, if no further actions
   * are taken.
   */
  int num_vehicles_idle_by(size_t i, BWTime t) const;

  /**
   * Index of an idle vehicle at origin, or numeric_limits<size_t>::max() if
   * there are no idle vehicles at origin. If there are several idle vehicles,
   * the one with the lowest index is chosen.
   */
  size_t idle_veh_at(size_t i) const;

  /**
   * Count idle vehicles and provide some summary stats.
   *
   * @param idle_vehs [in] must have num_stations entries; [out] per-station
   * idle vehicle counts; non-negative
   */
  void count_idle_vehs(std::vector<int> &idle_vehs) const;
};

struct BWReactiveHandler {
  explicit inline BWReactiveHandler(BWSim &sim) : sim(sim) { }
  virtual ~BWReactiveHandler() { }

  /**
   * Clear state for the next run. The number of stations and the corresponding
   * trip times will be the same for the next run, but everything else is
   * permitted to change.
   */
  inline virtual void init() { }

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
   * Clear state for the next run. The number of stations and the corresponding
   * trip times will be the same for the next run, but everything else is
   * permitted to change.
   */
  inline virtual void init() { }

  /**
   * Called after a passenger has arrived and been assigned a vehicle by the
   * reactive handler.
   *
   * @param sim current system state
   *
   * @param empty_origin the station that lost an empty vehicle due to the
   * passenger's arrival (not necessarily the passenger's origin station); it
   * maybe worth supplying a new empty vehicle.
   */
  inline virtual void handle_pax_served(size_t empty_origin)
  { }

  /**
   * Called when the given vehicle becomes idle.
   *
   * @param sim current system state
   *
   * @param veh vehicle that just became idle (it became idle at veh.destin;
   * it may now be moved to another station)
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
 * Interface for stats collection. By default, it collects no stats; subclasses
 * implement various levels of detail.
 *
 * Note that the constructor does NOT call init, but sim::init() does; the
 * state is undefined until init is called.
 */
struct BWSimStats {
  explicit inline BWSimStats(BWSim &sim) : sim(sim) { }
  virtual ~BWSimStats() { }

  /**
   * Clear all stats counters, in preparation for a new run.
   */
  inline virtual void init() { };

  /**
   * Called in each time frame; records queue lengths at each station.
   */
  inline virtual void record_queue_lengths() { };

  /**
   * Record statistics for given passenger.
   */
  inline virtual void record_pax_served(const BWPax &pax, size_t empty_origin,
      BWTime pickup) { };

  /**
   * Record an empty vehicle trip.
   */
  inline virtual void record_empty_trip(size_t empty_origin,
      size_t empty_destin) { };

  /**
   * The simulation that this object is recording from.
   */
  BWSim &sim;
};

/**
 * Collect waiting times, queue lengths and vehicle trip counts for each
 * station individually.
 */
struct BWSimStatsDetailed : public BWSimStats {
  explicit inline BWSimStatsDetailed(BWSim &sim) : BWSimStats(sim) { }
  virtual ~BWSimStatsDetailed() { }

  /// override
  virtual void init();

  /// override
  virtual void record_queue_lengths();

  /// override
  virtual void record_pax_served(const BWPax &pax, size_t empty_origin,
      BWTime pickup);

  /// override
  virtual void record_empty_trip(size_t empty_origin, size_t empty_destin);

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
};

/**
 * Collect mean passenger waiting time only.
 */
struct BWSimStatsMeanPaxWait : public BWSimStats {
  explicit inline BWSimStatsMeanPaxWait(BWSim &sim) : BWSimStats(sim),
      mean_pax_wait(std::numeric_limits<double>::quiet_NaN()), pax_count(0) { }
  virtual ~BWSimStatsMeanPaxWait() { }

  /// override
  virtual void init();

  /**
   * Record statistics for given passenger.
   */
  virtual void record_pax_served(const BWPax &pax, size_t empty_origin,
      BWTime pickup);

  double mean_pax_wait;
  int pax_count;
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
 * The original Bell and Wong Nearest Neighbours (BWNN) heuristic.
 */
struct BWH1Handler : public BWReactiveHandler {
  explicit inline BWH1Handler(BWSim &sim, double alpha);
  virtual ~BWH1Handler() { }
  virtual size_t handle_pax(const BWPax &pax);

  /**
   * Factor that weights future waiting time against current waiting time.
   *
   * @return non-negative
   */
  double alpha() const {
    return _alpha;
  }

  /**
   * Used for forecasting; entries in vehicle trips / second.
   */
  const ODMatrixWrapper &od() const {
    return _od;
  }

private:
  /// see alpha()
  double _alpha;

  /// see od()
  ODMatrixWrapper _od;
};

/**
 * Empty Time Nearest Neighbours (ETNN) heuristic; this is really a nearest
 * neighbours heuristic: it assigns the empty vehicle with the minimum extra
 * empty vehicle trip time. If there is a tie, it minimises the request's
 * waiting time.
 */
struct BWETNNHandler : public BWReactiveHandler {
  explicit inline BWETNNHandler(BWSim &sim) : BWReactiveHandler(sim) { }
  virtual ~BWETNNHandler() { }
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
  static BWTime update_veh(const BWPax &pax, BWVehicle &veh,
      const boost::numeric::ublas::matrix<int> &trip_time);

  virtual size_t handle_pax(const BWPax &pax);
};

/**
 * Generates a stream of passenger requests from an OD matrix. Times between
 * requests are exponentially distributed (before rounding to the nearest
 * time step).
 */
struct BWPoissonPaxStream : public BWPaxStream {
  /**
   * @param now non-negative; the first request arrives some time after now
   * @param od used to generate the requests; entries in vehicles per second
   */
  BWPoissonPaxStream(double now, boost::numeric::ublas::matrix<double> od);

  /// override
  virtual BWPax next_pax();

  /// override
  inline virtual void reset(double now) { last_time = now; }

  /// time at which the last request was be generated, in seconds
  double last_time;

  /**
   * Demand matrix with entries in vehicle trips / second.
   */
  const ODMatrixWrapper &od() const {
    return _od;
  }

protected:
  /// see od()
  ODMatrixWrapper _od;
};

/**
 * Generates a given stream of passengers; this is intended for testing code
 * that relies on random passenger arrivals (e.g. from BWPoissonPaxStream).
 *
 * If the pax vector is empty, next_pax raises an error. The returned
 * passengers have an offset (as set by reset()) added to their arrival time.
 */
struct BWTestPaxStream : public BWPaxStream {
  BWTestPaxStream();

  /// override
  virtual BWPax next_pax();

  /// override
  virtual void reset(double now);

  /// passengers to be created (first in first out)
  std::queue<BWPax> pax;

protected:
  int offset;
};

}

#endif
