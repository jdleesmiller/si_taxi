#ifndef SI_TAXI_MDP_A_H_
#define SI_TAXI_MDP_A_H_

namespace si_taxi {

struct MDPModelA {
  MDPModelA(const boost::numeric::ublas::matrix<int> &trip_time,
      size_t num_veh, int max_queue);

  size_t num_stations() const {
    return _num_stations;
  }

  size_t num_veh() const {
    return _num_veh;
  }

  int max_queue() const {
    return _max_queue;
  }

  size_t num_stations() const {
    return _num_stations;
  }

  /**
   * Number of requests in the queue for the given state.
   *
   * @return in [0, max_queue]
   */
  int &state_queue(int *state, size_t i);

  int &state_destin(int *state, size_t k);
  int &state_eta(int *state, size_t k);

  /**
   * The reward is the negative of the sum of the queue lengths.
   *
   * @return non-positive
   */
  double state_reward(int *state) const;

  /**
   * Index of an idle vehicle at station i (if any). The vehicle with the lowest
   * index is returned.
   *
   * @return num_veh if no such vehicle
   */
  size_t state_idle_veh(int *state, size_t i) const;

  /**
   * Assertions for basic sanity checks (all components in range).
   */
  void state_assert_sane(int *state) const;

  /**
   * Compute the number of the given state.
   *
   * This is the state's index in the value and action arrays.
   */
  size_t state_number(int *state) const;

  /**
   * Create state by state number.
   */
  void load_state(size_t s, int *state);

  double &value(size_t s);
  size_t &action(size_t s);

  /**
   * Run one iteration of policy evaluation with the current policy (defined by
   * action(.)).
   */
  double evaluate_policy();

  /**
   * Run one iteration of policy improvement.
   */
  bool improve_policy();

  /**
   * Return the new value estimate for the given state.
   *
   * This function is used in both policy evaluation and policy improvement. The
   * caller updates the given state to reflect the chosen action. This function
   * implements all of the single-step dynamics for the model.
   *
   * @param state modified in place
   */
  double backup(int *state);

private:

  /**
   * 
   */
  bool sweep_state();

  /**
   *
   */
  bool sweep_queue();

  /**
   * Sweep through feasible actions for given state.
   *
   * Idea: a spin of all vehicles with eta = 0; leave destins for eta > 0;
   * always have at least one action. Not sure about this interface; maybe need
   * to call 'init_sweep_action(state)' first, which gets us our first one, and
   * then do { } while.
   */
  bool sweep_action(int *state);

  boost::numeric::ublas::matrix<int> _trip_time;
  size_t _num_veh;
  int _max_queue;

  size_t _num_states;
  size_t _num_stations;
  int _max_time;

  double values[];
  size_t actions[];

  // buffers
  int curr_state[];
  int next_state[];
  int queue[];
};

}

#endif // guard

