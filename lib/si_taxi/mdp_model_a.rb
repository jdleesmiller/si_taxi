module SiTaxi
  class MDPStateA
    include Comparable

    def initialize model
      @model  = model
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
    # Redefine dup to be a deep copy instead of a shallow copy.
    #
    def dup
      copy = super
      copy.queue = self.queue.dup
      copy.destin = self.destin.dup
      copy.eta = self.eta.dup
      copy
    end

    #
    # Mutate this state into the 'next' state in numerical order.
    #
    # @return [Boolean] true iff the new state is not state zero
    #
    def next!
      Utility.spin_array(queue,  @model.max_queue) ||
      Utility.spin_array(destin, @model.num_stations - 1) ||
      Utility.spin_array(eta,    @model.max_time)
    end

    #
    #
    # @return Array<Integer> indexes of vehicles idle at station i
    #
    def idle_vehicles_at i
      @model.vehicles.select {|k| destin[k] == i && eta[k] == 0}
    end

    #
    #
    # @return Array<Integer> indexes of vehicles that are either idle at
    # station i or becoming idle in the current time step (eta == 1)
    #
    def available_vehicles_at i
      @model.vehicles.select {|k| destin[k] == i && eta[k] <= 1}
    end

    #
    # Feasible iff there is no station with both waiting passengers and idle
    # vehicles.
    #
    # @return [Boolean] 
    #
    def feasible?
      !@model.stations.any? {|i| queue[i] > 0 && idle_vehicles_at(i).size > 0}
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

    def <=> state
      self.to_a <=> state.to_a
    end

    def to_a
      queue + destin + eta
    end

    def inspect
      to_a.inspect
    end
  end

  class MDPModelA
    def initialize trip_time, num_veh, demand, max_queue
      @trip_time = trip_time
      @num_veh = num_veh
      @demand = demand
      @max_queue = max_queue

      @stations = (0...trip_time.size).to_a
      @vehicles = (0...num_veh).to_a
      @max_time = trip_time.flatten.max
      @value = {}
      @action = {}
    end

    attr_reader :trip_time
    #
    # @return [ODMatrixWrapper]
    #
    attr_reader :demand
    attr_reader :num_veh
    attr_reader :max_queue
    attr_reader :stations
    attr_reader :vehicles
    attr_reader :max_time
    attr_reader :value
    attr_reader :policy

    def num_stations; stations.size end

    def evaluate_policy
      delta = 0.0
      with_each_state do |state|
        new_value = backup(state, policy[state])
        delta = [delta, (value[state] - new_value).abs].max
        value[state] = new_value
      end
      delta
    end

    def improve_policy
      stable = false
      with_each_state do |state|
        a_max = nil
        v_max = -Float::MAX
        with_each_action_for(state) do |action|
          v = backup(state, action)
          if v > v_max
            a_max = action
            v_max = v
          end
        end
        raise "no feasible actions in state #{state}" unless a_max
        stable = false if policy[state] != a_max
        policy[state] = a_max
      end
      stable
    end

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
    # @yield [state] 
    #
    def with_each_successor_state state, action
      # count vehicles already idle (eta 0) or about to become idle (eta 1),
      # but subtract those that are moving away due to the action
      available = stations.map {|i| vehicles.count {|k|
        state.destin[k] == i && state.eta[k] <= 1 && action[k] == i}}

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

        # update queue states and vehicles due to actions
        new_state = state.dup
        new_state_pr = 1.0
        stations.each do |i|
          new_state.queue[i] = pax_temp[i] - pax_served[i]
          new_state.destin = action.dup

          pr_i = demand.poisson_arrival_pmf(i, new_pax[i])
          pr_i += demand.poisson_arrival_cdf_complement(i, new_pax[i]) if
            new_state.queue[i] == max_queue
          raise "bug: pr_i > 1" if pr_i > 1
          new_state_pr *= pr_i
        end

        # need to know destinations for the pax we're serving
        pax_stations = stations.select {|i| pax_served[i] > 0}
        pax_destins = pax_stations.map {|i| stations.purge(i) * pax_served[i]}
        pax_destins = Utility.cartesian_product(*pax_destins)
        if pax_destins
          pax_destins.each do |pax_destin|
            pax_state = new_state.dup
            pax_stations.zip(pax_destin).each do |i, destin_i|
              available_i = pax_state.available_vehicles_at(i)
              pax_state.destin[available_i.first] = destin_i
              pax_state.set_eta_from(state)
              pax_state_pr = new_state_pr * demand.at(i, destin_i) /
                demand.rate_to(destin_i)
              yield pax_state, pax_state_pr
            end
          end
        else
          # no passengers served; just yield new_state
          new_state.set_eta_from(state)
          yield new_state, new_state_pr
        end
      end while Utility.spin_array(new_pax, max_new_pax)
    end

    #
    # 
    # Note: we currently enumerate all possible permutations of passenger
    # destinations; we could instead enumerate only the numbers of requests 
    # per destination (must sum to total requests), because the difference is
    # just in the order in which we assign the idle vehicles.
    #
    # @param [Array<Integer>] state can be modified in place TODO maybe not
    #
    # @param [Array<Integer>] action not modified
    #
    def backup state, action
      # count vehicles already idle
      idle = stations.map {|i| vehicles.count {|k|
        state.destin[k] == i && state.eta[k] == 0}}

      # count vehicles that are about to become idle
      landing = stations.map {|i| vehicles.count {|k|
        state.destin[k] == i && state.eta[k] == 1}}

      # count vehicles that are leaving due to the selected action
      leaving = stations.map {|i| vehicles.count {|k|
        state.destin[k] == i && state.eta[k] == 0 &&
        action[k] != i}}

      # for each station, the basic relationship is:
      #   new_queue = max(0, queue + new_pax - (idle + landing - leaving))
      # because there can't be both idle vehicles and waiting passengers;
      # we want all values of new_pax that make new_queue <= max_queue
      max_new_pax = stations.map {|i|
        max_queue - state_queue(state, i) + (idle[i] + landing[i] - leaving[i])}

      new_pax = [0]*num_stations
      begin
        # need to know how many pax we can serve now (rest must queue)
        serving = stations.map {|i|
          [idle[i] + landing[i] - leaving[i], new_pax[i]].min}

        # need to know destinations for the ones we're serving
        pax_destins = stations.map {|i| stations.purge(i)*serving[i]}
        Utility.cartesian_product(*pax_destins) do |pax_destin|
          puts pax_destin
          #new_state = state.dup

        # update station queues to reflect the new arrival; see notes above
        #stations.each do |i|
        # TODO
        #  state_queue(new_state, i) = [state_queue(state, i) + new_pax[i] -
        #    (idle[i] + landing[i] - leaving[i]), 0].max
        #end
        end while Utility.spin_array(destins, max_destins)
      end while Utility.spin_array(new_pax, max_new_pax)
    end
