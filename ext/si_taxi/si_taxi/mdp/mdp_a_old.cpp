#ifndef SI_TAXI_MDP_A_H_
#define SI_TAXI_MDP_A_H_

namespace si_taxi {
#if 0
typedef byte unsigned char;

struct MDPAAction {
  /**
   * For each vehicle, its new immediate destination station.
   */
  byte *destin;
}

struct MDPAState {
  MDPAState(int num_stations, int num_veh) {
    queue  = new byte[num_stations];
    destin = new byte[num_veh];
    eta    = new byte[num_veh];
    action = NULL;
  }
  ~MDPAState() {
    delete [] *queue;
    delete [] *destin;
    delete [] *eta;
  }
  /**
   * For each station, the number of requests in the queue.
   */
  byte *queue;
  /**
   * For each vehicle, its immediate destination.
   */
  byte *destin;
  /**
   * For each vehicle, the number of time steps until it reaches its destin.
   */
  byte *eta;
  /**
   * Current value estimate for this state.
   */
  double value;
  /**
   * Current best action for this state (for policy iteration).
   */
  MDPAAction *action;
};

/**
 * States are stored in a contiguous array. This makes some operations simpler,
 * though it does require us to do some pointer arithmetic to pick out the
 * fields that we're interested in. It may have some impact on performance,
 * because it means that some states may be misaligned between pages, whereas
 * the default allocator might decide to waste some space in order to maintain
 * alignment; I haven't tested whether this is significant.
 */
struct MDPAModel {
  MDPAModel(byte max_queue, byte num_stations, byte num_veh,
      const boost::numeric::ublas::matrix<byte> &trip_time) : 
    max_queue(max_queue), num_stations(num_stations), num_veh(num_veh),
    trip_time(trip_time)
  {
    init_states();
    init_actions();
    //update_greedy_action(all states?);
  }

  ~MDPAModel() {
    delete [] states;
  }

  /**
   * Return state by state number (see also state_number).
   *
   * Use the returned pointer with state_queue, state_destin, etc.. 
   */
  byte *state_at(size_t s) const {
    ASSERT(s < num_states);
    return states + s*state_size();
  }

  /**
   * Number of requests in the queue for the given state.
   *
   * @return in [0, max_queue]
   */
  byte &state_queue(byte *state, byte i) const {
    ASSERT(state);
    ASSERT(i < num_stations);
    return *(state + i);
  }

  byte &state_destin(byte *state, byte k) const {
    ASSERT(state);
    ASSERT(k < num_veh);
    return *(state + num_stations + k);
  }

  byte &state_eta(byte *state, byte k) const {
    ASSERT(state);
    ASSERT(k < num_veh);
    return *(state + num_stations + num_veh + k);
  }

  size_t &state_action(byte *state) const {
    ASSERT(states <= state && state < states_end); // only for table of states
    state_assert_sane(state);
    return *(size_t *)(state + num_stations + 2*num_veh);
  }

  double &state_value(byte *state) const {
    ASSERT(states <= state && state < states_end); // only for table of states
    state_assert_sane(state);
    return *(double *)(state + num_stations + 2*num_veh + sizeof(size_t));
  }

  /**
   * The reward is the negative of the sum of the queue lengths.
   *
   * @return non-positive
   */
  double state_reward(byte *state) const {
    state_assert_sane(state);
    -std::accumulate(state, state + num_stations, 0);
  }

  /**
   * Index of an idle vehicle at station i (if any). The vehicle with the lowest
   * index is returned.
   *
   * @return num_veh if no such vehicle
   */
  byte state_idle_veh(byte *state, byte i) const {
    byte k;
    for (k = 0; k < num_veh; ++k) {
      if (state_eta(state, k) == 0)
        break;
    }
    return k;
  } 

  /**
   * Assertions for basic sanity checks (all components in range).
   */
  void state_assert_sane(byte *state) const {
    for (byte i = 0; i < num_stations; ++i) {
      ASSERT(state_queue(state, i) <= max_queue);
    }
    for (byte k = 0; k < num_veh; ++k) {
      ASSERT(state_destin(state, i) < num_stations);
      ASSERT(state_destin(state, i) <= max_time);
    }
  }

  /**
   * Index of given state into the state array.
   *
    //num = q0
    //num = q1 + qmax*(q0)
    //num = q2 + qmax*(q1 + qmax*(q0))
    //...
   */
  size_t state_number(byte *state) {
    ASSERT(states <= state && state < states_end);

    size_t num = 0;
    for (byte i = 0; i < num_stations; ++i) {
      num = state_queue(state, i) + max_queue * num;
    }
    for (byte i = 0; i < num_veh; ++i) {
      num = state_destin(state, i) + num_stations * num;
    }
    for (byte i = 0; i < num_veh; ++i) {
      num = state_eta(state, i) + max_time * num;
    }
    ASSERT(num < num_states);
    return num;
  }

