#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>
#include <si_taxi/random.h>
#include "tabular_sarsa_solver.h"

namespace si_taxi {

TabularSarsaSolver::TabularSarsaSolver(MDPSim *sim) :
  sim(sim), actor(NULL), alpha(1), gamma(1),
  state_action(state_action_size()),
  next_state_action(state_action_size()),
  action(sim->num_stations(), sim->num_stations())
{
}

size_t TabularSarsaSolver::state_size() const {
  size_t n = sim->num_stations();
  return 2*n + sim->num_vehicles();
}

size_t TabularSarsaSolver::action_size() const
{
  size_t n = sim->num_stations();
  // we store the diagonal entries, but we could remove them (always zero)
  return n*n;
}

void TabularSarsaSolver::init() {
  CHECK(actor);

  fill_state_action_state(state_action);
  actor->select_action(state_action);
  fill_state_action_action(state_action);
}

void TabularSarsaSolver::tick(const std::vector<BWPax> &requests)
{
  CHECK(actor);
  CHECK(state_action.size() == state_action_size());
  CHECK(next_state_action.size() == state_action_size());
  CHECK(action.data().size() == action_size());

  sim->tick(action, requests);
  fill_state_action_state(next_state_action);

  actor->select_action(next_state_action);
  fill_state_action_action(next_state_action);

  update_q();
  std::copy(next_state_action.begin() + state_size(), next_state_action.end(),
      action.data().begin());
  std::copy(next_state_action.begin(), next_state_action.end(),
      state_action.begin());
}

void TabularSarsaSolver::handle_pax_stream(size_t num_pax,
    BWPaxStream *pax_stream)
{
  CHECK(pax_stream);
  std::vector<BWPax> no_requests;
  std::vector<BWPax> requests;
  for (; num_pax > 0; --num_pax) {
    // let the sim catch up
    if (!requests.empty())
      while (requests.front().arrive > sim->now)
        tick(no_requests);

    BWPax pax = pax_stream->next_pax();
    if (pax.arrive <= sim->now + 1) {
      requests.push_back(pax);
    } else {
      tick(requests);
      requests.clear();
      requests.push_back(pax);
    }
  }

  // handle leftover requests
  if (!requests.empty()) {
    while (requests.front().arrive > sim->now) {
      tick(no_requests);
    }
    tick(requests);
  }
}

void TabularSarsaSolver::fill_state_action_state(sa_t &sa) {
  sa_t::iterator it = sa.begin();

  // queue lengths
  for(std::vector<std::deque<BWPax> >::const_iterator it_q = sim->queue.begin();
      it_q != sim->queue.end(); ++it_q)
    *(it++) = it_q->size();

  // number of inbound vehicles
  for(std::vector<std::deque<BWTime> >::const_iterator it_i =
      sim->inbound.begin(); it_i != sim->inbound.end(); ++it_i)
    *(it++) = it_i->size();

  // time remaining for inbound vehicles; note that the sim keeps track of
  // absolute time, because it's easier, so here we have to subtract
  for(std::vector<std::deque<BWTime> >::const_iterator it_i =
      sim->inbound.begin(); it_i != sim->inbound.end(); ++it_i) {
    for (std::deque<BWTime>::const_iterator it_r = it_i->begin();
        it_r != it_i->end(); ++it_r) {
      *(it++) = std::max(0, (int)(*it_r - sim->now));
    }
  }
}

void TabularSarsaSolver::fill_state_action_action(sa_t &sa)
{
  std::copy(action.data().begin(), action.data().end(),
      sa.begin() + state_size());
}

int TabularSarsaSolver::reward(const sa_t &sa) const {
  // currently just the negative sum of the queue lengths
  return -std::accumulate(sa.begin(), sa.begin() + sim->num_stations(), 0);
}

double TabularSarsaSolver::lookup_q(const sa_t &sa) const {
  // look up Q(s,a); initialise to immediate reward
  q_t::const_iterator it = q.find(sa);
  if (it == q.end())
    return reward(sa);
  else
    return it->second;
}

void TabularSarsaSolver::update_q() {
  // look up Q(s, a) and Q(s', a')
  double q_sa = lookup_q(state_action);
  double r_s = reward(state_action);
  double q_sap = lookup_q(next_state_action);

  q[state_action] = q_sa + alpha*(r_s + gamma*q_sap - q_sa);
}

std::pair<std::vector<int>, double> TabularSarsaSolver::policy(
    const std::vector<int> &state) const
{
  CHECK(state.size() == state_size());
  std::vector<int> action(action_size());
  double q_max = -DOUBLE_MAX;

  // a linear scan, at the moment
  for (q_t::const_iterator it = q.begin(); it != q.end(); ++it) {
    bool match = true;
    for (size_t i = 0; i < state_size(); ++i) {
      if (it->first[i] != state[i]) {
        match = false;
        break;
      }
    }

    if (match && it->second > q_max) {
      q_max = it->second;
      std::copy(it->first.begin() + state_size(), it->first.end(),
          action.begin());
    }
  }

  return make_pair(action, q_max);
}

void TabularSarsaSolver::dump_q(std::ostream &os) const {
  for (q_t::const_iterator it = q.begin(); it != q.end(); ++it) {
    os << it->first << '\t' << it->second << '\n';
  }
}

/**
 * For the 'epsilon' in epsilon greedy action selection; just keeps a list of
 * all of of the state action pairs that it sees.
 */
struct F_random_qsa {
  TabularSarsaSolver &solver;
  std::vector<TabularSarsaSolver::sa_t> actions;
  F_random_qsa(TabularSarsaSolver &solver) : solver(solver) { }
  void operator()(TabularSarsaSolver::sa_t &sa) {
    actions.push_back(sa);
  }
  void select_random_action() {
    // select random action
    CHECK(actions.size() > 0); // all states have actions (no terminals)
    boost::uniform_int<> random_index(0, actions.size() - 1);
    const TabularSarsaSolver::sa_t &sa = actions.at(random_index(rng));

    // update the solver's action
    CHECK(sa.size() == solver.state_action_size());
    CHECK(solver.action.data().size() == solver.action_size());
    std::copy(sa.begin() + solver.state_size(), sa.end(),
        solver.action.data().begin());
  }
};

/**
 * The 'greedy' in epsilon greedy action selection; keeps track of the action
 * with the highest estimate Q(s, a) score.
 */
struct F_max_qsa {
  TabularSarsaSolver &solver;
  double max_qsa;

