/**
 * These are intended mainly for profiling.
 */
#include <si_taxi/stdafx.h>
#include <si_taxi/si_taxi.h>
#include <si_taxi/utility.h>
#include <si_taxi/bell_wong/bell_wong.h>
#include <si_taxi/bell_wong/dynamic_tp.h>

using namespace std;
using namespace si_taxi;

void test_bell_wong_dynamic_tp_example() {
  size_t num_pax = 5000;
  size_t reps = 500;
  size_t num_veh = 10;
  unsigned int seed = 123;

  si_taxi::BWSim sim;

  // network_name: star_5st_2min_del01s
  CHECK(from_s(sim.trip_time, "[5,5]("
      "(0, 121, 121, 121, 121),"
      "(121, 0, 181, 241, 241),"
      "(121, 241, 0, 241, 241),"
      "(121, 161, 241, 0, 161),"
      "(121, 161, 241, 241, 0))"));

  // demand_name: out (scaled for 10 vehicles)
  boost::numeric::ublas::matrix<double> scaled_od_demand;
  CHECK(from_s(scaled_od_demand, "[5,5]("
      "(0.0, 0.00516528, 0.00516528, 0.00516528, 0.00516528),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0))"));

  sim.add_vehicles_in_turn(num_veh);

  BWNNHandler reactive(sim);
  BWDynamicTransportationProblemHandler proactive(sim);
  proactive.targets[0] = 5;
  BWSimStatsMeanPaxWait stats(sim);

  sim.reactive = &reactive;
  sim.proactive = &proactive;
  sim.stats = &stats;

  BWPoissonPaxStream pax_stream(0, scaled_od_demand);

  si_taxi::rng.seed(seed);
  for (size_t rep = 0; rep < reps; ++rep) {
    sim.init();
    pax_stream.reset(0);
    sim.park_vehicles_in_turn();

    sim.handle_pax_stream(num_pax, &pax_stream);

    cout << stats.mean_pax_wait << endl;
  }
}

int main(int *argc, char **argv) {
  test_bell_wong_dynamic_tp_example();
  return 0;
}