#      # move idle vehicles according to the specified action
#      apply_action(state, action)
#
#      # move vehicles closer to their destinations
#      vehicles.each do |k|
#        state_eta(state, k) -= 1 if state_eta(state, k) > 0
#      end
#
#      # sweep over all possible next states
#      v = 0.0
#      with_each_state do |new_state|
#        # prob of next state:
#        # 0 if we moved a non-idle vehicle
#        # 0 if queue length decreased without moving an idle vehicle
#        # 0 if number of idle vehicles increased
#        # 0 if there is a station with qi > 0 and idle vehicles
#        vehicles.each do |k|
#          if state_eta(state, k) == 0
#
#          else
#            # vehicle not idle; must leave it alone
#            if state_eta(state, k) == state_eta(new_state, k)
#              vs = 1.0
#            else
#              vs = 0.0
#            end
#          end
#        end
#      end

    #
    # Modify state so that its idle vehicle destinations match the 
    # and ETAs.
    #
    # @param [Array<Integer>] state modified in place
    #
    # @return nil
    #
    def apply_action state, action
      vehicles.each do |k|
        old_destin = state.destin[k]
        new_destin = action[k]
        state.destin[k] = new_destin
        state.eta[k]    = trip_time[old_destin][new_destin]
      end
      nil
    end
  end
end
