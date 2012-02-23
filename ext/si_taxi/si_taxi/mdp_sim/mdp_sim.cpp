#include "mdp_sim.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

using namespace std;

namespace si_taxi {

MDPSim::MDPSim() : stats(NULL), now(-1), queue_max(0) { }

void MDPSim::add_vehicles_in_turn(size_t num_veh, size_t station) {
  if (num_veh > 0) {
    CHECK(inbound.size() > 0);
    station = station % inbound.size();
    inbound[station].push_front(-1);
    add_vehicles_in_turn(num_veh - 1, station + 1);
  }
}

void MDPSim::init() {
  CHECK(trip_time.size1() == num_stations());
  CHECK(trip_time.size2() == num_stations());

  queue.clear();
  queue.resize(num_stations());
  inbound.clear();
  inbound.resize(num_stations());
  available = int_vector_t(num_stations());
  now = 0;

  if (stats)
    stats->init();
}

void MDPSim::tick(const int_od_t &empty_trips,
    const std::vector<MDPPax> &pax)
{
  if (stats)
    stats->record_time_step_stats();

  // count vehicles that are idle (or will become idle) in this time step
  fill(available.begin(), available.end(), 0);
  count_idle_by(now, available);

  // first serve as many queued requests as we can
  for (size_t i = 0; i < num_stations(); ++i) {
    while (!queue[i].empty() && available[i] > 0) {
      MDPPax &pax = queue[i].front();
      if (stats)
        stats->record_pax_to_be_served(pax);
      move(pax.origin, pax.destin);
      --available[pax.origin];
      queue[i].pop_front();
    }
  }

  if (stats)
    stats->record_reward();

  // then move idle vehicles according to action; this will fail if there are
  // not enough idle vehicles left
  for (size_t i = 0; i < num_stations(); ++i) {
    for (size_t j = 0; j < num_stations(); ++j) {
      int m_ij = empty_trips(i, j);
      if (i != j && m_ij > 0) {
        if (stats)
          stats->record_empty_trip(i, j, m_ij);
        move(i, j, m_ij);
        available[i] -= m_ij;
      }
    }
  }

  // serve incoming requests; if there are no vehicles at the request's origin,
  // add it to the queue
  for (std::vector<MDPPax>::const_iterator it = pax.begin();
      it != pax.end(); ++it)
  {
    if (available[it->origin] > 0) {
      if (stats) stats->record_pax_to_be_served(*it);
      move(it->origin, it->destin);
      --available[it->origin];
    } else {
      queue[it->origin].push_back(*it);
    }
  }

  // truncate queues if required
  if (queue_max > 0) {
    for (std::vector<std::deque<MDPPax> >::iterator it = queue.begin();
        it != queue.end(); ++it)
      while (it->size() > queue_max)
        it->pop_back();
  }

  ++now;
}

void MDPSim::count_idle_by(MDPTime time, int_vector_t &num_vehicles) const
{
  CHECK(num_vehicles.size() == num_stations());
  for (size_t i = 0; i < inbound.size(); ++i) {
    for (size_t k = 0; k < inbound[i].size(); ++k) {
      if (inbound[i][k] <= time) {
        ++(num_vehicles(i));
      } else {
        break;
      }
    }
  }
}

size_t MDPSim::num_vehicles() const
{
  size_t count = 0;
  for (std::vector<std::deque<MDPTime> >::const_iterator it = inbound.begin();
      it != inbound.end(); ++it)
  {
    count += it->size();
  }
  return count;
}

void MDPSim::move(size_t origin, size_t destin, size_t count)
{
  CHECK(origin != destin);
  CHECK(origin < inbound.size());
  CHECK(destin < inbound.size());

  // must have an idle vehicle to move at the origin
  deque<MDPTime> & origin_inbound = inbound[origin];
  for (size_t i = 0; i < count; ++i) {
    CHECK(!origin_inbound.empty());
    CHECK(origin_inbound.front() <= now);
    origin_inbound.pop_front();
  }

  // update the inbound list for the destination
  CHECK(origin < trip_time.size1());
  CHECK(destin < trip_time.size2());
  MDPTime time = now + trip_time(origin, destin);
  deque<MDPTime> & destin_inbound = inbound[destin];
  deque<MDPTime>::iterator ub = upper_bound(destin_inbound.begin(),
      destin_inbound.end(), time);
  destin_inbound.insert(ub, count, time);
}

void MDPSim::model_c_state(std::vector<int> &state) const
{
  CHECK(state.size() >= 2*num_stations() + num_vehicles());
  std::vector<int>::iterator it = state.begin();

  // queue lengths
  for(std::vector<std::deque<MDPPax> >::const_iterator it_q = queue.begin();
      it_q != queue.end(); ++it_q)
    *(it++) = it_q->size();

  // number of inbound vehicles
  for(std::vector<std::deque<MDPTime> >::const_iterator it_i =
      inbound.begin(); it_i != inbound.end(); ++it_i)
    *(it++) = it_i->size();

  // time remaining for inbound vehicles; note that the sim keeps track of
  // absolute time, because it's easier, so here we have to subtract
  for(std::vector<std::deque<MDPTime> >::const_iterator it_i =
      inbound.begin(); it_i != inbound.end(); ++it_i) {
    for (std::deque<MDPTime>::const_iterator it_r = it_i->begin();
        it_r != it_i->end(); ++it_r) {
      *(it++) = std::max(0, (int)(*it_r - now));
    }
  }
}
size_t MDPSim::run_with_model_c_policy(
    const std::vector<std::vector<int> > &policy,
    MDPPaxStream &pax_stream, size_t num_pax,
    int policy_queue_max, double policy_step_size)
{
  typedef std::vector<int> state_t;
  typedef int_od_t action_t;
  typedef boost::unordered_map<state_t, action_t, boost::hash<state_t> >
	  policy_t;

  CHECK(policy_step_size >= 1);

  // hash the policy for faster lookup
  state_t state(2*num_stations() + num_vehicles());
  action_t action(num_stations(), num_stations());
  policy_t pi;

  for (std::vector<std::vector<int> >::const_iterator it = policy.begin();
      it != policy.end(); ++it)
  {
    CHECK(it->size() == state.size() + action.data().size());
    std::copy(it->begin(), it->begin() + state.size(), state.begin());
    std::copy(it->begin() + state.size(), it->end(), action.data().begin());
    pi[state] = action;
  }

  size_t pax_generated = 0;
  std::vector<bool> truncated_queue(num_stations());
  while (pax_generated < num_pax) {
    // get current state
    model_c_state(state);

    // may have to truncate queues to be compatible with the policy
    for (size_t i = 0; i < num_stations(); ++i) {
      if (state[i] > policy_queue_max) {
        state[i] = policy_queue_max;
        truncated_queue[i] = true;
      } else {
        truncated_queue[i] = false;
      }
    }

    // may have to scale policy time steps into sim timesteps
    if (policy_step_size != 1) {
      size_t b_offset = num_stations();
      size_t r_offset = b_offset + num_stations();

      for (size_t j = 0; j < num_stations(); ++j) {
        // the r times can only range up to max_time[j] - 1; truncation is
        // required because of the ceil() used below to scale the times below
        int max_time_j = -INT_MAX;
        for (size_t i = 0; i < num_stations(); ++i) {
          if (trip_time(i,j) > max_time_j) {
            max_time_j = trip_time(i,j);
          }
        }
        max_time_j = (int)ceil(max_time_j / policy_step_size);

        for (int k = state[b_offset + j]; k > 0; --k) {
          CHECK(r_offset < state.size());
          state[r_offset] = (int)ceil(state[r_offset] / policy_step_size);
          if (state[r_offset] >= max_time_j)
            state[r_offset] = max_time_j - 1;
          ++r_offset;
        }
      }
      CHECK(r_offset == state.size());
    }

    // look up action for this state
    policy_t::const_iterator it = pi.find(state);
    CHECK(it != pi.end());
    std::copy(it->second.data().begin(), it->second.data().end(),
        action.data().begin());

    // the policy for the truncated queues may not be valid for the actual
    // queues; in particular, we can try to move more empty vehicles from a
    // station than will be available after serving the queues; to avoid
    // this, zero the action row for each station at which we truncated the
    // queues; this is crude but simple, and it avoids fairness issues
    for (size_t i = 0; i < num_stations(); ++i) {
      if (truncated_queue[i]) {
        for (size_t j = 0; j < num_stations(); ++j) {
          action(i,j) = 0;
        }
      }
    }

    // process passengers
    const std::vector<MDPPax> &pax = pax_stream.next_pax();
    tick(action, pax);

    pax_generated += pax.size();
  }

  return pax_generated;
}

void MDPSimStats::init()
{
  pax_wait.clear();
  pax_wait.resize(sim.num_stations());
  pax_wait_simple.clear();
  pax_wait_simple.resize(sim.num_stations());
  queue_len_simple.clear();
  queue_len_simple.resize(sim.num_stations());
  idle_vehs_simple.clear();
  idle_vehs_simple.resize(sim.num_stations());

  occupied_trips.resize(sim.num_stations(), sim.num_stations());
  occupied_trips.clear();
  empty_trips.resize(sim.num_stations(), sim.num_stations());
  empty_trips.clear();
  idle_vehs_simple_total.clear();
  reward.clear();
  reward.resize(sim.num_stations());
}

void MDPSimStats::record_time_step_stats()
{
  // queue lengths
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    queue_len_simple[i].increment(sim.queue[i].size());
  }

