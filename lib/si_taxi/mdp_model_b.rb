module SiTaxi
  #
  # State for {MDPModelB}.
  #
  class MDPStateB < MDPStateBase
    def initialize model
      super(model)
      @queue   = [0]*model.num_stations
      @inbound = []
    end

    attr_accessor :queue, :inbound

    #
    # Create state from array representation (see to_a).
    #
    # @param [MDPModelB] model
    # @param [Array] a from {MDPStateB#to_a}
    #
    def self.from_a model, a
      state = self.new(model)

      # the queues are just the same
      ns, nv = model.num_stations, model.num_veh
      state.queue   = a[0,    ns]
      
      # build the inbound lists; their sizes are stored in a[ns,...,2*ns-1], and
      # their entries are stored in the rest of a.
      k = 2*ns
      a[ns, ns].each_with_index do |num_inbound, i|
        state.inbound[i] = a[k,num_inbound]
        k += num_inbound
      end
      raise unless k == a.size

      state
    end

    #
    # Create an equivalent model B state from an {MDPModelA} state; this
    # unlabels the vehicles.
    #
    def self.from_model_a_state model, a_state
      b_state = self.new(model)
      ns, nv = model.num_stations, model.num_veh

      # group vehicles by destination and sort their ETAs to eliminate the
      # dependence on vehicle index order
      inbound = (0...ns).map {|j| 
        (0...nv).select {|k| a_state.destin[k] == j}.
          map{|k| a_state.eta[k]}.sort}

      b_state.queue   = a_state.queue.dup
      b_state.inbound = inbound
      b_state
    end

    #
    # Number of vehicles inboudn to each station.
    #
    # @return [Array<Integer>] not nil; length num_stations; entries
    #         non-negative
    #
    def num_inbound
      inbound.map(&:size)
    end

    #
    # Number of vehicles idle at each station.
    #
    # @return [Array<Integer>] not nil; length num_stations; entries
    #         non-negative
    #
    def idle
      inbound.map{|etas| etas.count {|eta| eta == 0}}
    end

    #
    # Destination station of each vehicle, as in {MDPStateA}.
    #
    # @return [Array<Integer>] not nil; length num_veh; entries in [0,
    #         num_stations)
    #
    def destin
      inbound.map.with_index{|etas,i| [i]*etas.size}.flatten
    end

    #
    # Basic feasibility check.
    #
    def feasible?
      # cache these arrays locally to speed this up
      idle = self.idle
      destin = self.destin

      @model.stations.all? {|i|
        (queue[i] == 0 || (idle[i] == 0 && @model.demand.rate_from(i) > 0)) &&
          Utility::is_nondescending?(inbound[i]) &&
          inbound[i].all?{|eta| eta <= @model.max_time[i]}} &&
        inbound.flatten.size == @model.num_veh
    end
    
    #
    # Change this state to reflect the movement of +n+ vehicles from i to j.
    # There must be at least +n+ idle vehicles at +origin+.
    #
    # @return [self]
    #
    def move! origin, destin, n=1
      n.times do
        raise unless inbound[origin].shift == 0
        inbound[destin].push @model.trip_time[origin][destin]
      end
      self
    end

    #
    # Change this state so that all moving vehicles advance one time step
    # forward. Idle vehicles remain idle, and destinations and queues are not
    # changed. The resulting state may be infeasible.
    #
    # @return [self]
    #
    def advance_vehicles!
      inbound.each do |etas|
        etas.map! {|eta| if eta > 0 then eta - 1 else 0 end}
      end
      self
    end

    #
    # Move idle vehicles according to the given action.
    #
    # @return [self]
    #
    def apply_action! action
      for i in @model.stations
        for j in @model.stations
          self.move! i, j, action[i][j] if i != j
        end
      end
      self
    end

    #
    # Redefine dup to be a deep copy instead of a shallow copy.
    #
    def dup
      copy = super
      copy.queue = self.queue.dup
      copy.inbound = self.inbound.map{|etas| etas.dup}
      copy
    end

    #
    # Return state as an array; the format is as described in {MDPModelB}.
    #
    def to_a
      queue + num_inbound + inbound.flatten
    end
  end

  #
  # A model without the redundant vehicle labelling of MDPModelA. This cheats
  # somewhat by just copying from an MDPModelA instead of generating itself.
  #
  # The state representation is
  #   q_1, ..., q_S, n_1, ..., n_S, r_1, ..., r_K
  # where
  #   q_i = queue length at i (just like in Model A)
  #   n_i = number of vehicles with destination i; must satisfy \sum_i n_i = K
  #   r_k = time remaining, aligned wrt the n_i.
  # The time remaining bit is a bit different: the first n_0 entries are the
  # times remaining for the n_0 vehicles inbound to or idle at station 0 (if
  # any); moreover, they are sorted in non-decreasing order to resolve ordering
  # ambiguity.
  # 
  # An action specifies the number of vehicles to move between each pair of
  # stations. We represent it as an S-by-S matrix (where S is the number of
  # stations) with zeros on the diagonal and non-negative integer entries
  # elsewhere.
  #
  class MDPModelB < MDPModelBase

    def initialize *params
      super(*params)
      @hash = {}
    end

    attr_reader :hash

    def to_hash
      @hash
    end

    #
    # Build a model B from a model A.
    #
    def self.new_from_model_a model_a
      model_b = MDPModelB.new(model_a.trip_time, model_a.num_veh,
                              model_a.demand, model_a.max_queue)

      # note: this routine spends much of its time hashing states, so we have to
      # be careful to avoid hashing a state more than necessary; this is why we
      # have the "value = hash[key] ||= default" constructs

      for state_a, actions_a in model_a.to_hash
        state_b  = MDPStateB.from_model_a_state(model_b, state_a)
        h_b_actions = model_b.hash[state_b] ||= {}

        for action_a, succs_a in actions_a
          action_b = model_b.action_from_model_a(state_a, action_a)
          h_b_succs = h_b_actions[action_b] ||= {}

          for succ_a, (pr, reward) in succs_a
            succ_b = MDPStateB.from_model_a_state(model_b, succ_a)
            pr_reward = h_b_succs[succ_b] ||= [nil, nil]

            # the probability and reward for any equivalent triple should do
            old_pr, old_reward = pr_reward
            if old_pr
              raise "different prob" unless old_pr == pr
              raise "different rewards" unless old_reward == reward
            end

            pr_reward[0] = pr
            pr_reward[1] = reward
          end
        end
      end

      model_b
    end

    #
    # Build a new model B without building a model A first.
    #
    def self.new_from_scratch trip_time, num_veh, demand, max_queue
      model = MDPModelB.new(trip_time, num_veh, demand, max_queue)
      h = model.hash

      # enumerate feasible states; the approach we take here is to enumerate a
      # larger set of states and filter out the infeasible ones; this could
      # probably be improved
      feas_queues  = Utility.mixed_radix_sequence([model.max_queue]*
                                                  model.num_stations).to_a
      feas_inbound = Utility.integer_partitions(model.num_veh,
                                                model.num_stations)
      feas_etas    = Utility.mixed_radix_sequence([model.max_time.max]*
                                                  model.num_veh).to_a
      Utility.cartesian_product(feas_queues, feas_inbound, feas_etas).each do
        |state_array|
        state = MDPStateB.from_a(model, state_array.flatten)
        h[state] = {} if state.feasible?
      end

      # enumerate actions for each state, then possible successor states
      for state, state_actions in h
        reward = state.reward
        for action in Utility::cartesian_product(*state.idle.map{|sum|
          Utility::integer_partitions(sum, model.num_stations)})
          # zero diagonals to make this easier to read
          model.stations.each do |i|
            action[i][i] = 0
          end
          pr_rewards = state_actions[action] = {}
          for next_state, pr in model.transitions(state, action)
            pr_rewards[next_state] = [pr, reward]
          end
        end
      end

      model
    end

    #
    # Convert a (state, action) pair from MDPModelA into an action for model B.
    #
    def action_from_model_a state_a, action_a
      action_b = stations.map{stations.map{0}}
      for old_destin, new_destin in state_a.destin.zip(action_a)
        if old_destin != new_destin
          action_b[old_destin][new_destin] += 1
        end
      end
      action_b
    end

    #
    # Generate all possible successor states, their rewards, and their
    # transition probabilities.
    #
    # @param [MDPStateB] state not nil; not modified
    #
    def transitions state, action
      results = []

      # advance moving vehicles closer to their destinations
      new_state = state.dup.advance_vehicles!
      #p new_state

      # move idle vehicles according to the specified action
      new_state.apply_action! action
      #p new_state

      # the remaining idle vehicles are 'available'
      available = new_state.idle
      #puts "state: #{state.inspect}; action: #{action.inspect}"
      #puts "available: #{available.inspect}"
      
      # for each station, the basic relationship is:
      #   new_queue = max(0, queue + new_pax - (idle + landing - leaving))
      # because there can't be both idle vehicles and waiting passengers;
      # we want all values of new_pax that make new_queue <= max_queue
      max_new_pax = stations.map {|i| max_queue - state.queue[i] + available[i]}
      new_pax = [0]*num_stations
      begin
        # add new pax to waiting pax (note that this may exceed max_queue)
        # need to know how many pax we can serve now (rest must queue)
        pax_temp   = stations.map {|i| state.queue[i] + new_pax[i]}
        pax_served = stations.map {|i| [available[i], pax_temp[i]].min}
        #puts "state: #{state.inspect}"
        #puts "pax_temp: #{pax_temp}"
        #puts "pax_served: #{pax_served}"

        # update queue states
        next_state = new_state.dup
        next_state_pr = 1.0
        stations.each do |i|
          next_state.queue[i] = pax_temp[i] - pax_served[i]

          pr_i = demand.poisson_origin_pmf(i, new_pax[i])
          pr_i += demand.poisson_origin_cdf_complement(i, new_pax[i]) if
            next_state.queue[i] == max_queue
          raise "bug: pr_i > 1" if pr_i > 1
          next_state_pr *= pr_i
        end

        # the above generates states with non-zero queues at stations with zero
        # arrival rates, which would cause us to generate infeasible states
        if next_state_pr > 0
          # need to know destinations for any pax we're serving
          journey_product = stations.map {|i|
            journeys_from_i = stations.map {|j| [i, j] if i != j}.compact
            Utility.cartesian_product(*[journeys_from_i]*pax_served[i])}.compact

          #puts "journey_product:\n#{journey_product.inspect}"
          if journey_product.empty?
            # no passengers served; just return new_state
            results << [next_state, next_state_pr]
          else
            Utility.cartesian_product(*journey_product).each do |journeys|
              #available_for_pax = available.map{|ai| ai.dup}
              pax_state = next_state.dup
              pax_state_pr = next_state_pr
              #puts "journeys: #{journeys.inspect}"
              journeys.flatten(1).each do |i, j|
                pax_state.move! i, j
                pax_state_pr *= demand.at(i, j) / demand.rate_from(i)
                #puts "pax_state: #{pax_state.inspect}"
              end
              #puts "pax_state: #{pax_state.inspect}"
              results << [pax_state, pax_state_pr]
            end
          end
        end
      end while Utility.spin_array(new_pax, max_new_pax)
      results
    end
  end

  #
  # Use a policy for a {MDPModelB} to make proactive movements in the
  # corresponding {BWSim}, for comparison purposes.
  #
  # To map from {BWSim} states to MDP states, we take the following approach:
  #
  # 1. Ignore the queues. While we can measure the queues in {BWSim}, the
  #    problem is that the {BWReactiveHandler} has already assigned vehicles to
  #    serve the queued requests, and the vehicles' destinations are the
  #    requests' destinations. This means that we only use a small part of the
  #    policy: that for when the system is empty.
  # 2. Truncate ETA times. The {BWVehicle} +arrive+ times may extend more than
  #    one trip into the future, which the ETA times cannot. This means that we
  #    can't fully represent the trip times. 
  #
  # This is far from perfect, but the models don't really match, and I haven't
  # so far found a better way.
  # 
  # Here we rely on SWIG's 'director' feature, which us to override the virtual
  # methods of C++ classes (namely BWProactiveHandler) in ruby. It is all rather
  # slow, however.
  #
  class BWMDPModelBHandler < BWProactiveHandler
    def initialize sim, model, policy
      super(sim)
      @model = model
      @policy = policy
    end

    #
    # Override; called by {BWSim} after a passenger is served.
    #
    def handle_pax_served empty_origin
      #puts "pax : #{current_state.inspect}=>#{@policy[current_state].inspect}"
      apply @policy[current_state]
    end

    #
    # Override; called by {BWSim} when a vehicle becomes idle.
    #
    def handle_idle veh
      #puts "idle: #{current_state.inspect}=>#{@policy[current_state].inspect}"
      apply @policy[current_state]
    end

    #
    # Map the current simulation state to an {MDPStateB}. Queues are zeroed, and
    # ETA times are truncated to {#MDPModelB#max_time} for the appropriate
    # destination station.
    #
    # @return [MDPStateB] not nil
    #
    def current_state
      vehs_by_destin = sim.vehs.group_by {|v| v.destin}.mash! {|destin, vs|
        [destin, vs.map{|v| [v.arrive - sim.now, 0].max}.sort]}

      state = MDPStateB.new(@model)
      # note: queues are projected out (set to zero)
      state.inbound = (0...sim.num_stations).map{|i|
        (vehs_by_destin[i] || []).map {|eta| [eta, @model.max_time[i]].min}}
      state
    end

    #
    # Move idle vehicles according to the given action matrix (see {MDPModelB}).
    #
    # @return [nil]
    #
    def apply action
      for i in 0...sim.num_stations
        for j in 0...sim.num_stations
          action[i][j].times do
            sim.move_empty_od(i, j)
          end
        end
      end
      nil
    end
  end
end