  /**
   * Modify state to go to the "next" state in the space, according to our
   * state numbering scheme.
   *
   * Does not modify the action or value.
   *
   * @return true iff there are more states
   */
  void next_state(byte *state) {
    ASSERT(states <= state && state < states_end);

    // Advance the queue lengths.
    byte i;
    for (i = 0; i < num_stations; ++i) {
      state_queue(state, i) += 1;
      if (state_queue(state, i) <= max_queue) {
        return;
      } else {
        state_queue(state, i) = 0;
      }
    }

    // Advance the vehicle destinations.
    byte k;
    for (k = 0; k < num_veh; ++k) {
      state_destin(state, k) += 1;
      if (state_destin(state, k) <= num_stations) {
        return;
      } else {
        state_destin(state, k) = 0;
      }
    }

    // Advance the vehicle trip times.
    for (k = 0; k < num_veh; ++k) {
      state_eta(state, k) += 1;
      if (state_eta(state, k) <= max_time) {
        return;
      } else {
        state_eta(state, k) = 0;
      }
    }

    FAIL("reached the last state");
  }

  void init_states() {
    // Determine space requirements. 
    max_time   = compute_max_time();
    num_states = compute_num_states();
    state_size = compute_state_size();

    // Overflow check.
    CHECK(num_states < numeric_limits<size_t>::max()/state_size);
    CHECK(state_size < numeric_limits<size_t>::max()/num_states);

    // Allocate the state array.
    states = new byte[num_states*state_size];
    CHECK(states);
    states_end = states + num_states*state_size;

    // Start at state zero; copy state i to the space for state j, then
    // advance state j to the "next" state, according to the ordering scheme
    // defined by next_state(). Will set default actions later.
    byte *state = states;
    fill(state, state + state_size, 0);
    for (;;) {
      state_value(state) = state_reward(state);
      state_action(state) = numeric_limits<size_t>::max();

      byte *new_state = state + state_size;
      if (new_state == states_end)
        break;
      memcpy(new_state, state, state_size);
      next_state(state);
      state = new_state;
    }
  }

  void init_actions() {
    num_actions = S**V

    // Now go through and set initial greedy actions; these depend on immediate
    // rewards from the next state.
    // TODO
  }

  /**
   * @return true iff greedy action changed
   */
  bool update_greedy_action(byte *state) {
    // loop over actions
    // in this case, taking an action means that we basically copy over that
    // bit of the state
    // so, we need to keep a copy of the state's current destin vector

  }

  /**
   * Expected reward if the given action (assumed to be feasible) is taken in
   * the given state.
   *
   * This is really where the model is defined; it generates and considers all
   * possible successor states and computes the relevant probabilities.
   *
   * @return finite number
   */
  double action_value(byte *state, byte *action) {
    // need a work_queue to do the spin
    // copy the work queue to a work state
    // then we probably need a second work state, since we could be updating
    // several passengers at once
    
    // not much point in actually materialising all of the states 
    // then there's not much point in doing it all with bytes, etc.
    // but we still have the issue of variable lengths, so it's not just
    // structs.
    
    work_state_from(state);
    double v = 0;
    do {
      double pr = queue_transition_pr(state, work_state);

      // now have passengers; move vehicles toward their destinations.
      for (byte k = 0; k < num_veh; ++k) {
        byte &eta = state_eta(work_state, k);
        if (eta > 0) {
          --eta;
        }
      }
      
      // if we have a passenger and an idle vehicle at the same station, serve
      // the passenger
      for (byte i = 0; i < num_stations; ++i) {
        while (state_queue(work_state) > 0) {
          byte k = state_idle_veh(work_state, i);
          if (k < num_veh) {
            // determine passenger destination 
            for (byte j = 0; j < num_stations; ++j) {

            }
          }
        }
        // if (state_queue > 0 && have an idle vehicle at i)
        //   second stage of randomness: passenger's destination
        //   one work state is not enough
      }

      byte *s_prime = state_at(state_number(work_state));
      v += pr * (state_reward(work_state) + gamma * state_value(s_prime));
    } while (work_state_spin_queues(state));
    return v;
  }

  /**
   * Spin the queues on the work state; this is like a normal spin, but instead
   * of resetting to zero after a carry, it resets to queue length for the given
   * state).
   *
   * @return true iff there are more queue states
   */
  bool work_state_spin_queues(byte *state) {
    for (byte i = 0; i < num_stations; ++i) {
      state_queue(work_state, i) += 1;
      if (state_queue(work_state, i) <= max_queue) {
        state_assert_sane(work_state);
        return true;
      } else {
        state_queue(work_state, i) = state_queue(state, i);
      }
    }
    return false;
  }

