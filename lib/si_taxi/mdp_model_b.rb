module SiTaxi
  class MDPStateB < MDPStateBase
    def initialize model
      super model
      @queue   = [0]*model.num_stations
      @inbound = [0]*model.num_veh
      @eta     = [0]*model.num_veh
    end

    #
    # Create state from array representation (see to_a).
    #
    def self.from_a model, a
      state = self.new(model)
      ns, nv = model.num_stations, model.num_veh
      state.queue   = a[0,    ns]
      state.inbound = a[ns,   ns]
      state.eta     = a[2*ns, nv]
      state
    end

    attr_accessor :model, :queue, :inbound, :eta

    #
    # Mutate this state into the 'next' state in numerical order; the resulting
    # state is not guaranteed to be feasible.
    #
    # @return [Boolean] true iff the new state is not state zero
    #
    def next!
      Utility.spin_array(queue,   @model.max_queue) ||
      Utility.spin_array(inbound, @model.num_veh) ||
      Utility.spin_array(eta,     @model.max_time.max)
    end

    #
    #
    # @return [Array<Integer>] length inbound[i]; time steps remaining until
    # each vehicle inbound to i becomes idle; entries non-negative and in
    # ascending order; result is undefined if sum of inbound counts does not
    # equal the fleet size
    #
    def eta_at i
      eta[inbound[0...i].sum, inbound[i]]
    end

    #
    #
    # @return [Integer] number of idle vehicles at station i
    #
    def idle_vehicles_at i
      eta_at(i).count {|t| t == 0}
    end

    #
    # Feasible iff inbound vehicle counts sum to the fleet size, there is no
    # station with both waiting passengers and idle vehicles and travel times
    # are in range.
    #
    # @return [Boolean] 
    #
    def feasible?
      inbound.sum == @model.num_veh &&
        @model.stations.all? {|i| queue[i] == 0 ||
          (idle_vehicles_at(i) == 0 && @model.demand.rate_from(i) > 0)} &&
        @model.stations.all? {|j| eta_at(j).all? {|t| t <= @model.max_time[j]}}
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

  class MDPModelB
    #
    # Yield for each state in numeric order.
    #
    # @yield [state] a copy of the current state; you can modify it without
    # affecting the iteration
    #
    def with_each_state
      state = MDPStateB.new(self)
      begin
        yield state.dup if state.feasible?
      end while state.next!
      nil
    end

    #
    # Yield for each action in numeric order. Note that the actions yielded may
    # not be feasible for some states.
    #
    # @yield [action] 
    #
    def with_each_action
      action = [0] * num_veh
      begin 
        yield action.dup
      end while Utility.spin_array(action, num_stations - 1)
      nil
    end

    #
    # Yield for each feasible action from the given state, in numeric order. 
    #
    # @param [Array<Integer>] state not modified
    #
    # @yield [action] 
    #
    def with_each_action_for state
      # can only move idle vehicles; can move to any destination
      with_each_action do |action|
        yield action if vehicles.all? {|k|
          action[k] == state.destin[k] || state.eta[k] == 0}
      end
    end

    #
    # Yield for each possible successor state of state under action.
    #
    # Note: we currently enumerate all possible permutations of passenger
    # destinations; we could instead enumerate only the numbers of requests 
    # per destination (must sum to total requests), because the difference is
    # just in the order in which we assign the idle vehicles.
    #
    # @param [MDPStateA] state
    #
    # @param [Array<Integer>] action 
    #
    # @yield [state] 
    #
    def with_each_successor_state state, action
      # find vehicles already idle (eta 0) or about to become idle (eta 1),
      # but ignore those that are moving away due to the action
      available = stations.map {|i| vehicles.select {|k|
        state.destin[k] == i && state.eta[k] <= 1 && action[k] == i}}
      #puts "available: #{available.inspect}"

      # for each station, the basic relationship is:
      #   new_queue = max(0, queue + new_pax - (idle + landing - leaving))
      # because there can't be both idle vehicles and waiting passengers;
      # we want all values of new_pax that make new_queue <= max_queue
      max_new_pax = stations.map {|i|
        max_queue - state.queue[i] + available[i].count}
      new_pax = [0]*num_stations
      begin
        # add new pax to waiting pax (note that this may exceed max_queue)
        # need to know how many pax we can serve now (rest must queue)
        pax_temp   = stations.map {|i| state.queue[i] + new_pax[i]}
        pax_served = stations.map {|i| [available[i].count, pax_temp[i]].min}
        #puts "state: #{state.inspect}"
        #puts "pax_temp: #{pax_temp}"
        #puts "pax_served: #{pax_served}"

        # update queue states and vehicles due to actions
        new_state = state.dup
        new_state_pr = 1.0
        stations.each do |i|
          new_state.queue[i] = pax_temp[i] - pax_served[i]
          new_state.destin = action.dup

          pr_i = demand.poisson_origin_pmf(i, new_pax[i])
          pr_i += demand.poisson_origin_cdf_complement(i, new_pax[i]) if
            new_state.queue[i] == max_queue
          raise "bug: pr_i > 1" if pr_i > 1
          new_state_pr *= pr_i
        end

        # the above generates states with non-zero queues at stations with zero
        # arrival rates, which would cause us to generate infeasible states
        if new_state_pr > 0
          # need to know destinations for any pax we're serving
          journey_product = stations.map {|i|
            journeys_from_i = stations.map {|j| [i, j] if i != j}.compact
            Utility.cartesian_product(*[journeys_from_i]*pax_served[i])}.compact
          #puts "new_state: #{new_state.inspect}"
          #puts "journey_product:\n#{journey_product.inspect}"
          if journey_product.empty?
            # no passengers served; just yield new_state
            new_state.set_eta_from(state)
            yield new_state, new_state_pr
          else
            Utility.cartesian_product(*journey_product).each do |journeys|
              available_for_pax = available.map{|ai| ai.dup}
              pax_state = new_state.dup
              pax_state_pr = new_state_pr
              #puts "journeys: #{journeys.inspect}"
              journeys.flatten(1).each do |i, j|
                pax_state.destin[available_for_pax[i].shift] = j
                pax_state_pr *= demand.at(i, j) / demand.rate_from(i)
                #puts "pax_state: #{pax_state.inspect}"
              end
              pax_state.set_eta_from(state)
              #puts "pax_state: #{pax_state.inspect}"
              yield pax_state, pax_state_pr
            end
          end
        end
      end while Utility.spin_array(new_pax, max_new_pax)
    end
  end
end
