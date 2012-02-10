#include "mdp_sim.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

using namespace std;

namespace si_taxi {

MDPSim::MDPSim() : now(-1) { }

void MDPSim::add_vehicles_in_turn(size_t num_veh, size_t station) {
  if (num_veh > 0) {
    CHECK(inbound.size() > 0);
    station = station % inbound.size();
    inbound[station].push_front(0);
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
  idle = int_vector_t(num_stations());
  ones = boost::numeric::ublas::scalar_vector<int>(num_stations(), 1);
  now = 0;
}

void MDPSim::tick(const int_od_t &empty_trips,
    const std::vector<BWPax> &requests)
{
  // validate the action; can't move more idle vehicles than we have; this is
  // the only reason we have to count idle vehicles
  fill(idle.begin(), idle.end(), 0);
  count_idle_by(now, idle);
  CHECK(vector_all_at_least(idle - prod(empty_trips, ones), 0));

  // move empty vehicles according to the chosen action
  for (size_t i = 0; i < num_stations(); ++i) {
    for (size_t j = 0; j < num_stations(); ++j) {
      if (i != j) {
        move(i, j, empty_trips(i, j));
      }
    }
  }

  // see how many vehicles we can use this time step
  fill(available.begin(), available.end(), 0);
  count_idle_by(now + 1, available);

  // advance now
  // NB: this is so that vehicles that depart in the interval (now, now+1)
  // arrive at their destination at now + t_{ij} + 1 rather than now + t_{ij}
  ++now;

  // serve queued requests from previous time steps
  for (size_t i = 0; i < num_stations(); ++i) {
    while (!queue[i].empty() && available[i] > 0) {
      BWPax &pax = queue[i].front();
      move(pax.origin, pax.destin);
      --available[pax.origin];
      queue[i].pop_front();
    }
  }

  // serve incoming requests; if there are no available vehicles at the
  // request's origin, add it to the queue
  for (std::vector<BWPax>::const_iterator it = requests.begin();
      it != requests.end(); ++it)
  {
    if (available[it->origin] > 0) {
      --available[it->origin];
      move(it->origin, it->destin);
    } else {
      queue[it->origin].push_back(*it);
    }
  }

}

void MDPSim::count_idle_by(BWTime time, int_vector_t &num_vehicles) const
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
  for (std::vector<std::deque<BWTime> >::const_iterator it = inbound.begin();
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

  // must have a vehicle available to move at the origin
  deque<BWTime> & origin_inbound = inbound[origin];
  for (size_t i = 0; i < count; ++i) {
    CHECK(!origin_inbound.empty());
    CHECK(origin_inbound.front() <= now + 1);
    origin_inbound.pop_front();
  }

  // update the inbound list for the destination
  CHECK(origin < trip_time.size1());
  CHECK(destin < trip_time.size2());
  BWTime time = now + trip_time(origin, destin);
  deque<BWTime> & destin_inbound = inbound[destin];
  deque<BWTime>::iterator ub = upper_bound(destin_inbound.begin(), destin_inbound.end(), time);
  destin_inbound.insert(ub, count, time);
}

    /* select_action(state):
 *   the Q(s, a) have to be initialised somehow
 *   we'd like to initialise them to the expected one-step reward, but this
 *   means we'd have to enumerate all possible states whenever we got a Q(s,a)
 *   that wasn't yet initialised -- even the very unlikely ones; moreover, we
 *   have an infinite number of successor states. One idea would be to bias
 *   the reward according to how far a is from the fluid limit solution.
 *
 * sarsa:
 * s = sim.state
 * a = select_action(s)
 * while (t < t_end) {
 *   tick(action, generate_demand())
 *   s_p = sim.state
 *   r_p = reward(s_p)
 *   a_p = select_action(s_p)
 *   Q(s,a) = Q(s,a) + alpha[r_p + gamma*Q(s',a') - Q(s,a)]
 *   s = s_p
 *   a = a_p
 * }
 *
 * thoughts:
 *   - maybe it converges with gamma=1 if not over capacity
 *   - want to test out the two different action structures; we only have to
 *     solve the TP for the selected action
 */
}

