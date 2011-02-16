#ifndef SI_TAXI_MDP_A_H_
#define SI_TAXI_MDP_A_H_

namespace si_taxi {

struct MDPModelAStateCursor;

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

  int &state_queue(int *state, size_t i);
  int &state_destin(int *state, size_t k);
  int &state_eta(int *state, size_t k);

  /**
   * Compute the number of the given state.
   *
   * This is the state's index in the value and action arrays.
   */
  size_t state_number(int *state) const;

  double &value(size_t s);
  size_t &action(size_t s);

  /**
   * Create state by state number.
   */
  void load_state(size_t s, int *state);

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

  MDPModelAStateCursor states;

  size_t _num_states;
  size_t _num_stations;
  int _max_time;

  double values[];
  size_t actions[];

  // buffers
  int state[];
  int next_state[];
  int queue[];
};

struct MDPModelAStateCursor; {
  MDPModelAStateCursor(MDPModelA &model);
  ~MDPModelAStateCursor();

  int *state;
private:
  MDPModelA &model; 
};

MDPModelA::MDPModelA(const boost::numeric::ublas::matrix<int> &trip_time,
    size_t num_veh, int max_queue) : 
  _trip_time(trip_time), _num_veh(num_veh), _max_queue(max_queue),
  states(*this)
{
  CHECK(trip_time.size1() == trip_time.size2());
  _num_stations = trip_time.size1();

  _num_states = compute_num_states();
}

double MDPModelA::evaluate_policy() {
  double delta = 0;
  CHECK(state_number(state) == 0);
  do {
    size_t s = state_number(state);
    double v_old = value(s);
    value(s) = backup(state);
    delta = max(delta, fabs(v_old - value(s)));
  } while (sweep_state());
  return delta;
}

bool MDPModelA::improve_policy() {
  bool stable = true;
  CHECK(state_number(state) == 0);
  CHECK(action_number(action) == 0);
  do {
    init_sweep_action(state);
    size_t a_max = numeric_limits<size_t>::max();
    double v_max = -numeric_limits<double>::max();
    do {
      work_state_copy(state);
      apply(action, work_state);
      double v = backup(work_state);
      if (v > v_max) {
        a_max = action_number(action);
        v_max = v;
      }
    } while (sweep_action(state));
    ASSERT(a_max != numeric_limits<size_t>::max());

    size_t s = state_number(state);
    if (action(s) != a_max) {
      stable = false;
    }
    action(s) = a_max;

  } while (sweep_state());
  return stable;
}

MDPModelAStateCursor::MDPModelAStateCursor(MDPModelA &model) : model(model) {
  state = new int[model.state_size()];
  fill(state, state + model.state_size(), 0);
}

MDPModelAStateCursor::~MDPModelAStateCursor() {
  delete state;
}

}

#endif // guard
