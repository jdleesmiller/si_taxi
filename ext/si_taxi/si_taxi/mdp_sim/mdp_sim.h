#ifndef SI_TAXI_MDP_SIM_H_
#define SI_TAXI_MDP_SIM_H_

#include <si_taxi/si_taxi.h>
#include <si_taxi/natural_histogram.h>
#include <si_taxi/od_matrix_wrapper.h>

// we re-use several of the primitives (including BWTime and BWPax) here
#include <si_taxi/bell_wong/bell_wong.h>

#include <queue>

namespace si_taxi {

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
  /// Current simulation time.
  BWTime now;
  /// Station-station trip times in seconds; zeros on the diagonal.
  boost::numeric::ublas::matrix<int> trip_time;
  /// Queued requests at each station.
  std::vector<std::deque<BWPax> > queue;
  /// Arrival times of vehicles inbound to each station.
  std::priority_queue<BWTime,
    std::vector<BWTime>, std::greater<BWTime> > inbound;

  void tick();
};

}

#endif