  // idle vehicle counts
  size_t idle_total = 0;
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    size_t idle_i = 0;
    for (size_t k = 0; k < sim.inbound[i].size(); ++k) {
      if (sim.inbound[i][k] < sim.now) {
        ++idle_i;
      } else {
        break;
      }
    }
    idle_vehs_simple[i].increment(idle_i);
    idle_total += idle_i;
  }
  idle_vehs_simple_total.increment(idle_total);
}

void MDPSimStats::record_reward()
{
  // queue lengths AFTER we've served as many queued requests as possible
  for (size_t i = 0; i < sim.num_stations(); ++i) {
    reward[i] -= sim.queue[i].size();
  }
}

void MDPSimStats::record_empty_trip(
    size_t origin, size_t destin, size_t count)
{
  empty_trips(origin, destin) += count;
}

void MDPSimStats::record_pax_to_be_served(const MDPPax &pax)
{
  CHECK(pax.origin < sim.num_stations());
  CHECK(pax.arrive < step * (sim.now + 1));

  ++occupied_trips(pax.origin, pax.destin);

  //
  // update simple waiting time estimate
  // TODO this tends to overestimate
  //
  double wait_simple = step * ceil(sim.now - pax.arrive / step);
  CHECK(wait_simple >= 0);
  pax_wait_simple[pax.origin].increment((size_t)wait_simple);

  //
  // update best guess at actual waiting time
  // TODO WRONG
  //
  CHECK(!sim.inbound[pax.origin].empty());
  MDPTime veh_stop_time = sim.inbound[pax.origin].front();
  bool veh_idle = veh_stop_time < sim.now;
  if (veh_idle) {
    // should not have idle vehicles and queued requests left over
    ASSERT(pax.arrive >= sim.now);
    pax_wait[pax.origin].increment(0);
  } else {
    bool request_from_queue = pax.arrive < sim.now;
    if (request_from_queue) {
      double wait = step*(sim.now + 0.5) - pax.arrive;
      CHECK(wait >= 0);
      pax_wait[pax.origin].increment((size_t)wait);
    } else {
      double wait = (step*(sim.now + 1.0) - pax.arrive) / 2.0;
      CHECK(wait >= 0);
      pax_wait[pax.origin].increment((size_t)wait);
    }
  }
}

