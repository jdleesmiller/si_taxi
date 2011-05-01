#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include <si_taxi/od_matrix_wrapper.h>
#include "andreasson.h"

using namespace std;

namespace si_taxi {

// Compensate for floating point errors in call time comparisons.
const double EPSILON = 1e-3;

BWAndreassonHandler::BWAndreassonHandler(BWSim &sim,
    BWCallTimeTracker &call_time, boost::numeric::ublas::matrix<double> od) :
    BWProactiveHandler(sim), _call_time(call_time), _od(od) {
  // Defaults:
  immediate_inbound_only = false;
  use_call_times_for_inbound = true;
  use_call_times_for_targets = true;
  send_when_over = true;
  call_only_from_surplus = true;
  surplus_threshold = 1.0;
  targets.resize(sim.num_stations(), 0);
  preferred.resize(sim.num_stations(), sim.num_stations());
  preferred.clear();
}

void BWAndreassonHandler::init() {
  while (!this->call_queue.empty())
    this->call_queue.pop();
  _call_time.init();
}

void BWAndreassonHandler::handle_pax_served(size_t empty_origin) {
  size_t ev_destin = empty_origin;

  double ev_destin_surplus = surplus(ev_destin);
  if (ev_destin_surplus < surplus_threshold) {
    // Want to call a vehicle.
    double min_surplus =
        call_only_from_surplus ? surplus_threshold : ev_destin_surplus;
    size_t ev_origin = find_call_origin(ev_destin, min_surplus);
    if (ev_origin == numeric_limits<size_t>::max()) {
      // No origin found; put this station on the call queue.
      call_queue.push(ev_destin);
    } else {
      size_t k = sim.idle_veh_at(ev_origin);
      if (k == numeric_limits<size_t>::max()) {
        // Found an origin, but there are no currently idle vehicles; queue it.
        call_queue.push(ev_destin);
      } else {
        _call_time.update(ev_origin, ev_destin);
        sim.move_empty(k, ev_destin);
      }
    }
  }
}

void BWAndreassonHandler::handle_idle(BWVehicle &veh) {
  size_t ev_origin = veh.destin;
  // The rationale for the = in the >= here is that a station with zero demand
  // and one vehicle should be considered to have a surplus when the surplus
  // threshold is one vehicle. It's also consistent with the corresponding test
  // in find_call_origin, and it complements the test in handle_pax_served.
  if (surplus(ev_origin) >= surplus_threshold) {
    size_t ev_destin = numeric_limits<size_t>::max();
    if (call_queue.empty()) {
      if (send_when_over)
        ev_destin = find_send_destin(ev_origin);
    } else {
      size_t call_destin = call_queue.front();
      // the ev_origin may have a call outstanding; don't use this vehicle to
      // service the call
      if (call_destin != ev_origin) {
        ev_destin = call_destin;
        call_queue.pop();
      }
    }
    if (ev_destin != numeric_limits<size_t>::max()) {
      ASSERT(ev_origin != ev_destin);
      _call_time.update(ev_origin, ev_destin);
      sim.move_empty(sim.idle_veh_at(ev_origin), ev_destin);
    }
  }
}

int BWAndreassonHandler::num_vehicles_inbound_in_call_time(size_t i) const {
  ASSERT(i < sim.num_stations());
  int count = 0;
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    if (sim.vehs[k].destin == i &&
        sim.vehs[k].arrive <= sim.now + EPSILON + _call_time.at(i)) {
      ++count;
    }
  }
  return count;
}

int BWAndreassonHandler::num_vehicles_immediately_inbound_in_call_time(size_t i)
const {
  ASSERT(i < sim.num_stations());
  int count = 0;
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    if (sim.vehs[k].destin == i &&
        sim.vehs[k].arrive <= sim.now + min(EPSILON + _call_time.at(i),
            (double)sim.trip_time(sim.vehs[k].origin, i))) {
      ++count;
    }
  }
  return count;
}

int BWAndreassonHandler::supply_at(size_t i) const {
  ASSERT(i < sim.num_stations());
  if (immediate_inbound_only && use_call_times_for_inbound) {
    return num_vehicles_immediately_inbound_in_call_time(i);
  } else if (immediate_inbound_only) {
    return sim.num_vehicles_immediately_inbound(i);
  } else if (use_call_times_for_inbound) {
    return num_vehicles_inbound_in_call_time(i);
  } else {
    return sim.num_vehicles_inbound(i);
  }
}

double BWAndreassonHandler::demand_at(size_t i) const {
  ASSERT(i < sim.num_stations());
  if (use_call_times_for_targets) {
    return _call_time.at(i) * _od.rate_from(i);
  } else {
    return targets.at(i);
  }
}

double BWAndreassonHandler::surplus(size_t i) const {
  return supply_at(i) - demand_at(i);
}

size_t BWAndreassonHandler::find_call_origin(size_t j, double min_surplus) const {
  ASSERT(j < sim.num_stations());
  size_t best_origin = numeric_limits<size_t>::max();
  size_t pref_origin = numeric_limits<size_t>::max();
  int best_time = numeric_limits<int>::max();
  int pref_time = numeric_limits<int>::max();

  for (size_t i = 0; i < sim.num_stations(); ++i) {
    if (i != j) {
      double surplus_i = surplus(i);
      if (surplus_i >= min_surplus) {
        int trip_time_i = sim.trip_time(i, j);
        if (trip_time_i < best_time) {
          best_time = trip_time_i;
          best_origin = i;
        }
        if (trip_time_i < pref_time && preferred(i, j)) {
          pref_time = trip_time_i;
          pref_origin = i;
        }
      }
    }
  }

  if (pref_origin == numeric_limits<size_t>::max())
    return best_origin;
  else
    return pref_origin;
}

size_t BWAndreassonHandler::find_send_destin(size_t i) const {
  ASSERT(i < sim.num_stations());
  size_t best_destin = numeric_limits<size_t>::max();
  size_t pref_destin = numeric_limits<size_t>::max();
  double min_surplus = 0;
  double pref_surplus = 0;

  for (size_t j = 0; j < sim.num_stations(); ++j) {
    if (i != j) {
      double surplus_j = surplus(j);
      if (surplus_j < min_surplus) {
        min_surplus = surplus_j;
        best_destin = j;
      }
      if (surplus_j < pref_surplus && preferred(i, j)) {
        pref_surplus = surplus_j;
        pref_destin = j;
      }
    }
  }

  if (pref_destin == numeric_limits<size_t>::max())
    return best_destin;
  else
    return pref_destin;
}

}
