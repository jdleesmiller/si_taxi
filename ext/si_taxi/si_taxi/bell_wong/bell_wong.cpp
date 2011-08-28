#include "bell_wong.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

using namespace std;

namespace si_taxi {

void BWSim::init() {
  ASSERT(this->reactive);
  ASSERT(this->proactive);
  ASSERT(this->stats);

  now = 0;
  this->reactive->init();
  this->proactive->init();
  this->stats->init();
}

void BWSim::add_vehicles_in_turn(size_t num_veh, size_t station) {
  if (num_veh > 0) {
    station = station % num_stations();
    vehs.push_back(BWVehicle(station, now));
    add_vehicles_in_turn(num_veh - 1, station + 1);
  }
}

void BWSim::park_vehicles_in_turn(size_t station) {
  CHECK(station < num_stations());
  for (size_t k = 0; k < vehs.size(); ++k) {
    vehs[k].destin = station;
    vehs[k].arrive = now;
    station = (station + 1) % num_stations();
  }
}

void BWSim::run_to(BWTime t) {
  ASSERT(this->reactive);
  ASSERT(this->proactive);
  ASSERT(this->stats);
  ASSERT(t >= now);

  for (; now < t; ++now) {
    // record queue lengths and vehicle states
    stats->record_time_step_stats();

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

  stats->record_empty_trip(veh.destin, destin);

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
  stats->record_pax_served(pax, veh.destin, pickup);

  veh.arrive = pickup + trip_time(pax.origin, pax.destin);
  veh.origin = pax.origin;
  veh.destin = pax.destin;
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

void BWSim::count_idle_vehs(std::vector<int> &idle_vehs) const {
  CHECK(idle_vehs.size() == num_stations());
  for (size_t k = 0; k < vehs.size(); ++k) {
    if (vehs[k].arrive <= now) {
      ++(idle_vehs[vehs[k].destin]);
    }
  }
}

void BWSimStatsDetailed::init() {
  pax_wait.clear();
  pax_wait.resize(sim.num_stations());
  queue_len.clear();
  queue_len.resize(sim.num_stations());
  idle_vehs.clear();
  idle_vehs.resize(sim.num_stations());
  pickups.clear();
  pickups.resize(sim.num_stations());

  occupied_trips.resize(sim.num_stations(), sim.num_stations());
  occupied_trips.clear();
  empty_trips.resize(sim.num_stations(), sim.num_stations());
  empty_trips.clear();
  idle_vehs_total.clear();
}

size_t BWSimStatsDetailed::queue_at(size_t i) {
  // remove passengers that have already been served
  while (!pickups[i].empty() && pickups[i].top() <= sim.now)
    pickups[i].pop();
  return pickups[i].size();
}

void BWSimStatsDetailed::record_time_step_stats() {
  //
  // record passenger queue length at each station
  //
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    // record remaining queue; length is the number of future serve_times
    queue_len[i].increment(queue_at(i));
  }

  //
  // record number of idle vehicles at each station and overall
  //
  idle_vehs_counter.clear();
  idle_vehs_counter.resize(sim.num_stations(), 0);
  sim.count_idle_vehs(idle_vehs_counter);
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    idle_vehs[i].increment(idle_vehs_counter[i]);
  }
  idle_vehs_total.increment(std::accumulate(
      idle_vehs_counter.begin(), idle_vehs_counter.end(), 0));
}

void BWSimStatsDetailed::record_pax_served(const BWPax &pax,
    size_t empty_origin, BWTime pickup)
{
  CHECK(pickup >= pax.arrive);
  ASSERT(empty_origin < sim.num_stations());

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

void BWSimStatsDetailed::record_empty_trip(size_t empty_origin,
    size_t empty_destin)
{
  ++empty_trips(empty_origin, empty_destin);
}

void BWSimStatsMeanPaxWait::init() {
  this->mean_pax_wait = 0.0;
  this->pax_count = 0;
}

void BWSimStatsMeanPaxWait::record_pax_served(const BWPax &pax,
    size_t empty_origin, BWTime pickup)
{
  double wait = (double)(pickup - pax.arrive);
  CHECK(wait >= 0);
  this->mean_pax_wait = cumulative_moving_average(wait,
      this->mean_pax_wait,
      this->pax_count);
}

void BWSimStatsPaxRecorder::init() {
  this->records.clear();
}

void BWSimStatsPaxRecorder::record_pax_served(const BWPax &pax,
    size_t empty_origin, BWTime pickup)
{
  BWSimStatsPaxRecord record;
  record.origin = pax.origin;
  record.destin = pax.destin;
  record.arrive = pax.arrive;
  record.empty_origin = empty_origin;
  record.pickup = pickup;
  this->records.push_back(record);
}

BWTime BWNNHandler::wait(const BWPax &pax, const BWVehicle &veh) const
{
  return max((BWTime)0, veh.arrive - pax.arrive) +
      sim.trip_time(veh.destin, pax.origin);
}

size_t BWNNHandler::handle_pax(const BWPax &pax) {
  ASSERT(pax.origin < sim.num_stations());
  ASSERT(pax.destin < sim.num_stations());
  ASSERT(pax.arrive == sim.now);
  size_t k_star = numeric_limits<size_t>::max();
  BWTime w_star = numeric_limits<BWTime>::max();
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    BWTime w_k = wait(pax, sim.vehs[k]);
    if (w_k < w_star) {
      k_star = k;
      w_star = w_k;
    }
  }
  ASSERT(k_star != numeric_limits<size_t>::max());
  return k_star;
}

size_t BWHxHandler::handle_pax(const BWPax &pax) {
  ASSERT(pax.origin < sim.num_stations());
  ASSERT(pax.destin < sim.num_stations());
  ASSERT(pax.arrive == sim.now);
  size_t k_star = SIZE_T_MAX;
  double v_star = numeric_limits<double>::infinity();
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    double v_k = this->value(pax, k);
    if (v_k < v_star) {
      k_star = k;
      v_star = v_k;
    }
  }
  ASSERT(k_star != SIZE_T_MAX);
  return k_star;
}

