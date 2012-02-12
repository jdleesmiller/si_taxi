/**
 * These are intended mainly for profiling, because accurately profiling code
 * in shared objects turns out to be quite tricky. These can just be run with
 * gprof.
 *
 * Also home to tests for some functions that are too hard to expose via
 * the ruby interface.
 */
#include <si_taxi/stdafx.h>
#include <si_taxi/si_taxi.h>
#include <si_taxi/utility.h>
#include <si_taxi/bell_wong/bell_wong.h>
#include <si_taxi/bell_wong/dynamic_tp.h>
#include <si_taxi/bell_wong/sampling_voting.h>
#include <si_taxi/mdp_sim/mdp_sim.h>
#include <si_taxi/mdp_sim/tabular_sarsa_solver.h>

using namespace std;
using namespace si_taxi;

void load_star_5st_2min_del01s_trip_times(BWSim &sim) {
  CHECK(from_s(sim.trip_time, "[5,5]("
      "(0, 121, 121, 121, 121),"
      "(121, 0, 181, 241, 241),"
      "(121, 241, 0, 241, 241),"
      "(121, 161, 241, 0, 161),"
      "(121, 161, 241, 241, 0))"));
}

// demand_name: out (scaled for 10 vehicles at intensity 0.5)
void load_star_5st_2min_del01s_demand_1(boost::numeric::ublas::matrix<double> &od) {
  CHECK(from_s(od, "[5,5]("
      "(0.0, 0.00516528, 0.00516528, 0.00516528, 0.00516528),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0),"
      "(0.0, 0.0, 0.0, 0.0, 0.0))"));
}

void load_grid_24st_800m_del01s_trip_times(BWSim &sim) {
  CHECK(from_s(sim.trip_time, "[24,24]("
  "(  0, 81,161,161,401,321,481,241,321,321,561,481,241, 81,401,241,481,161,321,321,401,241,561,401),"
  "(561,  0, 81,401,321,241,721,481,561,561,481,401,481,641,321,161,721,401,561,241,641,481,481,321),"
  "(481,561,  0,321,241,161,641,401,481,481,401,321,401,561,241, 81,641,321,481,161,561,401,401,241),"
  "(161,241,321,  0,561,481,641,401,481,481,721,641, 81,241,561,401,641,321,481,481,561,401,721,561),"
  "(241,321,401, 81,  0,561,401,161,241,241,481,401,161,321,321,481,401, 81,241,561,321,161,481,321),"
  "(321,401,161,161, 81,  0,481,241,321,321,561,481,241,401, 81,241,481,161,321,321,401,241,561,401),"
  "(481,561,321,321,241,481,  0, 81,161,161,401,321,401,561,241,401,321,321,161,481,241, 81,401,241),"
  "(401,481,241,241,161,401,561,  0, 81,401,321,241,321,481,161,321,561,241, 81,401,481,321,321,161),"
  "(641,721,481,481,401,641,481,561,  0,321,241,161,561,721,401,561,481,481,321,641,401,561,241, 81),"
  "(321,401,481,481,401,641,161,241,321,  0,561,481,241,401,401,561,161,481,321,641, 81,241,561,401),"
  "(401,481,561,561,481,721,241,321,401, 81,  0,561,321,481,481,641,241,561,401,721,161,321,641,481),"
  "(481,561,321,321,241,481,321,401,161,161, 81,  0,401,561,241,401,321,321,161,481,241,401, 81,241),"
  "( 81,161,241,241,481,401,561,321,401,401,641,561,  0,161,481,321,561,241,401,401,481,321,641,481),"
  "(241,321,401, 81,321,561,401,161,241,241,481,401,161,  0,321,481,401, 81,241,561,321,161,481,321),"
  "(561,641, 81,401,321,241,721,481,561,561,481,401,481,641,  0,161,721,401,561,241,641,481,481,321),"
  "(401,481,241,241,161, 81,561,321,401,401,321,241,321,481,161,  0,561,241,401, 81,481,321,321,161),"
  "(161,241,321,321,561,481,641,401,481,481,721,641, 81,241,561,401,  0,321,481,481,561,401,721,561),"
  "(481,561,321,321,241,481,321, 81,161,161,401,321,401,561,241,401,321,  0,161,481,241, 81,401,241),"
  "(321,401,161,161, 81,321,481,241,321,321,561,481,241,401, 81,241,481,161,  0,321,401,241,561,401),"
  "(641,721,481,481,401,641,481,561,321,321,241,161,561,721,401,561,481,481,321,  0,401,561,241, 81),"
  "(241,321,401,401,321,561, 81,161,241,241,481,401,161,321,321,481, 81,401,241,561,  0,161,481,321),"
  "(401,481,561,561,481,721,241,321,401, 81,641,561,321,481,481,641,241,561,401,721,161,  0,641,481),"
  "(401,481,241,241,161,401,561,321, 81,401,321,241,321,481,161,321,561,241, 81,401,481,321,  0,161),"
  "(561,641,401,401,321,561,401,481,241,241,161, 81,481,641,321,481,401,401,241,561,321,481,161,  0))"));
}

