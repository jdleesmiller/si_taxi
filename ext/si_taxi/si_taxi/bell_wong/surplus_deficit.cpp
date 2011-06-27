#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include <si_taxi/od_matrix_wrapper.h>
#include "surplus_deficit.h"

#include <ext/numeric> // for iota
using namespace std;

namespace si_taxi {

BWSurplusDeficitHandler::BWSurplusDeficitHandler(BWSim &sim,
    BWCallTimeTracker &call_time, boost::numeric::ublas::matrix<double> od) :
  BWProactiveHandler(sim), _call_time(call_time), _od(od) {
}

void BWSurplusDeficitHandler::init() {
  _call_time.init();
}

void BWSurplusDeficitHandler::handle_pax_served(size_t empty_origin) {
  // count idle vehicles
  vector<int> idle_vehs(sim.num_stations());
  sim.count_idle_vehs(idle_vehs);

  // sort stations in ascending order by number of vehicles
  vector<size_t> pi(sim.num_stations());
  __gnu_cxx::iota(pi.begin(), pi.end(), 0);
  sort(pi.begin(), pi.end(), compare_perm(idle_vehs));

  // process stations with more idle vehicles first (descending order)
  for (vector<size_t>::const_reverse_iterator rit = pi.rbegin(); rit
      != pi.rend(); ++rit) {
    // stop when we run out of idle vehicles.
    if (idle_vehs[*rit] == 0)
      break;
    if (surplus_at(*rit) >= 1)
      send_idle_veh_to_nearest_deficit(*rit);
  }
}

void BWSurplusDeficitHandler::handle_idle(BWVehicle &veh) {
  if (surplus_at(veh.destin) >= 1)
    send_idle_veh_to_nearest_deficit(veh.destin);
}

double BWSurplusDeficitHandler::surplus_at(size_t i) const {
  int inbound_i = sim.num_vehicles_inbound(i);
  double demand_i = _call_time.at(i) * _od.rate_from(i);
  return inbound_i - demand_i;
}

void BWSurplusDeficitHandler::send_idle_veh_to_nearest_deficit(size_t origin) {
  // Send to destination with surplus < 0 and minimum T_ij.
  size_t best_destin = origin;
  BWTime min_time = numeric_limits<BWTime>::max();
  for (size_t destin = 0; destin < sim.num_stations(); ++destin) {
    if (origin != destin && sim.trip_time(origin, destin) < min_time
        && surplus_at(destin) < 0) {
      min_time = sim.trip_time(origin, destin);
      best_destin = destin;
    }
  }

  if (origin != best_destin) {
    _call_time.update(origin, best_destin);
    sim.move_empty(origin, best_destin);
  }
}

}