BWH1Handler::BWH1Handler(BWSim &sim, boost::numeric::ublas::matrix<double> od,
    double alpha) : BWHxHandler(sim, od, alpha) {
  using namespace boost::numeric;
  using namespace boost::numeric::ublas;

  //
  // When the demand is stationary (as we assume it is), we can precompute
  // the expected length of the next (occupied) trip from each station.
  //
  // Let e = vector of ones.
  // Let C denote the trip times matrix, for brevity.
  // Let C_h denote the h'th row of C, and P^j denote the j'th column of P.
  // Then we want CPe:
  // {CP}_{hj} = C_h * P^j = \sum_i C_hi P_ij
  // {CPe}_h   = \sum_j {CP}_{hj}
  //           = \sum_j \sum_i C_hi P_ij
  //           = \sum_{i,j} p_ij*c(h,i)
  //
  scalar_vector<double> e(this->od().num_stations(), 1);
  ublas::vector<double> Pe(prod(this->od().trip_prob_matrix(), e));
  _expected_trip_time_from = prod(sim.trip_time, Pe);
}

double BWH1Handler::expected_trip_time_from(size_t i) const
{
  ASSERT(i < _expected_trip_time_from.size());
  return _expected_trip_time_from[i];
}

double BWH1Handler::value(const BWPax & pax, size_t k) const
{
  // When the demand is stationary, p_{ij}(t) = p_{ij}. Then
  //   \sum_{ij} p_{ij} * w(t + h, a(k), d(k), i)
  // = \sum_{ij} p_{ij} * [max(0, a(k) - (t + h)) + c(d(k), i)]
  // = max(0, a(k) - (t + h)) + \sum_{ij} p_{ij}*c(d(k),i)
  // because the p_{ij} sum to 1.
  const BWVehicle &veh = sim.vehs[k];
  double t = pax.arrive;
  double h = od().expected_interarrival_time();
  double x = expected_trip_time_from(veh.destin);
  return wait(pax, veh) - alpha() * (max(0.0, veh.arrive - t - h) + x);
}

