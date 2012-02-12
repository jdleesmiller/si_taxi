#include "mdp_sim.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

using namespace std;

namespace si_taxi {

MDPSim::MDPSim() : now(-1), queue_max(0) { }

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
  // check that the requests are in the right time interval; this checks
  // that the arrivals are in [t, t+1], because we might have one at t=0.
  for (std::vector<BWPax>::const_iterator it = requests.begin();
      it != requests.end(); ++it) {
    CHECK(now <= it->arrive && it->arrive <= now + 1);
  }

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

  // truncate queues if required
  if (queue_max > 0) {
    for (std::vector<std::deque<BWPax> >::iterator it = queue.begin();
        it != queue.end(); ++it)
      while (it->size() > queue_max)
        it->pop_back();
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
  deque<BWTime>::iterator ub = upper_bound(destin_inbound.begin(),
      destin_inbound.end(), time);
  destin_inbound.insert(ub, count, time);
}

}
