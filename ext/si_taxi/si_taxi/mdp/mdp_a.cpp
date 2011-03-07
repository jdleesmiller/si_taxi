
// helper for sweep_state
#define SPIN_ARRAY(state, var, m, n) do { \
  for (size_t i = 0; i < (m); ++i) {      \
    var(state, i) += 1;                   \
    if (var(state, i) <= (n)) {           \
      return true;                        \
    } else {                              \
      var(state, i) = 0;                  \
    }                                     \
  }                                       \
} while(false)

#if 0
MDPModelA::MDPModelA(const boost::numeric::ublas::matrix<int> &trip_time,
    size_t num_veh, int max_queue) : 
  _trip_time(trip_time), _num_veh(num_veh), _max_queue(max_queue),
  states(*this)
{
  CHECK(trip_time.size1() == trip_time.size2());
  _num_stations = trip_time.size1();

  _num_states = compute_num_states();
}

int &MDPModelA::state_queue(int *state, size_t i) const {
  ASSERT(state);
  ASSERT(i < num_stations());
  return *(state + i);
}

int &MDPModelA::state_destin(int *state, size_t k) const {
  ASSERT(state);
  ASSERT(k < num_veh);
  return *(state + num_stations() + k);
}

int &MDPModelA::state_eta(int *state, size_t k) const {
  ASSERT(state);
  ASSERT(k < num_veh());
  return *(state + num_stations() + num_veh() + k);
}

double MDPModelA::state_reward(int *state) const {
  state_assert_sane(state);
  return -std::accumulate(state, state + num_stations, 0);
}

size_t MDPModelA::state_idle_veh(int *state, size_t i) const {
  size_t k;
  for (k = 0; k < num_veh(); ++k) {
    if (state_eta(state, k) == 0)
      break;
  }
  return k;
} 

void MDPModelA::state_assert_sane(int *state) const {
  for (size_t i = 0; i < num_stations(); ++i) {
    ASSERT(state_queue(state, i) <= max_queue());
  }
  for (size_t k = 0; k < num_veh(); ++k) {
    ASSERT(state_destin(state, i) < num_stations());
    ASSERT(state_destin(state, i) <= max_time());
  }
}

size_t MDPModelA::state_number(int *state) const {
  size_t num = 0;
  for (size_t i = 0; i < num_stations(); ++i)
    num = state_queue(state, i) + max_queue() * num;
  for (size_t i = 0; i < num_veh(); ++i)
    num = state_destin(state, i) + num_stations() * num;
  for (size_t i = 0; i < num_veh(); ++i)
    num = state_eta(state, i) + max_time() * num;
  ASSERT(num < num_states);
  return num;
}

bool MDPModelA::sweep_state() {
  SPIN_ARRAY(curr_state, state_queue,  num_stations(), max_queue());
  SPIN_ARRAY(curr_state, state_destin, num_veh(),      num_stations() - 1);
  SPIN_ARRAY(curr_state, state_eta,    num_veh(),      max_time());
  return false;
}

bool MDPModelA::sweep_action(int *state) {
  
  return false;
}

double MDPModelA::evaluate_policy() {
  double delta = 0;
  CHECK(state_number(curr_state) == 0);
  do {
    size_t s = state_number(curr_state);
    double v_old = value(s);
    value(s) = backup(curr_state); // TODO have to make a copy first
    delta = max(delta, fabs(v_old - value(s)));
  } while (sweep_state());
  return delta;
}

bool MDPModelA::improve_policy() {
  bool stable = true;
  CHECK(state_number(curr_state) == 0);
  CHECK(action_number(action) == 0);
  do {
    size_t a_max = numeric_limits<size_t>::max();
    double v_max = -numeric_limits<double>::max();
    init_sweep_action(curr_state);
    do {
      work_state_copy(curr_state);
      apply(action, work_state);
      double v = backup(work_state);
      if (v > v_max) {
        a_max = action_number(action);
        v_max = v;
      }
    } while (sweep_action(curr_state));
    ASSERT(a_max != numeric_limits<size_t>::max());

    size_t s = state_number(curr_state);
    if (action(s) != a_max) {
      stable = false;
    }
    action(s) = a_max;
  } while (sweep_state());

  return stable;
}

double MDPModelA::backup(int *state) {
  // the deterministic part: move vehicles closer to their destinations
  for (size_t k = 0; k < num_veh(); ++k) {
    if (state_eta(state) > 0) {
      --state_eta(state);
    }
  }

  // now we know how many idle vehicles we have at each station
  // and the current queue lengths
  // queue length is limited to [0, qmax], so we have to think about up to
  //   qmax - q + idle_vehs
  // arrivals in this time step; if q = qmax, it's certain that we'll decrease
  // by idle_vehs, but they we may have to add a few back due to new arrivals
  // but we're not done:
  // for each passenger service, we have to consider each possible destination

  // need another sweep

  // for station i
  //   if there is an idle vehicle at station i
  // sweep successor states? for each Poisson increment to each state
}

#endif
