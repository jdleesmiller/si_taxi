#include "bell_wong.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

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

void BWSim::handle_pax_stream(size_t num_pax, BWPaxStream *pax_stream) {
  ASSERT(pax_stream);
  for (; num_pax > 0; --num_pax) {
    handle_pax(pax_stream->next_pax());
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

size_t BWSim::move_empty_od(size_t origin, size_t destin) {
  size_t k = idle_veh_at(origin);
  if (origin != destin) {
    // There should always be an idle vehicle to move.
    CHECK(k < vehs.size());
    move_empty(k, destin);
  }
  return k;
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

int BWSim::num_vehicles_idle_by(size_t i, BWTime t) const {
  int count = 0;
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].destin == i && vehs[k].arrive <= t) {
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

void BWSim::count_idle_vehs(std::vector<int> &idle_vehs,
  int &num_idle_vehs,
  int &num_stations_with_idle_vehs) const {
  CHECK(idle_vehs.size() == num_stations());
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].arrive <= now) {
      ++num_idle_vehs;
      int &count = idle_vehs[vehs[k].destin];
      if (count == 0) {
        ++num_stations_with_idle_vehs;
      }
      ++count;
    }
  }
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

BWTime BWSNNHandler::update_veh(const BWPax &pax, BWVehicle &veh,
    const boost::numeric::ublas::matrix<int> &trip_time) {
  int ks_empty = trip_time(veh.destin, pax.origin);
  BWTime ks_arrive = veh.arrive + ks_empty;
  BWTime pickup = max(ks_arrive, pax.arrive);

  veh.arrive = pickup + trip_time(pax.origin, pax.destin);
  veh.origin = pax.origin;
  veh.destin = pax.destin;

  return pickup;
}

size_t BWSNNHandler::handle_pax(const BWPax &pax) {
  size_t k_star = BWSNNHandler::choose_veh(pax, sim.vehs, sim.trip_time);

  // Update sim state here, because we're not following the usual update rules.
  size_t empty_origin = sim.vehs[k_star].destin;
  BWTime pickup = BWSNNHandler::update_veh(pax,
      sim.vehs[k_star], sim.trip_time);
  sim.record_pax_served(pax, empty_origin, pickup);

  return numeric_limits<size_t>::max(); // sim state already updated
}

BWPoissonPaxStream::BWPoissonPaxStream(double now,
    boost::numeric::ublas::matrix<double> od) : _next_time(now), _od(od) {
}

BWPax BWPoissonPaxStream::next_pax() {
  BWPax pax;
  double interval;
  _od.sample(BYREF pax.origin, BYREF pax.destin, BYREF interval);
  pax.arrive = (BWTime)round(_next_time);
  _next_time += interval;
  return pax;
}

}