  /**
   * Compute probability of the observed number of arrivals between state s0 and
   * state s1.
   *
   * @return in [0, 1]
   */
  double queue_transition_pr(byte *s0, byte *s1) {
    double pr = 1.0;
    for (byte i = 0; i < num_stations; ++i) {
      byte q0 = state_queue(s0, i);
      byte q1 = state_queue(s1, i);
      CHECK(q0 <= q1);
      if (q1 == max_queue) {
        pr *= (1 - poisson_cdf(i, q1 - q0));
      } else {
        pr *= poisson_pmf(i, q1 - q0);
      }
    }
    return pr;
  }

  /**
   * A single iteration of in-place policy evaluation for the current policy.
   *
   * @return non-negative; largest change in any state's value function.
   */
  double evaluate() {
    double delta = 0;
    for (byte *state = states; state < states_end; state += state_size) {
      double v = state_value(state);
      double v_new = 0;
      // PROB: most actions infeasible
      // really we want to look at only the idle vehicles
      // so: could do in place
      // for each vehicle
      //   if idle
      //     if pax waiting
      //       several possible successor states: probabilities from od
      //     else 
      //       for each possible new destination
      //
      //  must get order right:
      //  can't have it so it looks like we can move a vehicle from state s, but
      //  then someone arrives and takes it somewhere else
      //  decision: should the transitions automatically serve passengers when a
      //  vehicle is available? I think we lose nothing by doing this,
      //  inpractice (though one can show in the static problem that there are
      //  sometimes situations where, if you know that another passenger is
      //  going to arrive at some other station in the near future, and you know
      //  that passenger's destination, and the system is busy, you might decide
      //  to leave the first passenger waiting -- highly unlikely in practice)
      //  so: queue = 0 in state s means we can move a vehicle empty;
      //      if a pax then arrives, we have to increment q, so:
      //      apply the action BEFORE processing new passengers
      //  if a new passenger arrives and there is still a vehicle with r = 0, we
      //  grab that vehicle. 
      //  if a vehicle goes from r = 1 to r = 0, check q; if q > 0, vehicle is
      //  immediately redirected destination j with pr from od; if q = 0,
      //  vehicle becomes idle.
      //
      //  so: sequence is
      //      new passengers arrive (update qs)
      //      vehicles arrive (update rs; update qs, vs, rs if any served)
      //      --- time frame boundary
      //      idle vehicles begin moving (update vs, rs; qs is unchanged)
      //  minor issue: if q = qmax, no new arrivals, even though a vehicle might
      //  be coming to take a passenger away; the idea is that we want to stay
      //  away from qmax, so hopefully this won't be an issue.
      //       
      for (byte *action = actions; action < actions_end;
          action += action_size) {
        set_work_state(state);
        set_work_state_action(action);
        if (transition_feasible(state, work_state)) {
          byte *s_prime = state_at(state_number(work_state));
          v_new += transition_probability(state, work_state) *
            (state_reward(work_state) + gamma*state_value(s_prime));
        }
      }
      state_value(state) = v_new;
      delta = max(delta, fabs(v - v_new));
    }
  }

  /**
   * Change
   *
   * @return true iff the current policy changed as a result of improvement
   */
  bool improve() {
  }

  void asynch_solve() {
    // Initialisation: we don't want to actually materialise all of the states;
    // it would be better to memoise. We could use a hash table with a custom
    // hash function for this:
    //   hash(state) -> code
    //   look up
    //   if not found, copy state into the table
    //   return the state from the table
    // it would be better to have an intrusive hash -- maybe in boost?
    // to avoid rehashing, just 
  }

private:
  byte max_queue;
  byte num_stations;
  byte num_veh;
  boost::numeric::ublas::matrix<byte> trip_time;

  byte max_time;
  size_t num_states;
  size_t state_size;
  byte *states;
  byte *states_end;

  /**
   * Largest entry in the trip_time matrix.
   */
  byte compute_max_time() const {
    return 0; // TODO from matrix
  }

  /**
   * Count the number of states.
   */
  size_t compute_num_states() const {
    double count = pow(1 + max_queue,    num_stations) *
                   pow(    num_stations, num_veh) *
                   pow(1 + max_time,     num_veh);
    CHECK(0 < count && count < numeric_limits<size_t>::max());
    return (size_t)count;
  }

  /**
   * Number of bytes in one state, including our best guess at the action and
   * the the state's value estimate.
   */
  size_t compute_state_size() {
    return (num_stations + 2*num_veh)*sizeof(byte) + // actual state
      sizeof(size_t) +                               // best known action
      sizeof(double);                                // value estimate
  }

  /*
   * TODO could simplify next_state a bit, if we can make this work (or maybe
   * use a macro)
  void spin(byte *s, byte n) {
    for (byte i = 0; i < n; ++i) {
      state_queue(state, i) += 1;
      if (state_queue(state, i) <= max_queue) {
        return;
      } else {
        state_queue(state, i) = 0;
      }
    }
  }*/
};

#endif
}

#endif // guard