// demand_name: am1_theta0.01 (scaled for 200 vehicles at intensity 0.5)
void load_grid_24st_800m_del01s_demand_1(boost::numeric::ublas::matrix<double> &od) {
  CHECK(from_s(od, "[24,24]("
  "(0,0.000574,9.72e-05,0.00125,0.000421,0.000236,4.76e-05,0.00209,0.000253,1.96e-05,4.73e-06,6.22e-06,4.37e-05,0.0026,0.000114,6.86e-05,1.05e-05,0.00464,0.000937,5.21e-05,1.39e-05,0.000562,2.14e-05,8.81e-06),"
  "(1.23e-05,0,0.000951,0.000499,0.00412,0.00231,1.9e-05,0.000832,0.000101,7.83e-06,4.63e-05,6.09e-05,1.74e-05,4.23e-05,0.00111,0.000672,4.2e-06,0.00185,0.000374,0.00051,5.53e-06,0.000224,0.000209,8.63e-05),"
  "(1.32e-05,1e-05,0,0.000535,0.00442,0.00247,2.04e-05,0.000892,0.000108,8.39e-06,4.96e-05,6.53e-05,1.87e-05,4.53e-05,0.00119,0.00072,4.5e-06,0.00199,0.000401,0.000546,5.92e-06,0.00024,0.000224,9.25e-05),"
  "(0.000547,0.000415,7.02e-05,0,0.000304,0.00017,3.44e-05,0.00151,0.000183,1.42e-05,3.41e-06,4.5e-06,0.000774,0.00188,8.2e-05,4.96e-05,7.6e-06,0.00335,0.000677,3.76e-05,1e-05,0.000406,1.55e-05,6.37e-06),"
  "(2.13e-05,1.61e-05,2.73e-06,0.000863,0,6.63e-06,3.28e-05,0.00144,0.000174,1.35e-05,3.26e-06,4.29e-06,3.01e-05,7.31e-05,7.83e-05,1.93e-06,7.25e-06,0.0032,0.000646,1.46e-06,9.55e-06,0.000388,1.48e-05,6.08e-06),"
  "(1.39e-05,1.06e-05,4.38e-05,0.000564,0.00466,0,2.15e-05,0.000941,0.000114,8.85e-06,2.13e-06,2.81e-06,1.97e-05,4.78e-05,0.00126,3.09e-05,4.74e-06,0.00209,0.000423,2.35e-05,6.25e-06,0.000254,9.65e-06,3.97e-06),"
  "(2.81e-06,2.13e-06,8.85e-06,0.000114,0.000941,2.15e-05,0,0.00466,0.000564,4.38e-05,1.06e-05,1.39e-05,3.97e-06,9.65e-06,0.000254,6.25e-06,2.35e-05,0.000423,0.00209,4.74e-06,3.09e-05,0.00126,4.78e-05,1.97e-05),"
  "(4.29e-06,3.26e-06,1.35e-05,0.000174,0.00144,3.28e-05,6.63e-06,0,0.000863,2.73e-06,1.61e-05,2.13e-05,6.08e-06,1.48e-05,0.000388,9.55e-06,1.46e-06,0.000646,0.0032,7.25e-06,1.93e-06,7.83e-05,7.31e-05,3.01e-05),"
  "(4.5e-06,3.41e-06,1.42e-05,0.000183,0.00151,3.44e-05,0.00017,0.000304,0,7.02e-05,0.000415,0.000547,6.37e-06,1.55e-05,0.000406,1e-05,3.76e-05,0.000677,0.00335,7.6e-06,4.96e-05,8.2e-05,0.00188,0.000774),"
  "(6.53e-05,4.96e-05,8.39e-06,0.000108,0.000892,2.04e-05,0.00247,0.00442,0.000535,0,1e-05,1.32e-05,9.25e-05,0.000224,0.00024,5.92e-06,0.000546,0.000401,0.00199,4.5e-06,0.00072,0.00119,4.53e-05,1.87e-05),"
  "(6.09e-05,4.63e-05,7.83e-06,0.000101,0.000832,1.9e-05,0.00231,0.00412,0.000499,0.000951,0,1.23e-05,8.63e-05,0.000209,0.000224,5.53e-06,0.00051,0.000374,0.00185,4.2e-06,0.000672,0.00111,4.23e-05,1.74e-05),"
  "(6.22e-06,4.73e-06,1.96e-05,0.000253,0.00209,4.76e-05,0.000236,0.000421,0.00125,9.72e-05,0.000574,0,8.81e-06,2.14e-05,0.000562,1.39e-05,5.21e-05,0.000937,0.00464,1.05e-05,6.86e-05,0.000114,0.0026,4.37e-05),"
  "(0.00072,0.000546,9.25e-05,0.00119,0.000401,0.000224,4.53e-05,0.00199,0.00024,1.87e-05,4.5e-06,5.92e-06,0,0.00247,0.000108,6.53e-05,1e-05,0.00442,0.000892,4.96e-05,1.32e-05,0.000535,2.04e-05,8.39e-06),"
  "(3.09e-05,2.35e-05,3.97e-06,0.00126,0.000423,9.65e-06,4.78e-05,0.00209,0.000254,1.97e-05,4.74e-06,6.25e-06,4.38e-05,0,0.000114,2.81e-06,1.06e-05,0.00466,0.000941,2.13e-06,1.39e-05,0.000564,2.15e-05,8.85e-06),"
  "(1e-05,7.6e-06,0.000774,0.000406,0.00335,0.00188,1.55e-05,0.000677,8.2e-05,6.37e-06,3.76e-05,4.96e-05,1.42e-05,3.44e-05,0,0.000547,3.41e-06,0.00151,0.000304,0.000415,4.5e-06,0.000183,0.00017,7.02e-05),"
  "(1.39e-05,1.05e-05,4.37e-05,0.000562,0.00464,0.0026,2.14e-05,0.000937,0.000114,8.81e-06,5.21e-05,6.86e-05,1.96e-05,4.76e-05,0.00125,0,4.73e-06,0.00209,0.000421,0.000574,6.22e-06,0.000253,0.000236,9.72e-05),"
  "(0.000672,0.00051,8.63e-05,0.00111,0.000374,0.000209,4.23e-05,0.00185,0.000224,1.74e-05,4.2e-06,5.53e-06,0.000951,0.00231,0.000101,6.09e-05,0,0.00412,0.000832,4.63e-05,1.23e-05,0.000499,1.9e-05,7.83e-06),"
  "(1.93e-06,1.46e-06,6.08e-06,7.83e-05,0.000646,1.48e-05,7.31e-05,0.0032,0.000388,3.01e-05,7.25e-06,9.55e-06,2.73e-06,6.63e-06,0.000174,4.29e-06,1.61e-05,0,0.00144,3.26e-06,2.13e-05,0.000863,3.28e-05,1.35e-05),"
  "(9.55e-06,7.25e-06,3.01e-05,0.000388,0.0032,7.31e-05,1.48e-05,0.000646,7.83e-05,6.08e-06,1.46e-06,1.93e-06,1.35e-05,3.28e-05,0.000863,2.13e-05,3.26e-06,0.00144,0,1.61e-05,4.29e-06,0.000174,6.63e-06,2.73e-06),"
  "(5.53e-06,4.2e-06,1.74e-05,0.000224,0.00185,4.23e-05,0.000209,0.000374,0.00111,8.63e-05,0.00051,0.000672,7.83e-06,1.9e-05,0.000499,1.23e-05,4.63e-05,0.000832,0.00412,0,6.09e-05,0.000101,0.00231,0.000951),"
  "(6.86e-05,5.21e-05,8.81e-06,0.000114,0.000937,2.14e-05,0.0026,0.00464,0.000562,4.37e-05,1.05e-05,1.39e-05,9.72e-05,0.000236,0.000253,6.22e-06,0.000574,0.000421,0.00209,4.73e-06,0,0.00125,4.76e-05,1.96e-05),"
  "(4.96e-05,3.76e-05,6.37e-06,8.2e-05,0.000677,1.55e-05,0.00188,0.00335,0.000406,0.000774,7.6e-06,1e-05,7.02e-05,0.00017,0.000183,4.5e-06,0.000415,0.000304,0.00151,3.41e-06,0.000547,0,3.44e-05,1.42e-05),"
  "(6.25e-06,4.74e-06,1.97e-05,0.000254,0.00209,4.78e-05,9.65e-06,0.000423,0.00126,3.97e-06,2.35e-05,3.09e-05,8.85e-06,2.15e-05,0.000564,1.39e-05,2.13e-06,0.000941,0.00466,1.06e-05,2.81e-06,0.000114,0,4.38e-05),"
  "(5.92e-06,4.5e-06,1.87e-05,0.00024,0.00199,4.53e-05,0.000224,0.000401,0.00119,9.25e-05,0.000546,0.00072,8.39e-06,2.04e-05,0.000535,1.32e-05,4.96e-05,0.000892,0.00442,1e-05,6.53e-05,0.000108,0.00247,0))"));
}

