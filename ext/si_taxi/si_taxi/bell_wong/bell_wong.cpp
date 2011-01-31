#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include "bell_wong.h"

using namespace std;

namespace si_taxi {

void BWSim::init() {
  now = 0;
  pax_wait.clear();
  pax_wait.resize(num_stations());
  queue_len.clear();
  queue_len.resize(num_stations());
  pickups.clear();
  pickups.resize(num_stations());

  occupied_trips.resize(num_stations(), num_stations());
  occupied_trips.clear();
  empty_trips.resize(num_stations(), num_stations());
  empty_trips.clear();
}

void BWSim::run_to(BWTime t) {
  ASSERT(this->reactive);
  ASSERT(this->proactive);
  ASSERT(t >= now);

  for (; now < t; ++now) {
    // Record queue length stats.
    record_queue_lengths();

    // Catch up on vehicle idle events.
    for (size_t k = 0; k < vehs.size(); ++k) {
      if (vehs[k].arrive == now) {
        proactive->handle_idle(vehs[k]);
      }
    }

    // Catch up on strobe events if strobe is enabled.
    if (strobe > 0 && now % strobe == 0) {
      proactive->handle_strobe();
    }
  }
}

void BWSim::handle_pax(const BWPax & pax) {
  //TV(this->now);
  ASSERT(pax.origin < num_stations());
  ASSERT(pax.destin < num_stations());

  // Run the sim up to just before the passenger's arrival...
  this->run_to(pax.arrive);

  // then handle the new arrival.
  size_t k = reactive->handle_pax(pax);
  if (k != numeric_limits<size_t>::max()) {
    size_t empty_origin = vehs.at(k).destin;
    serve_pax(k, pax);
    proactive->handle_pax_served(empty_origin);
  }
}

void BWSim::move_empty(size_t k, size_t destin) {
  CHECK(k < vehs.size());
  BWVehicle &veh = vehs[k];

  ASSERT(destin < num_stations());
  ASSERT(veh.destin < num_stations());

  ++empty_trips(veh.destin, destin);

  veh.origin = veh.destin;
  veh.destin = destin;
  veh.arrive = max(veh.arrive, now) + trip_time(veh.origin, veh.destin);
}

void BWSim::serve_pax(size_t k, const BWPax &pax) {
  CHECK(k < vehs.size());
  BWVehicle &veh = vehs[k];

  ASSERT(veh.origin < num_stations());
  ASSERT(veh.destin < num_stations());

  BWTime pickup = max(veh.arrive, now) + trip_time(veh.destin, pax.origin);
  record_pax_served(pax, veh.destin, pickup);

  veh.arrive = pickup + trip_time(pax.origin, pax.destin);
  veh.origin = pax.origin;
  veh.destin = pax.destin;
}

void BWSim::record_queue_lengths() {
  for (size_t i = 0; i < num_stations(); ++i) {
    // Remove passengers that have already been served.
    while (!pickups[i].empty() && pickups[i].top() <= now)
      pickups[i].pop();
    // Record remaining queue; length is the number of future serve_times.
    queue_len[i].increment(pickups[i].size());
  }
}

void BWSim::record_pax_served(const BWPax &pax, size_t empty_origin,
    BWTime pickup) {
  CHECK(pickup >= pax.arrive);
  ASSERT(empty_origin < num_stations());

  // Record empty and occupied vehicle trips.
  ++empty_trips(empty_origin, pax.origin);
  ++occupied_trips(pax.origin, pax.destin);

  // Record waiting time; update pickups so we can get queue lengths.
  size_t wait = (size_t)(pickup - pax.arrive);
  pax_wait.at(pax.origin).increment(wait);
  if (wait > 0) {
    // Don't push when wait is 0; we'd just pop it off before counting it.
    pickups.at(pax.origin).push(pickup);
  }
}

int BWSim::num_vehicles_inbound(size_t i) const {
  ASSERT(i < num_stations());
  int count = 0;
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].destin == i) {
      ++count;
    }
  }
  return count;
}

int BWSim::num_vehicles_immediately_inbound(size_t i) const {
  ASSERT(i < num_stations());
  int count = 0;
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].destin == i &&
        vehs[k].arrive <= now + trip_time(vehs[k].origin, i)) {
      ++count;
    }
  }
  return count;
}

size_t BWSim::idle_veh_at(size_t i) const {
  ASSERT(i < num_stations());
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].destin == i && vehs[k].arrive <= now) {
      return k;
    }
  }
  return numeric_limits<size_t>::max();
}

size_t BWNNHandler::handle_pax(const BWPax &pax) {
  ASSERT(pax.origin < sim.num_stations());
  ASSERT(pax.destin < sim.num_stations());
  ASSERT(pax.arrive == sim.now);
  size_t k_star = numeric_limits<size_t>::max();
  BWTime w_star = numeric_limits<BWTime>::max();
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    BWTime w_k = std::max((BWTime)0, sim.vehs[k].arrive - pax.arrive) +
        sim.trip_time(sim.vehs[k].destin, pax.origin);
    if (w_k < w_star) {
      k_star = k;
      w_star = w_k;
    }
  }
  ASSERT(k_star != numeric_limits<size_t>::max());
  return k_star;
}

size_t BWSNNHandler::choose_veh(const BWPax &pax, const vector<BWVehicle> &vehs,
    const boost::numeric::ublas::matrix<int> &trip_time) {
  int ks_empty = trip_time(vehs[0].destin, pax.origin);
  BWTime ks_arrive = vehs[0].arrive + ks_empty;
  BWTime ks_wait = max((BWTime)0, ks_arrive - pax.arrive);
  size_t ks = 0;

  for (size_t k = 1; k < vehs.size(); ++k) {
    int k_empty = trip_time(vehs[k].destin, pax.origin);
    BWTime k_arrive = vehs[k].arrive + k_empty;
    BWTime k_wait = max((BWTime)0, k_arrive - pax.arrive);

    bool new_ks = k_wait < ks_wait;
    if (!new_ks && k_wait == ks_wait) {
      new_ks = k_empty < ks_empty;
      if (!new_ks && k_empty == ks_empty) {
        new_ks = k_arrive > ks_arrive;
        if (!new_ks)
        new_ks = k < ks;
      }
    }

    if (new_ks) {
      ks = k;
      ks_empty = k_empty;
      ks_arrive = k_arrive;
      ks_wait = k_wait;
    }
  }

  return ks;
}

BWTime BWSNNHandler::update_veh(const BWPax &pax, vector<BWVehicle> &vehs,
    const boost::numeric::ublas::matrix<int> &trip_time, size_t k_star) {
  int ks_empty = trip_time(vehs[k_star].destin, pax.origin);
  BWTime ks_arrive = vehs[k_star].arrive + ks_empty;
  BWTime pickup = max(ks_arrive, pax.arrive);

  vehs[k_star].arrive = pickup + trip_time(pax.origin, pax.destin);
  vehs[k_star].origin = pax.origin;
  vehs[k_star].destin = pax.destin;

  return pickup;
}

size_t BWSNNHandler::handle_pax(const BWPax &pax) {
  size_t k_star = BWSNNHandler::choose_veh(pax, sim.vehs, sim.trip_time);

  // Update sim state here, because we're not following the usual update rules.
  size_t empty_origin = sim.vehs[k_star].destin;
  BWTime pickup = BWSNNHandler::update_veh(
      pax, sim.vehs, sim.trip_time, k_star);
  sim.record_pax_served(pax, empty_origin, pickup);

  return numeric_limits<size_t>::max(); // sim state already updated
}

}
