#ifndef SI_TAXI_BELL_WONG_DTP_H_
#define SI_TAXI_BELL_WONG_DTP_H_

#include "bell_wong.h"
#include <si_taxi/od_matrix_wrapper.h>

namespace si_taxi {

/**
 *
 */
struct BWDynamicTransportationProblemHandler : public BWProactiveHandler {
  /**
   * @param sim
   * @param od with entries in vehicles per second
   */
  BWDynamicTransportationProblemHandler(BWSim &sim,
      boost::numeric::ublas::matrix<double> od);

  /// Destructor.
  ~BWDynamicTransportationProblemHandler();

  /**
   * Override.
   */
  virtual void handle_pax_served(size_t empty_origin);

  /**
   * Override.
   */
  virtual void handle_idle(BWVehicle &veh);

  /**
   * Override.
   */
  virtual void handle_strobe();

  /**
   * Set up the transportation, solve, and move vehicles.
   */
  void redistribute();

  /// Shorthand for sim.num_stations().
  inline int num_stations() const { return sim.num_stations(); }
  /// One node per station plus source and sink.
  inline int num_nodes() const { return num_stations() + 2; }
  /// Every station links to every other station (N-1) + source and sink.
  inline int num_arcs() const { return num_stations() * (num_stations() + 1); }
  /// Source and sink are numbered after stations.
  inline int source_node() const { return num_stations() + 1; }
  /// Source and sink are numbered after stations.
  inline int sink_node() const { return num_stations() + 2; }

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

  /**
   * Print currently configured problem in format for the original relax4
   * solver to string.
   */
  std::string dump_problem();

protected:
  /// See od()
  ODMatrixWrapper _od;

  /**
   * Set source and sink demand to balance out the given net_demand, which is
   * the sum of demands for all station nodes.
   */
  void set_source_sink_demands();

  /**
   * Solve the minimum cost flow problem; the demands (and costs, etc.) must
   * have been set up before this is called.
   */
  void solve();

  /**
   * Move idle vehicles according to flows.
   */
  void move_by_flows();

  int *start_nodes;
  int *end_nodes;
  int *costs;
  int *capacities;
  int *demands;
  int *flows;

public:
  /// see redistribute(...)
  std::vector<int> targets;
};

}

#endif // guard
