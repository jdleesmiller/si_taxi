#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include "dynamic_tp.h"

extern "C" {
#include <si_taxi/relax4.h>
}

using namespace std;

namespace si_taxi {

BWDynamicTransportationProblemHandler::BWDynamicTransportationProblemHandler(
    BWSim &sim) : BWProactiveHandler(sim) {
  targets.resize(sim.num_stations(), 0);

  start_nodes = new int[num_arcs()];
  end_nodes = new int[num_arcs()];
  costs = new int[num_arcs()];
  capacities = new int[num_arcs()];
  demands = new int[num_nodes()];
  flows = new int[num_arcs()];

  relax4_init(num_nodes(), num_arcs(),
      start_nodes, end_nodes, costs, capacities,
      demands, flows, RELAX4_DEFAULT_LARGE);

  // Arcs from every station to every other station.
  size_t a = 0;
  for (int i = 0; i < num_stations(); ++i) {
    for (int j = 0; j < num_stations(); ++j) {
      if (i != j) {
        start_nodes[a] = i+1;
        end_nodes[a] = j+1;
        costs[a] = sim.trip_time(i, j);
        ++a;
      }
    }
  }

  // Arcs from source to every station.
  for (int i = 0; i < num_stations(); ++i) {
    start_nodes[a] = source_node();
    end_nodes[a] = i+1;
    costs[a] = 0;
    ++a;
  }

  // Arcs from every station to sink.
  for (int i = 0; i < num_stations(); ++i) {
    start_nodes[a] = i+1;
    end_nodes[a] = sink_node();
    costs[a] = 0;
    ++a;
  }

  CHECK(a == (size_t)num_arcs());
}

BWDynamicTransportationProblemHandler::
	~BWDynamicTransportationProblemHandler() {
  relax4_free();
  delete[] start_nodes;
  delete[] end_nodes;
  delete[] costs;
  delete[] capacities;
  delete[] demands;
  delete[] flows;
}

void BWDynamicTransportationProblemHandler::handle_pax_served(
    size_t empty_origin) {
  redistribute();
}

void BWDynamicTransportationProblemHandler::handle_idle(BWVehicle &veh) {
  redistribute();
}

void BWDynamicTransportationProblemHandler::handle_strobe() {
  redistribute();
}

void BWDynamicTransportationProblemHandler::redistribute() {
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    demands[i] = -min(
        sim.num_vehicles_inbound(i) - targets[i],
        sim.num_vehicles_idle_by(i, sim.now));
  }

  set_source_sink_demands();
  solve();
  move_by_flows();
}

string BWDynamicTransportationProblemHandler::dump_problem() {
  ostringstream os;
  os << num_nodes() << "\t" << num_arcs() << "\n";
  for (int i = 0; i < num_arcs(); ++i) {
    os << start_nodes[i] << "\t" << end_nodes[i] << "\t" << costs[i] << "\t"
        << capacities[i] << "\n";
  }
  for (int i = 0; i < num_nodes(); ++i) {
    os << -demands[i] << "\n"; // NB: these are surpluses
  }
  return os.str();
}

void BWDynamicTransportationProblemHandler::set_source_sink_demands() {
  int net_demand = 0;
  for (size_t i = 0; i < sim.num_stations(); ++i)
    net_demand += demands[i];

  // Balance flows with source/sink.
  if (net_demand >= 0) {
    demands[source_node() - 1] = -net_demand;
    demands[sink_node() - 1] = 0;
  } else {
    demands[source_node() - 1] = 0;
    demands[sink_node() - 1] = -net_demand;
  }
}

void BWDynamicTransportationProblemHandler::solve() {
  // Problem is uncapacitated. This has to be reset each time.
  // I've seen one problem incorrectly judged infeasible when using
  // RELAX4_UNCAPACITATED, so I am using a multiple of the fleet size.
  // While we can't actually move more than the fleet size on any one link at
  // one time, the targets may be higher than the fleet size; it seems highly
  // unlikely that we'd ever set targets 100x higher. However, some test cases
  // have very small fleets and large demands.
  for (int a = 0; a < num_arcs(); ++a) {
    capacities[a] = 100 * sim.vehs.size();
  }

  //for (int i = 0; i < num_nodes(); ++i) TV(demands[i]);

#ifndef NDEBUG
  string temp = dump_problem();
#endif
  CHECK(RELAX4_OK == relax4_check_inputs(RELAX4_DEFAULT_MAX_COST));
  CHECK(RELAX4_OK == relax4_init_phase_1());
  CHECK(RELAX4_OK == relax4_init_phase_2());
#ifndef NDEBUG
  int result = relax4_run();
  if (RELAX4_INFEASIBLE == result)
    FAIL("infeasible:\n" << temp);
  CHECK(RELAX4_OK == result);
#else
  CHECK(RELAX4_OK == relax4_run());
#endif
  CHECK(RELAX4_OK == relax4_check_output());

  //for (int a = 0; a < num_arcs(); ++a) TV(flows[a]);
}

void BWDynamicTransportationProblemHandler::move_by_flows() {
  // Check station-to-station flows for movements to make.
  size_t a = 0;
  for (int i = 0; i < num_stations(); ++i) {
    for (int j = 0; j < num_stations(); ++j) {
      if (i != j) {
        ASSERT(flows[a] >= 0);
        ASSERT(a < (size_t)num_arcs());
        while (flows[a] > 0) {
          ASSERT(sim.num_vehicles_idle_by(i, sim.now) > 0);
          sim.move_empty_od(i, j);
          --(flows[a]);
        }
        ++a;
      }
    }
  }
}

}
