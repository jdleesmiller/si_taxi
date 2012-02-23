#ifndef SI_TAXI_MDP_SIM_H_
#define SI_TAXI_MDP_SIM_H_

#include <si_taxi/si_taxi.h>
#include <si_taxi/natural_histogram.h>
#include <si_taxi/od_matrix_wrapper.h>
#include <si_taxi/mdp_sim/mdp_pax.h>

#include <queue>

namespace si_taxi {

/// Origin-destination matrix of counts.
typedef boost::numeric::ublas::matrix<int> int_od_t;

// forward declaration
struct MDPSimStats;
struct MDPPaxStream;

/**
 * A simulation consistent with MDPModelC.
 */
struct MDPSim {

  typedef boost::numeric::ublas::vector<int> int_vector_t;

  /**
   * Statistics record. If NULL, no statistics are recorded.
   */
  MDPSimStats *stats;

  /// Current simulation time.
  MDPTime now;

  /// Station-station trip times in seconds; zeros on the diagonal.
  boost::numeric::ublas::matrix<int> trip_time;

  /**
   * Queued requests at each station.
   *
   * Note that this sim doesn't set or look at the arrival times; we could
   * instead use (origin, destination) pairs here.
   */
  std::vector<std::deque<MDPPax> > queue;

  /**
   * Arrival time of each vehicle inbound to each station. These are stored
   * in non-decreasing order for each station; vehicles that are idle have
   * arrival times in the past.
   */
  std::vector<std::deque<MDPTime> > inbound;

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
  void tick(const int_od_t &empty_trips, const std::vector<MDPPax> &pax);

  /**
   * Count vehicles with arrival time less than or equal to the given time.
   *
   * @param num_vehicles size num_stations(); this method doesn't zero before
   * it starts accumulating.
   */
  void count_idle_by(MDPTime time, int_vector_t &num_vehicles) const;

  /**
   * Move a vehicle from orgin to destin. This pops a vehicle out of the
   * inbound list at the origin and adds one to the destination's inbound list.
   *
   * The vehicle being moved must be arriving within the next timestep (i.e.
   * inbound time <= now).
   */
  void move(size_t origin, size_t destin, size_t count=1);

  /**
   * Set state to the vector representation of the current state of the
   * simulation. The format is (q_1,...,q_S;b_1,...,b_S; remaining time lists),
   * which is the same as that from MDPStateC#to_a.
   *
   * @param state must have size at least 2*num_stations + num_veh
   */
  void model_c_state(std::vector<int> &state) const;

  /**
   *
   */
  size_t run_with_model_c_policy(const std::vector<std::vector<int> > &policy,
      MDPPaxStream &pax_stream, size_t num_pax,
      int policy_queue_max, double policy_step_size);
};

struct MDPSimStats
{
  const MDPSim &sim;

  /**
   * Size of simulation time step in actual time units, for recording purposes.
   * This is used to scale waiting times before rounding them in order to put
   * them into histogram bins.
   */
  double step;

  inline explicit MDPSimStats(const MDPSim &sim) : sim(sim), step(1) { }
  virtual ~MDPSimStats() { }

  virtual void init();

  /**
   * Called at the start of each time step.
   */
  virtual void record_time_step_stats();

  /**
   * Called immediately after queued requests are served.
   */
  virtual void record_reward();

  virtual void record_empty_trip(size_t origin, size_t destin, size_t count);

  virtual void record_pax_to_be_served(const MDPPax &pax);

  /**
   * Histograms of passenger waiting times, in seconds, per station.
   *
   * We can't be sure of actual vehicle or passenger arrival times within a
   * time step. However, there are two special cases that we can detect in the
   * sim:
   *
   *   1) if the vehicle was idle (i.e. its r_{i, k} was zero *before* the
   *      current time step), the request it serves has zero waiting time
   *   2) if the request is served from the queue, we know it has to wait
   *      until a vehicle gets there (vehicle was not idle)
   *   3) if both the vehicle and the request arrive in the current time step,
   *      we know the request's arrival time exactly, but we don't know the
   *      vehicle's arrival time
   *
   * In the second case, if we assume that the vehicle is equally likely to
   * arrive at any time within the time step, the MLE is 1/2 a time step. In
   * the third case, integration shows that the expected time is
   *  step * (now + 1 - p)/2
   * where p is when the passenger arrived.
   */
  std::vector<NaturalHistogram> pax_wait;

  /**
   * Histograms of passenger waiting times, in seconds, per station.
   *
   * TODO not quite right; tends to overestimate, whereas accumulated reward
   * tends to underestimate, at present; small time steps advisable
   */
  std::vector<NaturalHistogram> pax_wait_simple;

  /// Histograms of passenger queue lengths, in seconds, per station.
  std::vector<NaturalHistogram> queue_len_simple;

  /// Histograms of number of idle vehicles per station.
  std::vector<NaturalHistogram> idle_vehs_simple;

  /// Histogram of number of idle vehicles for whole network.
  NaturalHistogram idle_vehs_simple_total;

  /// Number of occupied vehicle trips observed between each pair of stations.
  boost::numeric::ublas::matrix<size_t> occupied_trips;

  /// Number of empty vehicle trips observed between each pair of stations.
  boost::numeric::ublas::matrix<size_t> empty_trips;

  /// Reward (will be non-positive) collected for each station.
  std::vector<long long> reward;
};

/**
 * Abstract base class for an object that generates a (notionally) infinite
 * sequence of requests.
 */
struct MDPPaxStream {
  virtual ~MDPPaxStream() { }

  /**
   * Generate the next passenger in the sequence.
   */
  virtual const std::vector<MDPPax> &next_pax() = 0;

  /**
   * Set the time of the next passenger arrival. This rebases the sequence
   * at time 'now.'
   */
  virtual void reset(double now) = 0;
};

/**
 * Generates a stream of passenger requests from an OD matrix. Times between
 * requests are exponentially distributed (before rounding to the nearest
 * time step). The requests are generated in batches, where each batch is
 * the set of requests that arrive in the current time step.
 */
struct MDPPoissonPaxStream : public MDPPaxStream {
  /**
   * @param now non-negative, in seconds; the first request arrives some time
   *        after now
   * @param step non-negative, in seconds; each batch is this many seconds long
   * @param od used to generate the requests; entries in vehicles per second
   */
  MDPPoissonPaxStream(double now, double step,
      const boost::numeric::ublas::matrix<double> &od);

  /// override
  virtual const std::vector<MDPPax> &next_pax();

  /// override
  virtual void reset(double now);

  /// start of the current time step, in seconds
  double now;

  /// length of one time step, in seconds
  double step;

  /// time at which the last request was be generated, in seconds
  double last_time;

  /**
   * Demand matrix with entries in vehicle trips / second.
   */
  inline const ODMatrixWrapper &od() const {
    return _od;
  }

protected:

  /// Generate a new request.
  void generate(MDPPax &pax);

  /// see od()
  ODMatrixWrapper _od;

  /// next_pax() returns a constant reference to one of these
  std::vector<MDPPax> _pax[2];

  /// index of the current pax vector
  size_t _pax_i;
};

}

#endif