// Basically what the cross entropy target search does, except that it doesn't
// change the targets between runs.
void test_1_bell_wong_dynamic_tp_star() {
  size_t num_pax = 5000;
  size_t reps = 500;
  size_t num_veh = 10;
  unsigned int seed = 123;

  si_taxi::BWSim sim;
  load_star_5st_2min_del01s_trip_times(sim);

  boost::numeric::ublas::matrix<double> scaled_od_demand;
  load_star_5st_2min_del01s_demand_1(scaled_od_demand);

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

// See what the performance impact of full stats collection is, relative
// to example 1. This took 20s vs example_1's 15s, and the
// record_queue_lengths method took about 20% of the total time, which makes
// sense, because it gets called once for every time step.
void test_2_bell_wong_dynamic_tp_star() {
  size_t num_pax = 5000;
  size_t reps = 500;
  size_t num_veh = 10;
  unsigned int seed = 123;

  si_taxi::BWSim sim;
  load_star_5st_2min_del01s_trip_times(sim);

  boost::numeric::ublas::matrix<double> scaled_od_demand;
  load_star_5st_2min_del01s_demand_1(scaled_od_demand);

  sim.add_vehicles_in_turn(num_veh);

  BWNNHandler reactive(sim);
  BWDynamicTransportationProblemHandler proactive(sim);
  proactive.targets[0] = 5;
  BWSimStatsDetailed stats(sim);

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

    cout << "done" << endl;
  }
}

