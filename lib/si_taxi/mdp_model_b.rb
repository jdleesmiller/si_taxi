module SiTaxi
  #
  # State for {MDPModelB}.
  #
  class MDPStateB < MDPStateBase
    def initialize model
      super(model)
      @queue   = [0]*model.num_stations
      @inbound = [0]*model.num_stations
      @eta     = [0]*model.num_veh
    end

    #
    # Create state from array representation (see to_a).
    #
    # @param [MDPModelB] model
    # @param [Array] a from {MDPStateB#to_a}
    #
    def self.from_a model, a
      state = self.new(model)
      ns, nv = model.num_stations, model.num_veh
      state.queue   = a[0,    ns]
      state.inbound = a[ns,   ns]
      state.eta     = a[2*ns, nv]
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
      vehs_by_destin = (0...ns).map {|j|
        (0...nv).select {|k| a_state.destin[k] == j}.
          map{|k| a_state.eta[k]}.sort}

      b_state.queue   = a_state.queue.dup
      b_state.inbound = vehs_by_destin.map{|group| group.size}
      b_state.eta     = vehs_by_destin.flatten
      b_state
    end

    attr_accessor :queue, :inbound, :eta

    #
    # Number of vehicles idle at each station.
    #
    def idle
      k = 0
      inbound.map{|num|
        idle = eta[k,num].count {|r| r == 0}
        k += num
        idle
      }
    end

    #
    # Destination station of each vehicle.
    #
    def destin
      inbound.map.with_index{|num,i| [i]*num}.flatten
    end

    #
    # Basic feasibility check.
    #
    def feasible?
      # cache these arrays locally to speed this up
      idle = self.idle
      destin = self.destin

      @model.stations.all? {|i|
        queue[i] == 0 || (idle[i] == 0 && @model.demand.rate_from(i) > 0)} &&
        inbound.sum == @model.num_veh &&
        @model.vehicles.all? {|k| eta[k] <= @model.max_time[destin[k]]}
    end

    #
    # Mutate this state into the 'next' state in numerical order. Note that the
    # resulting state may not be feasible.
    #
    # @return [Boolean] true iff the new state is not state zero
    #
    def next!
      Utility.spin_array(queue,   @model.max_queue) ||
      Utility.spin_array(inbound, @model.num_veh) ||
      Utility.spin_array(eta,     @model.max_time.max)
    end

    #
    # Redefine dup to be a deep copy instead of a shallow copy.
    #
    def dup
      copy = super
      copy.queue = self.queue.dup
      copy.inbound = self.inbound.dup
      copy.eta = self.eta.dup
      copy
    end

    def to_a
      queue + inbound + eta
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

    def self.new_from_scratch trip_time, num_veh, demand, max_queue
      model = MDPModelB.new(trip_time, num_veh, demand, max_queue)
      h = model.hash

      # enumerate feasible states
      state = MDPStateB.new(model)
      begin
        h[state.dup] = {} if state.feasible?
      end while state.next!

      # enumerate actions for each state, then possible successor states
      for state, state_actions in h
        for action in Utility::cartesian_product(*state.idle.map{|sum|
          Utility::integer_partitions(sum, model.num_stations)})
          state_actions[action] = model.transitions(state, action)
        end
      end

      model
    end

    #
    # Generate all possible successor states, their rewards, and their
    # transition probabilities.
    #
    def transitions state, action
      # TODO not done yet
      {}
#      # find vehicles already idle (eta 0) or about to become idle (eta 1),
#      # but ignore those that are moving away due to the action
#      available = stations.map {|i| vehicles.select {|k|
#        state.destin[k] == i && state.eta[k] <= 1 && action[k] == i}}
#      #puts "available: #{available.inspect}"
#
#      # for each station, the basic relationship is:
#      #   new_queue = max(0, queue + new_pax - (idle + landing - leaving))
#      # because there can't be both idle vehicles and waiting passengers;
#      # we want all values of new_pax that make new_queue <= max_queue
#      max_new_pax = stations.map {|i|
#        max_queue - state.queue[i] + available[i].count}
#      new_pax = [0]*num_stations
#      begin
#        # add new pax to waiting pax (note that this may exceed max_queue)
#        # need to know how many pax we can serve now (rest must queue)
#        pax_temp   = stations.map {|i| state.queue[i] + new_pax[i]}
#        pax_served = stations.map {|i| [available[i].count, pax_temp[i]].min}
#        #puts "state: #{state.inspect}"
#        #puts "pax_temp: #{pax_temp}"
#        #puts "pax_served: #{pax_served}"
#
#        # update queue states and vehicles due to actions
#        new_state = state.dup
#        new_state_pr = 1.0
#        stations.each do |i|
#          new_state.queue[i] = pax_temp[i] - pax_served[i]
#          new_state.destin = action.dup
#
#          pr_i = demand.poisson_origin_pmf(i, new_pax[i])
#          pr_i += demand.poisson_origin_cdf_complement(i, new_pax[i]) if
#            new_state.queue[i] == max_queue
#          raise "bug: pr_i > 1" if pr_i > 1
#          new_state_pr *= pr_i
#        end
#
#        # the above generates states with non-zero queues at stations with zero
#        # arrival rates, which would cause us to generate infeasible states
#        if new_state_pr > 0
#          # need to know destinations for any pax we're serving
#          journey_product = stations.map {|i|
#            journeys_from_i = stations.map {|j| [i, j] if i != j}.compact
#            Utility.cartesian_product(*[journeys_from_i]*pax_served[i])}.compact
#          #puts "new_state: #{new_state.inspect}"
#          #puts "journey_product:\n#{journey_product.inspect}"
#          if journey_product.empty?
#            # no passengers served; just yield new_state
#            new_state.set_eta_from(state)
#            yield new_state, new_state_pr
#          else
#            Utility.cartesian_product(*journey_product).each do |journeys|
#              available_for_pax = available.map{|ai| ai.dup}
#              pax_state = new_state.dup
#              pax_state_pr = new_state_pr
#              #puts "journeys: #{journeys.inspect}"
#              journeys.flatten(1).each do |i, j|
#                pax_state.destin[available_for_pax[i].shift] = j
#                pax_state_pr *= demand.at(i, j) / demand.rate_from(i)
#                #puts "pax_state: #{pax_state.inspect}"
#              end
#              pax_state.set_eta_from(state)
#              #puts "pax_state: #{pax_state.inspect}"
#              yield pax_state, pax_state_pr
#            end
#          end
#        end
#      end while Utility.spin_array(new_pax, max_new_pax)
    end
  end
end