  F_max_qsa(TabularSarsaSolver &solver) : solver(solver),
      max_qsa(-std::numeric_limits<double>::max()) { }

  void operator()(TabularSarsaSolver::sa_t &sa) {
    double qsa = solver.lookup_q(sa);
    if (qsa > max_qsa) {
      CHECK(sa.size() == solver.state_action_size());
      CHECK(solver.action.data().size() == solver.action_size());
      max_qsa = qsa;
      std::copy(sa.begin() + solver.state_size(), sa.end(),
          solver.action.data().begin());
    }
  }
};

void EpsilonGreedySarsaActor::select_action(TabularSarsaSolver::sa_t &sa) {
  // evaluate all action matrices that are valid in this state; note that
  // the zero (non) action is always valid, so we start with that one
  CHECK(sa.size() == solver.state_action_size());
  std::fill(sa.begin() + solver.state_size(), sa.end(), 0);

  // count up idle vehicles
  fill(solver.sim->idle.begin(), solver.sim->idle.end(), 0);
  solver.sim->count_idle_by(solver.sim->now, solver.sim->idle);

  // now ready to select action
  if (genrand_c01o<double>(rng) < epsilon) {
    // make a list of all feasible actions and choose a random one
    F_random_qsa f(solver);
    each_square_matrix_with_row_sums_lte(sa,
        solver.state_size(), 0, 0, solver.sim->idle, f);
    f.select_random_action();
  } else {
    // enumerate all possible actions; functor sets sa's action to the best one
    F_max_qsa f(solver);
    each_square_matrix_with_row_sums_lte(sa,
        solver.state_size(), 0, 0, solver.sim->idle, f);
  }
}

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