double BWH2Handler::value(const BWPax & pax, size_t k) const
{
  const BWVehicle &veh = sim.vehs[k];
  double t = pax.arrive;
  double h = od().expected_interarrival_time();
  double exp_wait_max = -numeric_limits<double>::infinity();
  for (size_t n = 0; n < horizon; ++n) {
    double exp_wait_n = 0;

    // a minor simplification is possible inside the 'max_n':
    //   \sum_i \sum_j p_ij * min_{k'} w(t + nh, k', i)
    // = \sum_i ( min_{k'} w(t + nh, k', i) ) \sum_j p_ij
    // since w(.) depends on i but not j. This means we only have to compute
    // the inner minimization once for each i, rather than for each i and j.

    for (size_t i = 0; i < sim.num_stations(); ++i) {
      // note: if there is only one vehicle, then the loop body never executes,
      // so it is important that we set wait_kp_min to a finite number;
      // otherwise, we will return an infinity, which will break the
      // BWHxHandler::handle_pax function.
      double wait_kp_min = numeric_limits<double>::max();
      for (size_t kp = 0; kp < sim.vehs.size(); ++kp) {
        if (kp == k) continue;
        const BWVehicle &veh_kp = sim.vehs[kp];
        double wait_kp = max(0.0, veh_kp.arrive - (t + n*h)) +
            sim.trip_time(veh_kp.destin, i);
        wait_kp_min = min(wait_kp_min, wait_kp);
      }

      // the \sum_j p_ij factor is the total rate out of station i divided
      // by the total demand, which is 1/h.
      exp_wait_n += od().rate_from(i) * h * wait_kp_min;
    }
    exp_wait_max = max(exp_wait_max, exp_wait_n);
  }

  return wait(pax, veh) + alpha() * exp_wait_max;
}

size_t BWETNNHandler::handle_pax(const BWPax &pax) {
  ASSERT(pax.origin < sim.num_stations());
  ASSERT(pax.destin < sim.num_stations());
  ASSERT(pax.arrive == sim.now);

  size_t ks            = numeric_limits<size_t>::max();
  int    ks_empty      = numeric_limits<int>::max();
  BWTime ks_extra_wait = numeric_limits<BWTime>::max();
  for (size_t k = 0; k < sim.vehs.size(); ++k) {
    int    k_empty      = sim.trip_time(sim.vehs[k].destin, pax.origin);
    BWTime k_extra_wait = max((BWTime)0, sim.vehs[k].arrive - sim.now);

    if (k_empty < ks_empty || (
        k_empty == ks_empty && k_extra_wait < ks_extra_wait))
    {
      ks = k;
      ks_empty = k_empty;
      ks_extra_wait = k_extra_wait;
    }
  }
  ASSERT(ks != numeric_limits<size_t>::max());
  return ks;
}

size_t BWSNNHandler::choose_veh(const BWPax &pax, const vector<BWVehicle> &vehs,
    const boost::numeric::ublas::matrix<int> &trip_time) {
  int ks_empty = trip_time(vehs[0].destin, pax.origin);
  BWTime ks_arrive = vehs[0].arrive + ks_empty;
  BWTime ks_wait = max((BWTime)0, ks_arrive - pax.arrive);
  size_t ks = 0;

  size_t num_veh = vehs.size();
  for (size_t k = 1; k < num_veh; ++k) {
    int k_empty = trip_time(vehs[k].destin, pax.origin);
    BWTime k_arrive = vehs[k].arrive + k_empty;
    BWTime k_wait = max((BWTime)0, k_arrive - pax.arrive);

    // note that because we process the vehicles in ascending order by index,
    // the final tie breaker on vehicle index is implicit; that is, it always
    // holds that k > ks, so even if k_arrive == ks_arrive, we would never
    // switch from ks to k.
    bool new_ks = k_wait < ks_wait || (
        k_wait   == ks_wait   && (k_empty  < ks_empty || (
        k_empty  == ks_empty  && (k_arrive > ks_arrive))));
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
  sim.stats->record_pax_served(pax, empty_origin, pickup);

  return numeric_limits<size_t>::max(); // sim state already updated
}

BWPoissonPaxStream::BWPoissonPaxStream(double now,
    boost::numeric::ublas::matrix<double> od) : last_time(now), _od(od) {
}

BWPax BWPoissonPaxStream::next_pax() {
  BWPax pax;
  double interval;
  _od.sample(BYREF pax.origin, BYREF pax.destin, BYREF interval);
  last_time += interval;
  pax.arrive = (BWTime)round(last_time);
  return pax;
}

BWTestPaxStream::BWTestPaxStream() : offset(0) { }

BWPax BWTestPaxStream::next_pax() {
  CHECK(pax.size() > 0);
  BWPax pax_i = pax.front();
  pax_i.arrive += offset;
  pax.pop();
  return pax_i;
}

void BWTestPaxStream::reset(double now) {
  offset = (int)round(now);
}

}
