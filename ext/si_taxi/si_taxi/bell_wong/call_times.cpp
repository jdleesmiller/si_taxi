#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include "call_times.h"

using namespace std;

namespace si_taxi {

// Compensate for floating point errors in call time comparisons.
const double EPSILON = 1e-3;

BWCallTimeTracker::BWCallTimeTracker(BWSim &sim) : sim(sim) {
  // One entry for each station.
  call_time.resize(sim.num_stations());
  this->init();
}

void BWCallTimeTracker::init() {
  call.clear();
  call.resize(sim.num_stations(), 0);

  // initialise call times according to closest upstream station
  for (size_t i = 0; i < sim.trip_time.size1(); ++i) {
    int min_time = numeric_limits<int>::max();
    for (size_t j = 0; j < sim.trip_time.size2(); ++j) {
      if (i != j && sim.trip_time(j, i) < min_time) {
        min_time = sim.trip_time(j, i);
        call_time[i] = min_time;
      }
    }
  }
}

void BWCallTimeTracker::update(size_t ev_origin, size_t ev_destin) {
  ASSERT(ev_origin < sim.num_stations());
  ASSERT(ev_destin < sim.num_stations());
  if (ev_origin != ev_destin) {
    call_time[ev_destin] = cumulative_moving_average(
        (double)sim.trip_time(ev_origin, ev_destin),
        call_time[ev_destin],
        call[ev_destin]);
  }
}

int BWCallTimeTracker::num_vehicles_inbound_in_call_time(size_t i) const {
  ASSERT(i < sim.num_stations());
  int count = 0;
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    if (sim.vehs[k].destin == i &&
        sim.vehs[k].arrive <= sim.now + EPSILON + this->at(i)) {
      ++count;
    }
  }
  return count;
}

int BWCallTimeTracker::num_vehicles_immediately_inbound_in_call_time(size_t i)
const {
  ASSERT(i < sim.num_stations());
  int count = 0;
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    if (sim.vehs[k].destin == i &&
        sim.vehs[k].arrive <= sim.now + min(EPSILON + this->at(i),
            (double)sim.trip_time(sim.vehs[k].origin, i))) {
      ++count;
    }
  }
  return count;
}


void BWNNHandlerWithCallTimeUpdates::init() {
  _call_time.init();
}

size_t BWNNHandlerWithCallTimeUpdates::handle_pax(const BWPax &pax) {
  size_t k_star = BWNNHandler::handle_pax(pax);
  _call_time.update(sim.vehs.at(k_star).destin, pax.origin);
  return k_star;
}

}
