module SiTaxi
  class MDPStateA < MDPStateBase
    def initialize model
      super model
      @queue  = [0]*model.num_stations
      @destin = [0]*model.num_veh
      @eta    = [0]*model.num_veh
    end

    #
    # Create state from array representation (see to_a).
    #
    def self.from_a model, a
      state = self.new(model)
      ns, nv = model.num_stations, model.num_veh
      state.queue  = a[0,     ns]
      state.destin = a[ns,    nv]
      state.eta    = a[ns+nv, nv]
      state
    end

    attr_accessor :queue, :destin, :eta

    #
    # Mutate this state into the 'next' state in numerical order.
    #
    # @return [Boolean] true iff the new state is not state zero
    #
    def next!
      Utility.spin_array(queue,  @model.max_queue) ||
      Utility.spin_array(destin, @model.num_stations - 1) ||
      Utility.spin_array(eta,    @model.max_time.max)
    end

    #
    #
    # @return [Array<Integer>] indexes of vehicles idle at station i
    #
    def idle_vehicles_at i
      @model.vehicles.select {|k| destin[k] == i && eta[k] == 0}
    end

    #
    # Feasible iff there is no station with both waiting passengers and idle
    # vehicles and travel times are in range.
    #
    # @return [Boolean] 
    #
    def feasible?
      @model.stations.all? {|i| queue[i] == 0 ||
        (idle_vehicles_at(i).empty? && @model.demand.rate_from(i) > 0)} &&
        @model.vehicles.all? {|k| eta[k] <= @model.max_time[destin[k]]}
    end

    #
    # Update expected time to arrival (eta) based on old destinations (state)
    # and current destinations. If a vehicle's ETA is larger than 1, it is just
    # decremented; otherwise, it's set to the trip time between its old and new
    # destination.
    #
    def set_eta_from state
      @model.vehicles.each do |k|
        if self.eta[k] > 1
          self.eta[k] -= 1
        else
          self.eta[k] = @model.trip_time[state.destin[k]][self.destin[k]]
        end
      end
      nil
    end

    #
    # Redefine dup to be a deep copy instead of a shallow copy.
    #
    def dup
      copy = super
      copy.queue = self.queue.dup
      copy.destin = self.destin.dup
      copy.eta = self.eta.dup
      copy
    end

    def to_a
      queue + destin + eta
    end
  end

  class MDPModelA < MDPModelBase
    #
    # Yield for each state in numeric order.
    #
    # @yield [state] a copy of the current state; you can modify it without
    # affecting the iteration
    #
    def with_each_state
      state = MDPStateA.new(self)
      begin
        yield state.dup if state.feasible?
      end while state.next!
      nil
    end

    #
    # @return [Array] array of states
    #
    def states
      states = []
      with_each_state do |state|
        states << state
      end
      states
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
          new_state.destin = action.dup # TODO move out of loop

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
        #
        #p stations.map {|i|
        #  journeys = stations.purge(i).map {|j| [i, j] }
        #  Utility.cartesian_product(*[journeys]*pax_served[i])} 
        #pax_stations = stations.select {|i| pax_served[i] > 0}
        #puts "pax_stations: #{pax_stations.inspect}"
        #pax_destins = pax_stations.map {|i| [stations.purge(i)] * pax_served[i]}
        #puts "pax_destins: #{pax_destins.inspect}"
        ## [1,0,2]
        ## [[1,2,3],[],[0,1,3,0,1,3]]
        ## or
        ## [1,0]
        ## [[1],[]]
        #pax_destins = Utility.cartesian_product(*pax_destins)
        #if pax_destins
        #  puts "pax_destins: #{pax_destins.inspect}"
        #  pax_destins.each do |pax_destin|
        #    puts "pax_destin: #{pax_destin}"
        #    pax_stations.zip(pax_destin).each do |i, destins_i|
        #      available_i = new_state.available_vehicles_at(i)
        #      pax_state = new_state.dup
        #      available_i.zip(destins_i).each do |k, destin_i|
        #        pax_state.destin[k] = destin_i
        #        pax_state.set_eta_from(state)
        #        pax_state_pr = new_state_pr * demand.at(i, destin_i) /
        #          demand.rate_to(destin_i)
        #        p pax_state
        #        yield pax_state, pax_state_pr
        #      end
        #    end
        #  end
        #else
        #  # no passengers served; just yield new_state
        #  new_state.set_eta_from(state)
        #  yield new_state, new_state_pr
        #end
      end while Utility.spin_array(new_pax, max_new_pax)
    end

    #
    # Build the explicit transition matrices (as nested Hashes).
    #
    # @return Hash
    #
    def to_hash
      # set up nested hashes using appropriate missing value defaults
      hash = Hash.new {|h0,k0|
      h0[k0] = Hash.new {|h1,k1|
      h1[k1] = Hash.new {[0,0]} } }

      with_each_state do |s0|
        with_each_action_for(s0) do |a|
          with_each_successor_state(s0, a) do |s1, pr|
            hash[s0][a][s1] = [pr, s0.reward]
          end
        end
      end
      hash
    end
  end
end