void test_3_bell_wong_sampling_voting_star() {
  size_t num_pax = 20000;
  size_t num_veh = 10;
  unsigned int seed = 123;

  si_taxi::BWSim sim;
  load_star_5st_2min_del01s_trip_times(sim);

  boost::numeric::ublas::matrix<double> scaled_od_demand;
  load_star_5st_2min_del01s_demand_1(scaled_od_demand);

  sim.add_vehicles_in_turn(num_veh);

  BWNNHandler reactive(sim);
  BWPoissonPaxStream sampling_pax_stream(0, scaled_od_demand);
  BWSamplingVotingHandler proactive(sim, &sampling_pax_stream);
  proactive.num_pax = 100;
  proactive.num_sequences = 50;
  BWSimStatsMeanPaxWait stats(sim);

  sim.reactive = &reactive;
  sim.proactive = &proactive;
  sim.stats = &stats;

  BWPoissonPaxStream pax_stream(0, scaled_od_demand);

  si_taxi::rng.seed(seed);
  sim.init();

  sim.handle_pax_stream(num_pax, &pax_stream);
}

void test_4_bell_wong_dynamic_tp_grid() {
  size_t num_pax = 5000;
  size_t reps = 50;
  size_t num_veh = 200;
  unsigned int seed = 123;

  si_taxi::BWSim sim;
  load_grid_24st_800m_del01s_trip_times(sim);

  boost::numeric::ublas::matrix<double> scaled_od_demand;
  load_grid_24st_800m_del01s_demand_1(scaled_od_demand);

  sim.add_vehicles_in_turn(num_veh);

  BWNNHandler reactive(sim);
  BWDynamicTransportationProblemHandler proactive(sim);
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

    for (size_t i = 0; i < sim.num_stations(); ++i) {
      proactive.targets[i] = si_taxi::rng() % 10;
    }

    sim.handle_pax_stream(num_pax, &pax_stream);

    cout << stats.mean_pax_wait << endl;
  }
}

