#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include "sampling_voting.h"

using namespace std;

namespace si_taxi {

BWSamplingVotingHandler::BWSamplingVotingHandler(BWSim &sim,
    BWPaxStream *pax_stream) : BWProactiveHandler(sim), pax_stream(pax_stream),
    num_sequences(0), num_pax(0) {
}

void BWSamplingVotingHandler::handle_pax_served(
    size_t empty_origin) {
  handle_strobe(); // same as strobe
}

void BWSamplingVotingHandler::handle_idle(BWVehicle &veh) {
  // Run for only the station where the vehicle became idle.
  vector<int> idle_vehs(sim.num_stations(), 0);
  ODHistogram action_hist(sim.num_stations());
  idle_vehs[veh.destin] = sim.num_vehicles_idle_by(veh.destin, sim.now);
  //TV(sim.now);
  //TV(idle_vehs);
  sample(idle_vehs, action_hist);
  //TV(action_hist);
  move_to_best_destin_for_each_station(idle_vehs, action_hist);
}

void BWSamplingVotingHandler::handle_strobe() {
  // Run for all stations.
  vector<int> idle_vehs(sim.num_stations(), 0);
  ODHistogram action_hist(sim.num_stations());
  sim.count_idle_vehs(idle_vehs);
  //TV(sim.now);
  //TV(idle_vehs);
  sample(idle_vehs, action_hist);
  //TV(action_hist);
  move_to_best_destin_for_each_station(idle_vehs, action_hist);
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

void BWSamplingVotingHandler::sample(const std::vector<int> &idle_vehs,
    ODHistogram &action_hist) {
  vector<BWVehicle> clone_vehs;

  vector<int> num_trivial_idle_trips(sim.num_stations());
  vector<size_t> first_idle_nt_destins(sim.num_stations()); // nt = nontrivial
  vector<size_t> first_destins(sim.num_stations());

  action_hist.clear();

  // Can stop early if we have assigned destinations for all stations with
  // idle vehicles.
  int num_idle_vehs = 0, num_stations_with_idle_vehs = 0;
  for (size_t i = 0; i < idle_vehs.size(); ++i) {
    num_idle_vehs += idle_vehs[i];
    if (idle_vehs[i] > 0) {
      ++num_stations_with_idle_vehs;
    }
  }
  ASSERT(0 <= num_idle_vehs && num_idle_vehs <= (int)sim.vehs.size());
  ASSERT(0 <= num_stations_with_idle_vehs &&
      num_stations_with_idle_vehs <= (int)sim.num_stations());

  // Stop if there's nothing to move.
  if (num_idle_vehs == 0)
    return;

  for (size_t s = 0; s < num_sequences; ++s) {
    // Copy system state.
    clone_sim_vehs(BYREF clone_vehs);

    int first_idle_nt_destins_done = 0;
    first_idle_nt_destins.assign(first_idle_nt_destins.size(), SIZE_T_MAX);
    num_trivial_idle_trips.assign(num_trivial_idle_trips.size(), 0);
    first_destins.assign(first_destins.size(), SIZE_T_MAX);

    // Generate sample and process.
    pax_stream->reset(sim.now);
    for (size_t p = 0; p < num_pax; ++p) {
      BWPax pax = pax_stream->next_pax();
      //TRACE("pax" << pax.origin << "-" << pax.destin << "@" << pax.arrive);
      size_t k_star = BWSNNHandler::choose_veh(pax, clone_vehs, sim.trip_time);
      //TV(k_star);
      size_t k_origin = clone_vehs.at(k_star).destin;

      // Extracting solution features.
      bool idle = (clone_vehs[k_star].arrive <= sim.now);
      bool nontrivial = (k_origin != pax.origin);
      if (idle && nontrivial) {
        if (first_idle_nt_destins[k_origin] == SIZE_T_MAX) {
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
        if (first_destins[k_origin] == SIZE_T_MAX) {
          first_destins[k_origin] = pax.origin;
        }
      }

      BWSNNHandler::update_veh(pax, clone_vehs[k_star], sim.trip_time);
    }

    //TV(first_idle_nt_destins);
    //TV(num_trivial_idle_trips);
    //TV(first_destins);

    // Accumulate decisions in action_hist.
    for (size_t i = 0; i < sim.num_stations(); ++i) {
      if (idle_vehs[i] == 0) {
        // nothing to do
      } else if (first_idle_nt_destins[i] != SIZE_T_MAX) {
        action_hist.increment(i, first_idle_nt_destins[i]);
      } else if (num_trivial_idle_trips[i] >= idle_vehs[i]) {
        ASSERT(num_trivial_idle_trips[i] == idle_vehs[i]);
        action_hist.increment(i, i);
      } else if (first_destins[i] != SIZE_T_MAX) {
        action_hist.increment(i, first_destins[i]);
      } else {
        action_hist.increment(i, i); // give up: leave vehicle where it is
      }
    }
  }
}

size_t BWSamplingVotingHandler::best_destin(size_t i,
    const ODHistogram &action_hist) {

  size_t best_j = numeric_limits<size_t>::max();
  int max_score = action_hist.max_weight_in_row(i);
  int min_trip_time = numeric_limits<int>::max();
  for (size_t j = 0; j < action_hist.num_stations(); ++j) {
    if (action_hist(i,j) == max_score && sim.trip_time(i,j) < min_trip_time) {
      best_j = j;
      min_trip_time = sim.trip_time(i,j);
    }
  }
  ASSERT(best_j != numeric_limits<size_t>::max());

  return best_j;
}

void BWSamplingVotingHandler::move_to_best_destin_for_each_station(
    const std::vector<int> &idle_vehs, const ODHistogram &action_hist) {
  for (size_t i = 0; i < action_hist.num_stations(); ++i) {
    if (idle_vehs[i] == 0) {
      continue;
    }
    sim.move_empty_od(i, best_destin(i, action_hist));
  }
}

}
