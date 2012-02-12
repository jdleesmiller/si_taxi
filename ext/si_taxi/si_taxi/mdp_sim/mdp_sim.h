#ifndef SI_TAXI_MDP_SIM_H_
#define SI_TAXI_MDP_SIM_H_

#include <si_taxi/si_taxi.h>
#include <si_taxi/natural_histogram.h>
#include <si_taxi/od_matrix_wrapper.h>

// we re-use several of the primitives (including BWTime and BWPax) here
#include <si_taxi/bell_wong/bell_wong.h>

namespace si_taxi {

/// Origin-destination matrix of counts.
typedef boost::numeric::ublas::matrix<int> int_od_t;

/**
 *
 * queues of passengers (destin, arrival time)
 * priority queues of inbound vehicles by destination
 *   - minimum info is just the arrival time
 *   - maybe some value in keeping track of the origin (viz. only?)
 *
 * likely aggregations:
 *   - queue length per station (throw out destin)
 *     - cutoff / bins
 *   - number of inbound vehicles
 *   - number of inbound vehicles in bins
 *   -
 *
 */
struct MDPSim {

  typedef boost::numeric::ublas::vector<int> int_vector_t;

  /// Current simulation time.
  BWTime now;

  /// Station-station trip times in seconds; zeros on the diagonal.
  boost::numeric::ublas::matrix<int> trip_time;

  /**
   * Queued requests at each station.
   *
   * Note that this sim doesn't set or look at the arrival times; we could
   * instead use (origin, destination) pairs here. The convention is that
   * the passenger's arrival time is the ceiling of their actual arrival time,
   * so if they arrive in the interval (t, t+1], it's as if they arrived at
   * exactly t+1.
   */
  std::vector<std::deque<BWPax> > queue;

  /**
   * Arrival time of each vehicle inbound to each station. These are stored
   * in non-decreasing order for each station; vehicles that are idle have
   * arrival times in the past.
   */
  std::vector<std::deque<BWTime> > inbound;

  /**
   * If positive, truncate any queue longer than this. This is for comparison
   * with explicit solution methods that require a finite state space.
   */
  size_t queue_max;

  /**
   * For internal use. Undefined before init is called. After that, size is
   * num_stations().
   */
  int_vector_t available;

  /**
   * For internal use. Undefined before init is called. After that, size is
   * num_stations().
   */
  int_vector_t idle;

  /**
   * For internal use. Undefined before init is called. After that, size is
   * num_stations().
   */
  boost::numeric::ublas::scalar_vector<int> ones;

  MDPSim();

  /**
   * Number of stations (or zones); this is based on the trip times.
   */
  inline size_t num_stations() const {
    return trip_time.size1();
  }

  /**
   * Number of vehicles in the simulation. This is obtained by adding the
   * lengths of the inbound lists.
   */
  size_t num_vehicles() const;

  /**
   * Add num_veh idle vehicles, one to each station, starting at the given
   * station.
   *
   * @param num_veh
   *
   * @param station
   */
  void add_vehicles_in_turn(size_t num_veh, size_t station = 0);

  /**
   * Call after initialising trip_time but before adding vehicles (e.g. with
   * add_vehicles_in_turn) and before the first tick. This method does some
   * basic sanity checks and initialises queue (all empty) and now.
   */
  void init();

  /**
   * @param empty_trips the control action to take at time now; this is the
   *        number of idle vehicles to move between each pair of stations
   *
   * @param requests occupied vehicle trips requested by passengers in the time
   *        interval [now, now+1)
   */
  void tick(const int_od_t &empty_trips, const std::vector<BWPax> &requests);

  /**
   * Count vehicles with arrival time less than or equal to the given time.
   *
   * @param num_vehicles size num_stations(); this method doesn't zero before
   * it starts accumulating.
   */
  void count_idle_by(BWTime time, int_vector_t &num_vehicles) const;

  /**
   * Move a vehicle from orgin to destin. This pops a vehicle out of the
   * inbound list at the origin and adds one to the destination's inbound list.
   *
   * The vehicle being moved must be arriving within the next timestep (i.e.
   * arrival time <= now + 1).
   */
  void move(size_t origin, size_t destin, size_t count=1);
};

}

#endif
