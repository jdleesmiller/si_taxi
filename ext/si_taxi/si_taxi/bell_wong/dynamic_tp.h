#ifndef SI_TAXI_BELL_WONG_DTP_H_
#define SI_TAXI_BELL_WONG_DTP_H_

#include "bell_wong.h"

namespace si_taxi {

/**
 * The Dynamic Transportation Problem (DTP) heuristic.
 *
 * Note that there is only one transportation problem solver instance, so you
 * must use at most one instance of BWDynamicTransportationProblemHandler at a
 * time.
 */
struct BWDynamicTransportationProblemHandler : public BWProactiveHandler {
  /**
   * @param sim
   */
  BWDynamicTransportationProblemHandler(BWSim &sim);

  /// Destructor.
  virtual ~BWDynamicTransportationProblemHandler();

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
   * Get currently configured problem in format for the original relax4 solver.
   */
  std::string dump_problem();

protected:

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