void test_5_bell_wong_sampling_voting_grid() {
  size_t num_pax = 10000;
  size_t num_veh = 200;
  unsigned int seed = 123;

  si_taxi::BWSim sim;
  load_grid_24st_800m_del01s_trip_times(sim);

  boost::numeric::ublas::matrix<double> scaled_od_demand;
  load_grid_24st_800m_del01s_demand_1(scaled_od_demand);

  sim.add_vehicles_in_turn(num_veh);

  BWNNHandler reactive(sim);
  BWPoissonPaxStream sampling_pax_stream(0, scaled_od_demand);
  BWSamplingVotingHandler proactive(sim, &sampling_pax_stream);
  proactive.num_pax = 100;
  proactive.num_sequences = 50;
  BWSimStatsMeanPaxWait stats(sim);

  sim.reactive = &reactive;
  sim.proactive = &proactive;
  sim.stats = &stats;

  BWPoissonPaxStream pax_stream(0, scaled_od_demand);

  si_taxi::rng.seed(seed);
  sim.init();

  sim.handle_pax_stream(num_pax, &pax_stream);
}

// helper for test_6_enumerate_square_matrices
struct F_get_matrix_from_data {
  typedef boost::numeric::ublas::matrix<int> result_t;
  std::vector<result_t> &results;
  size_t n, start;
  F_get_matrix_from_data(
      std::vector<result_t> &results, size_t n, size_t start) :
    results(results), n(n), start(start) { }
  void operator()(vector<int> &data) {
    CHECK(data.size() == start + n*n);
    result_t result(n, n);
    std::copy(data.begin() + start, data.end(), result.data().begin());
    results.push_back(result);
  }
};

std::vector<boost::numeric::ublas::matrix<int> >
list_square_matrices_with_row_sums_lte(const std::vector<int> &row_sums) {
  std::vector<boost::numeric::ublas::matrix<int> > results;
  size_t start = 10; // more accurate test -- don't start at zero
  size_t n = row_sums.size();
  std::vector<int> data(start + n*n);
  F_get_matrix_from_data f(results, n, start);
  each_square_matrix_with_row_sums_lte(data, start, 0, 0, row_sums, f);
  return results;
}