MDPPoissonPaxStream::MDPPoissonPaxStream(double now, double step,
    const boost::numeric::ublas::matrix<double> &od) :
    now(now), step(step), last_time(now), _od(od), _pax_i(0)
{
  _pax[0] = std::vector<MDPPax>();
  _pax[1] = std::vector<MDPPax>();
}

void MDPPoissonPaxStream::generate(MDPPax &pax)
{
  double interval;
  _od.sample(BYREF pax.origin, BYREF pax.destin, BYREF interval);
  last_time += interval;
  pax.arrive = last_time;
}

const std::vector<MDPPax> &MDPPoissonPaxStream::next_pax()
{
  MDPPax pax;
  std::vector<MDPPax> &current_pax = _pax[_pax_i];
  std::vector<MDPPax> &pending_pax = _pax[(_pax_i + 1) % 2];

  // clear the one we returned last time
  current_pax.clear();

  // except when initialising, we should always have one pending pax
  if (pending_pax.empty()) {
    generate(pax);
    pending_pax.push_back(pax);
  }

  now += step;
  if (pending_pax.front().arrive >= now) {
    // sim needs to catch up; no new pax this time step
    return current_pax;
  } else {
    // the pending pax arrives this time step; there may be more
    for (;;) {
      generate(pax);
      if (pax.arrive >= now) {
        // current_pax will be the new pending_pax
        current_pax.push_back(pax);
        break;
      } else {
        pending_pax.push_back(pax);
      }
    }
    _pax_i = (_pax_i + 1) % 2;
    return pending_pax;
  }
}

void MDPPoissonPaxStream::reset(double now)
{
  this->now = now;
  this->last_time = now;
  _pax[0].clear();
  _pax[1].clear();
}

}
