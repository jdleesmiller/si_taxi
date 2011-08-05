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
    def initialize model_a
      super(model_a.trip_time, model_a.num_veh, model_a.demand,
            model_a.max_queue)

      # note: this routine spends much of its time hashing states, so we have to
      # be careful to avoid hashing a state more than necessary; this is why we
      # have the "value = hash[key] ||= default" constructs

      h_b = {}
      for state_a, actions_a in model_a.to_hash
        state_b  = MDPStateB.from_model_a_state(self, state_a)
        h_b_actions = h_b[state_b] ||= {}

        for action_a, succs_a in actions_a
          action_b = action_from_model_a(state_a, action_a)
          h_b_succs = h_b_actions[action_b] ||= {}

          for succ_a, (pr, reward) in succs_a
            succ_b = MDPStateB.from_model_a_state(self, succ_a)
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
      @hash = h_b
    end

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
  end
end