void test_6_enumerate_square_matrices() {
  std::vector<boost::numeric::ublas::matrix<int> > results;
  std::vector<int> row_sums(2);
  row_sums[0] = 1;
  row_sums[1] = 1;
  results = list_square_matrices_with_row_sums_lte(row_sums);

  CHECK(results.size() == 4);
  CHECK(to_s(results[0]) == "[2,2]((0,0),(0,0))");
  CHECK(to_s(results[1]) == "[2,2]((0,0),(1,0))");
  CHECK(to_s(results[2]) == "[2,2]((0,1),(0,0))");
  CHECK(to_s(results[3]) == "[2,2]((0,1),(1,0))");

  row_sums[0] = 2;
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 6);
  CHECK(to_s(results[0]) == "[2,2]((0,0),(0,0))");
  CHECK(to_s(results[1]) == "[2,2]((0,0),(1,0))");
  CHECK(to_s(results[2]) == "[2,2]((0,1),(0,0))");
  CHECK(to_s(results[3]) == "[2,2]((0,1),(1,0))");
  CHECK(to_s(results[4]) == "[2,2]((0,2),(0,0))");
  CHECK(to_s(results[5]) == "[2,2]((0,2),(1,0))");

  row_sums[1] = 2;
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 9);
  CHECK(to_s(results[0]) == "[2,2]((0,0),(0,0))");
  CHECK(to_s(results[1]) == "[2,2]((0,0),(1,0))");
  CHECK(to_s(results[2]) == "[2,2]((0,0),(2,0))");
  CHECK(to_s(results[3]) == "[2,2]((0,1),(0,0))");
  CHECK(to_s(results[4]) == "[2,2]((0,1),(1,0))");
  CHECK(to_s(results[5]) == "[2,2]((0,1),(2,0))");
  CHECK(to_s(results[6]) == "[2,2]((0,2),(0,0))");
  CHECK(to_s(results[7]) == "[2,2]((0,2),(1,0))");
  CHECK(to_s(results[8]) == "[2,2]((0,2),(2,0))");

  row_sums.push_back(1);
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 18*6);
  CHECK(to_s(results[ 0]) == "[3,3]((0,0,0),(0,0,0),(0,0,0))");
  CHECK(to_s(results[ 1]) == "[3,3]((0,0,0),(0,0,0),(0,1,0))");
  CHECK(to_s(results[ 2]) == "[3,3]((0,0,0),(0,0,0),(1,0,0))");
  CHECK(to_s(results[ 3]) == "[3,3]((0,0,0),(0,0,1),(0,0,0))");
  CHECK(to_s(results[ 4]) == "[3,3]((0,0,0),(0,0,1),(0,1,0))");
  CHECK(to_s(results[ 5]) == "[3,3]((0,0,0),(0,0,1),(1,0,0))");
  CHECK(to_s(results[ 6]) == "[3,3]((0,0,0),(0,0,2),(0,0,0))");
  CHECK(to_s(results[ 7]) == "[3,3]((0,0,0),(0,0,2),(0,1,0))");
  CHECK(to_s(results[ 8]) == "[3,3]((0,0,0),(0,0,2),(1,0,0))");
  CHECK(to_s(results[ 9]) == "[3,3]((0,0,0),(1,0,0),(0,0,0))");
  CHECK(to_s(results[10]) == "[3,3]((0,0,0),(1,0,0),(0,1,0))");
  CHECK(to_s(results[11]) == "[3,3]((0,0,0),(1,0,0),(1,0,0))");
  CHECK(to_s(results[12]) == "[3,3]((0,0,0),(1,0,1),(0,0,0))");
  CHECK(to_s(results[13]) == "[3,3]((0,0,0),(1,0,1),(0,1,0))");
  CHECK(to_s(results[14]) == "[3,3]((0,0,0),(1,0,1),(1,0,0))");
  CHECK(to_s(results[15]) == "[3,3]((0,0,0),(2,0,0),(0,0,0))");
  CHECK(to_s(results[16]) == "[3,3]((0,0,0),(2,0,0),(0,1,0))");
  CHECK(to_s(results[17]) == "[3,3]((0,0,0),(2,0,0),(1,0,0))");

  row_sums[0] = 0;
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 18);
  CHECK(to_s(results[ 0]) == "[3,3]((0,0,0),(0,0,0),(0,0,0))");
  CHECK(to_s(results[ 1]) == "[3,3]((0,0,0),(0,0,0),(0,1,0))");
  CHECK(to_s(results[ 2]) == "[3,3]((0,0,0),(0,0,0),(1,0,0))");
  CHECK(to_s(results[ 3]) == "[3,3]((0,0,0),(0,0,1),(0,0,0))");
  CHECK(to_s(results[ 4]) == "[3,3]((0,0,0),(0,0,1),(0,1,0))");
  CHECK(to_s(results[ 5]) == "[3,3]((0,0,0),(0,0,1),(1,0,0))");
  CHECK(to_s(results[ 6]) == "[3,3]((0,0,0),(0,0,2),(0,0,0))");
  CHECK(to_s(results[ 7]) == "[3,3]((0,0,0),(0,0,2),(0,1,0))");
  CHECK(to_s(results[ 8]) == "[3,3]((0,0,0),(0,0,2),(1,0,0))");
  CHECK(to_s(results[ 9]) == "[3,3]((0,0,0),(1,0,0),(0,0,0))");
  CHECK(to_s(results[10]) == "[3,3]((0,0,0),(1,0,0),(0,1,0))");
  CHECK(to_s(results[11]) == "[3,3]((0,0,0),(1,0,0),(1,0,0))");
  CHECK(to_s(results[12]) == "[3,3]((0,0,0),(1,0,1),(0,0,0))");
  CHECK(to_s(results[13]) == "[3,3]((0,0,0),(1,0,1),(0,1,0))");
  CHECK(to_s(results[14]) == "[3,3]((0,0,0),(1,0,1),(1,0,0))");
  CHECK(to_s(results[15]) == "[3,3]((0,0,0),(2,0,0),(0,0,0))");
  CHECK(to_s(results[16]) == "[3,3]((0,0,0),(2,0,0),(0,1,0))");
  CHECK(to_s(results[17]) == "[3,3]((0,0,0),(2,0,0),(1,0,0))");

  row_sums[1] = 0;
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 3);
  CHECK(to_s(results[ 0]) == "[3,3]((0,0,0),(0,0,0),(0,0,0))");
  CHECK(to_s(results[ 1]) == "[3,3]((0,0,0),(0,0,0),(0,1,0))");
  CHECK(to_s(results[ 2]) == "[3,3]((0,0,0),(0,0,0),(1,0,0))");

  row_sums[2] = 0;
  results = list_square_matrices_with_row_sums_lte(row_sums);
  CHECK(results.size() == 1);
  CHECK(to_s(results[ 0]) == "[3,3]((0,0,0),(0,0,0),(0,0,0))");

  //for (size_t i = 0; i < results.size(); ++i) TV(results[i]);
}

