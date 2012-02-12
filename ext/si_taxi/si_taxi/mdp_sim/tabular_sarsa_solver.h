#ifndef SI_TAXI_TABULAR_SARSA_H_
#define SI_TAXI_TABULAR_SARSA_H_

#include <unordered_map>
#include <boost/functional/hash.hpp>

#include "mdp_sim.h"

namespace si_taxi {

// forward declaration
struct SarsaActor;

/**
 * Currently one big table, but maybe we'd save code and have better locality
 * if we had a nested hash table -- state -> (action -> value). Really should
 * do this -- also makes it easier to get the policy out at the end. It might
 * have a lot of wasted memory, however; we could just use a vector of pairs
 * for the actions beneath each state.
 */
struct TabularSarsaSolver {
  /**
   * The sim to learn from. Not null.
   * Should probably be a reference, not a pointer.
   */
  MDPSim *sim;

  /**
   * The action selection method. Maybe not the best name: it's not an actor
   * in the actor-critic sense. Not null when init is called and thereafter.
   */
  SarsaActor *actor;

  /**
   * Learning rate for update_q.
   */
  double alpha;

  /**
   * Discount factor.
   */
  double gamma;

  typedef std::vector<int> sa_t;

  /**
   * The first 'SA' in 'SARSA'. Using matrix action but ignoring diagonal. This
   * projects the current state of the sim into the 'model B' state space,
   * namely (q_1,...,q_S,b_1,...,b_S,r_1,...,r_K).
   */
  sa_t state_action;

  /**
   * The second 'SA' in 'SARSA'; same conventions as state_actions.
   */
  sa_t next_state_action;

  /**
   * The action to take on the next tick.
   */
  int_od_t action;

  typedef std::unordered_map<sa_t, double, boost::hash<sa_t> > q_t;

  /**
   * Map from (state, action) pairs to state-action values.
   */
  q_t q;

  /**
   * Constructor.
   */
  TabularSarsaSolver(MDPSim *sim);

  /**
   * Number of elements in a station_action that encode the state, computed
   * from the sim.
   */
  size_t state_size() const;

  /**
   * Number of elements in a station_action that encode the action, computed
   * from the sim.
   */
  size_t action_size() const;

  /**
   * Number of elements in a station_action, computed from the sim.
   */
  inline size_t state_action_size() const {
    return state_size() + action_size();
  }

  /**
   * Call before first tick.
   */
  void init();

  /**
   * Handle the given requests in the current tick.
   *
   * @param requests the arrive times are not used, but they must be in (now,
   * now + 1]
   */
  void tick(const std::vector<BWPax> &requests);

  /**
   * Generate requests from the given stream, chunk them into time steps, and
   * for each timestep call tick.
   */
  void handle_pax_stream(size_t num_pax, BWPaxStream *pax_stream);

  /**
   * Set the state part of the given state_action vector based on current
   * sim state.
   */
  void fill_state_action_state(sa_t &sa);

  /**
   * Set the action part of the given state_action vector based on the current
   * action matrix.
   */
  void fill_state_action_action(sa_t &sa);

  /**
   * Set action based on the current state of the sim.
   */
  void select_action(sa_t &sa);

  /**
   * Reward for the given (state, action) pair; currently we only look at
   * the state.
   */
  int reward(const sa_t &sa) const;

  /**
   * Look up Q(s,a); if there is no stored value for Q(s,a), this returns a
   * default value, namely the immediate reward R(s,a).
   */
  double lookup_q(const sa_t &sa) const;

  /**
   * Update q based on state_action and next_state_action
   */
  void update_q();

  /**
   * The number of (state, action) pairs stored in q.
   * (This only exists because I can't get SWIG to wrap q properly.)
   */
  inline size_t q_size() const {
    return q.size();
  }

  /**
   * Look up the optimal action to take in the given state. Also returns the
   * corresponding Q(s, a) value, or -DBL_MAX if there are no actions known for
   * the given state.
   */
  std::pair<std::vector<int>, double> policy(
      const std::vector<int> &state) const;

  /**
   * Print the contents of the Q(s,a) table to the given stream.
   */
  void dump_q(std::ostream &os = std::cout) const;
};

struct SarsaActor {
  struct TabularSarsaSolver &solver;

  explicit inline SarsaActor(TabularSarsaSolver &solver) : solver(solver) {   }

  virtual ~SarsaActor() { }

  virtual void select_action(TabularSarsaSolver::sa_t &sa) = 0;
};

struct EpsilonGreedySarsaActor : public SarsaActor {
  /**
   * For epsilon-greedy action selection with a given epsilon; in [0, 1].
   */
  double epsilon;

  explicit inline EpsilonGreedySarsaActor(TabularSarsaSolver &solver) :
      SarsaActor(solver), epsilon(0) {   }

  virtual void select_action(TabularSarsaSolver::sa_t &sa);
};

}

#endif /* guard */
