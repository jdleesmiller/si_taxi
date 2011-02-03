#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include "sampling_voting.h"

using namespace std;

namespace si_taxi {

BWSamplingVotingHandler::BWSamplingVotingHandler(BWSim &sim,
    BWPaxStream *pax_stream) : BWProactiveHandler(sim), pax_stream(pax_stream) {
}

void BWSamplingVotingHandler::handle_pax_served(
    size_t empty_origin) {
}

void BWSamplingVotingHandler::handle_idle(BWVehicle &veh) {
}

void BWSamplingVotingHandler::handle_strobe() {
}

void BWSamplingVotingHandler::clone_sim_vehs(
    std::vector<BWVehicle> &clone_vehs) const {
  clone_vehs = sim.vehs;
  for (size_t k = 0; k < clone_vehs.size(); ++k) {
    if (clone_vehs[k].arrive < sim.now) {
      clone_vehs[k].arrive = sim.now;
    }
  }
}

void BWSamplingVotingHandler::sample() {
  vector<BWVehicle> clone_vehs;

  vector<int> num_trivial_idle_trips(sim.num_stations());
  vector<size_t> first_idle_nt_destins(sim.num_stations()); // nt = nontrivial
  vector<size_t> first_destins(sim.num_stations());
  const size_t NONE = numeric_limits<size_t>::max();

  // Can stop early if we have assigned destinations for all stations with
  // idle vehicles.
  vector<int> idle_vehs(sim.num_stations());
  int num_idle_vehs, num_stations_with_idle_vehs;
  sim.count_idle_vehs(BYREF idle_vehs,
      BYREF num_idle_vehs,
      BYREF num_stations_with_idle_vehs);

  for (size_t s = 0; s < num_sequences; ++s) {
    // Copy system state.
    clone_sim_vehs(BYREF clone_vehs);

    int first_idle_nt_destins_done = 0;
    first_idle_nt_destins.assign(first_idle_nt_destins.size(), NONE);
    num_trivial_idle_trips.assign(num_trivial_idle_trips.size(), 0);
    first_destins.assign(first_destins.size(), NONE);

    // Generate sample and process.
    for (size_t p = 0; p < num_pax; ++p) {
      BWPax pax = pax_stream->next_pax();
      size_t k_star = BWSNNHandler::choose_veh(pax, clone_vehs, sim.trip_time);
      size_t k_origin = clone_vehs.at(k_star).destin;

      bool idle = (clone_vehs[k_star].arrive <= sim.now);
      bool nontrivial = (k_origin != pax.origin);
      if (idle && nontrivial) {
        if (first_idle_nt_destins[k_origin] == NONE) {
          first_idle_nt_destins[k_origin] = pax.origin;

          // Can stop early if we get all of these done.
          ++first_idle_nt_destins_done;
          if (first_idle_nt_destins_done >= num_stations_with_idle_vehs) {
            break;
          }
        }
      } else if (idle) {
        ++num_trivial_idle_trips[k_origin]; // idle but trivial
      } else if (nontrivial) {
        if (first_destins[k_origin] == NONE) {
          first_destins[k_origin] = pax.origin;
        }
      }

      BWSNNHandler::update_veh(pax, clone_vehs[k_star], sim.trip_time);
    }
  }
}
#if 0
    assert(idle_vehs.size() == trip_times.size1());

    vector<size_t> first_idle_nt_destins(trip_times.size1()); // nt = nontrivial
    vector<int> num_trivial_idle_trips(trip_times.size1());
    vector<size_t> first_destins(trip_times.size1());
    const size_t NONE = numeric_limits<size_t>::max();

    // Can stop early if we have assigned destinations for all stations with
    // idle vehicles.
    int num_idle_vehs, num_stations_with_idle_vehs;
    count_idle_vehs(idle_vehs, num_idle_vehs, num_stations_with_idle_vehs);

    //TV(now);
    //TV(idle_vehs);

    action_hist.clear();
    for (samples_ci_t it = samples.begin(); it != samples.end(); ++it) {
      // Reset sample_vehs for current sample.
      clone_vehs(now, vehs);

      int first_idle_nt_destins_done = 0;
      first_idle_nt_destins.assign(first_idle_nt_destins.size(), NONE);
      num_trivial_idle_trips.assign(num_trivial_idle_trips.size(), 0);
      first_destins.assign(first_destins.size(), NONE);

      sample_t::cursor_t sim(now, *it);
      while (!sim.done()) {
        pax_t pax = sim.pax(); // advance cursor
        size_t k_star = perfect_info_nn_choose(pax, sample_vehs, trip_times);
        size_t k_origin = sample_vehs[k_star].destin;
        //TV(pax.origin);
        //TV(pax.arrive);
        //TV(k_star);
        //TV(k_origin);

        bool idle = (sample_vehs[k_star].arrive <= now);
        bool nontrivial = (k_origin != pax.origin);
        if (idle && nontrivial) {
          if (first_idle_nt_destins[k_origin] == NONE) {
            first_idle_nt_destins[k_origin] = pax.origin;

            // Can stop early if we get all of these done.
            ++first_idle_nt_destins_done;
            if (first_idle_nt_destins_done >= num_stations_with_idle_vehs) {
              break;
            }
          }
        } else if (idle) {
          ++num_trivial_idle_trips[k_origin]; // idle but trivial
        } else if (nontrivial) {
          if (first_destins[k_origin] == NONE) {
            first_destins[k_origin] = pax.origin;
          }
        }

        perfect_info_nn_update(pax, sample_vehs, trip_times, k_star);
      }

      //TV(first_idle_nt_destins);
      //TV(num_trivial_idle_trips);
      //TV(first_destins);

      // Accumulate decisions in action_hist.
      for (size_t i = 0; i < trip_times.size1(); ++i) {
        if (idle_vehs[i] == 0) {
          // nothing to do
        } else if (first_idle_nt_destins[i] != NONE) {
          action_hist.increment(i, first_idle_nt_destins[i]);
        } else if (num_trivial_idle_trips[i] >= idle_vehs[i]) {
          assert(num_trivial_idle_trips[i] == idle_vehs[i]);
          action_hist.increment(i, i);
        } else if (first_destins[i] != NONE) {
          action_hist.increment(i, first_destins[i]);
        } else {
          action_hist.increment(i, i); // give up: leave vehicle where it is
        }
      }

      //TV(action_hist);
    }
  }

#endif

}