void test_7_run_tabular_sarsa() {
  MDPSim sim;
  CHECK(from_s(sim.trip_time, "[2,2]((0,1),(1,0))"));
  sim.init();
  sim.add_vehicles_in_turn(1);

  TabularSarsaSolver solver(&sim);
  EpsilonGreedySarsaActor actor(solver);
  solver.actor = &actor;
  std::vector<BWPax> requests;
  requests.push_back(BWPax(0,1,1));
  solver.tick(requests);
}

int main(int argc, char **argv) {
  if (argc == 2) {
    int test = atoi(argv[1]);
    switch(test) {
    case 1: test_1_bell_wong_dynamic_tp_star();
      break;
    case 2: test_2_bell_wong_dynamic_tp_star();
      break;
    case 3: test_3_bell_wong_sampling_voting_star();
      break;
    case 4: test_4_bell_wong_dynamic_tp_grid();
      break;
    case 5: test_5_bell_wong_sampling_voting_grid();
      break;
    case 6: test_6_enumerate_square_matrices();
      break;
    case 7: test_7_run_tabular_sarsa();
      break;
    default:
      cout << "unknown test: " << argv[1] << endl;
    }
  } else {
    cout << "specify test by number (starting from 1)" << endl;
    cout << "example: ./si_taxi_test 1" << endl;
  }
  return 0;
}
