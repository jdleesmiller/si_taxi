#ifndef SI_TAXI_BELL_WONG_SAMPLING_VOTING_H_
#define SI_TAXI_BELL_WONG_SAMPLING_VOTING_H_

#include "bell_wong.h"
#include <si_taxi/od_histogram.h>
#include <si_taxi/od_matrix_wrapper.h>

namespace si_taxi {

/**
 * The Sampling and Voting (SV) heuristic.
 */
struct BWSamplingVotingHandler : public BWProactiveHandler {
  /**
   * @param sim
   * @param stream not null
   */
  BWSamplingVotingHandler(BWSim &sim, BWPaxStream *pax_stream);

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
   * Make a copy of the current simulation state and adjust the arrive times of
   * idle vehicles to now, so we don't try to move them in the past.
   */
  void clone_sim_vehs(std::vector<BWVehicle> &clone_vehs) const;

  /**
   *
   */
  void sample(const std::vector<int> &idle_vehs, ODHistogram &action_hist);

  /**
   * For a given origin, find the destination with largest weight, breaking ties
   * on minimum trip time.
   */
  size_t best_destin(size_t i, const ODHistogram &action_hist);

  /**
   * For each station with idle vehicles (as counted by idle_vehs), move an
   * idle vehicle to the best destination (as defined by best_destin) for
   * that station.
   */
  void move_to_best_destin_for_each_station(const std::vector<int> &idle_vehs,
      const ODHistogram &action_hist);

  /// generates passengers for the sample sequences
  BWPaxStream *pax_stream;

  /// number of sequences to generate
  size_t num_sequences;

  /// number of requests to generate per sequence
  size_t num_pax;
};

}

#endif // guard
