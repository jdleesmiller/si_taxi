#
# Some of this could be spun out into a gem... some is SiTaxi-specific.
#
# Useful to distinguish between Implicit and Explicit models.
# Implicit means that we can sample from it; this is what we need for big models
# and monte carlo / RL methods; this handles finite and infinite MDPs
# Explicit means that we can build a full transition matrix and keep all of the
# states etc. in memory; this is necessarily a finite MDP.
#
# Want to be able to separate model specification from solution.
# Going from implicit to explicit is not possible, but an explicit to implicit
# adaptor should be provided.
# An implicit model can still be used with a lookup table for value/policy data,
# but it doesn't work with an explicit solver.
# A state in an implicit model has to:
# 1) know its reward
# 2) generate a valid action and successor state
# 3) be hashable, if using a Hash lookup table
#
# An action in an implicit model has to:
# 1) be hashable, if using a Hash lookup table
#
# A state in an explicit model has to:
# 1) know its reward, but it could instead be specified as a vector
# 2) know its valid actions, but these are store in T
# 3) know successor state probabilites, but again these are stored in T 
# 4) be hashable, so we can find it in T
#
# An action in an explicit model has to:
# 1) be hashable, so we can find it in T
#
# Another issue is in how much we want to use objects vs functions.
# In the explicit case, forcing T to be a hash means that it encodes all of the
# states and all of the legal actions. In the implicit case, I guess the
# algorithms are all pretty trivial anyway (the hard part is approximating the
# states), so it would not be big deal to provide a both object- and
# function-oriented routines.
#
module MarkovDecisionProcess
end

#
# Mix-in to help an arbitrary object function as a state or action; it assumes
# that the object can be converted to an array, and it uses this array for
# comparison, hashing and sorting purposes.
#
# An implementing class must define +to_a+. Also, if it has complicated internal
# structure (e.g. array members), +dup+ must be overridden to provide a deep
# copy (instead of the default shallow copy).
#
# @example
#   class MyMDPState
#     include MarkovDecisionProcess::VectorValued
#
#     def initialize x, y
#       @x = @x
#       @y = @y
#     end
#
#     attr_accessor :x, :y
#
#     def to_a
#       [x, y]
#     end
#   end
#
module MarkovDecisionProcess::VectorValued
  include Comparable

  #
  # Redefine comparison so we can sort states lexically.
  #
  def <=> state
    self.to_a <=> state.to_a
  end

  #
  # Redefine hashing so we can use states as hash keys.
  #
  def hash
    self.to_a.hash
  end

  #
  # Redefine equality so we can use states as hash keys.
  #
  def eql? state
    self.to_a.eql? state.to_a
  end
end

#
# Use policy iteration and value iteration (and a few variants thereon) to solve
# MDPs with state and action spaces that are finite and sufficiently small to be
# explicitly represented in memory.
#
# Use of hashes is reasonably efficient when the transitions are sparse, and it
# allows for states and actions to be arbitrary objects, without worrying about
# the numbering scheme (provided these objects define hash codes; see the
# {VectorValued} mix-in).
#
class MarkovDecisionProcess::ExplicitSolver
  def initialize transitions, reward, discount, policy,
    value=Hash.new {|v,s| v[s] = reward[s]}
    
    @transitions = transitions
    @reward      = reward
    @discount    = discount
    @value       = value
    @policy      = policy
  end

  attr_accessor :value, :policy

  #
  # Refine our estimate of the value function for the current policy; this can
  # be used to implement variants of policy iteration.
  #
  # This is the 'policy evaluation' step in Figure 4.3 of Sutton and Barto
  # (1998).
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def evaluate_policy
    delta = 0.0
    for state, actions in @transitions
      new_value = @reward[state]
      for succ, succ_pr in actions[@policy[state]]
        new_value += @discount*succ_pr*@value[succ]
      end
      delta = [delta, (@value[state] - new_value).abs].max
      @value[state] = new_value
    end
    delta
  end

  #
  # Make our policy greedy with respect to our current value function; this can
  # be used to implement variants of policy iteration.
  #
  # This is the 'policy improvement' step in Figure 4.3 of Sutton and Barto
  # (1998).
  # 
  # @return [Boolean] false iff the policy changed for any state
  #
  def improve_policy
    stable = true
    for state, actions in @transitions
      a_max = nil
      v_max = -Float::MAX
      for action in actions.keys
        v = backup_value(state, action)
        if v > v_max
          a_max = action
          v_max = v
        end
      end
      raise "no feasible actions in state #{state}" unless a_max
      stable = false if @policy[state] != a_max
      @policy[state] = a_max
    end
    stable
  end

  #
  # Do one iteration of value iteration.
  #
  # This is the algorithm from Figure 4.5 of Sutton and Barto (1998). It is
  # mostly equivalent to calling evaluate_policy and then improve_policy, but it
  # does fewer backups.
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def value_iteration
    delta = 0.0
    for state, actions in @transitions
      state_reward = @reward[state]
      for action, succs in actions
        v = state_reward
        for succ, succ_pr in succs
          v += @discount*succ_pr*@value[succ]
        end
        if v > v_max
          a_max = action
          v_max = v
        end
      end
      delta = [delta, (@value[state] - v_max).abs].max
      @value[state]  = v_max
      @policy[state] = a_max
    end
    delta
  end

  #
  # Compute revised estimate for the value of taking the given action in the
  # given state. This is a 'Bellman backup.'
  # 
  # @param state
  #
  # @param action
  #
  # @return [Float]
  #
  def backup_value state, action
    v = @reward[state]
    for succ, succ_pr in @transitions[state][action]
      v += @discount*succ_pr*@value[succ]
    end
    v
  end
end

#
# Wrapper for {ExplicitSolver} that may help to solve models with complicated
# state objects more quickly than ExplicitSolver would; it transparently numbers
# all states and actions, to avoid repeatedly rehashing them during the
# computation, which can slow things down significantly.
#
class MarkovDecisionProcess::ExplicitRichStateSolver <
  MarkovDecisionProcess::ExplicitSolver

  def initialize transitions, reward, discount, policy, value=Hash.new(0.0)
    raise ArgumentError.new('reward and policy maps must have same size') if
      reward.size != policy.size

    # build map from states to numbers and back; the order is arbitrary
    @state_num = Hash[*reward.keys.zip(0...reward.size).flatten(1)]

    # build map from actions to numbers
    all_actions = transitions.values.map(&:keys).flatten(1).uniq
    @action_num = Hash[*all_actions.zip(0...all_actions.size).flatten(1)]

    # rewrite transitions with state and action numbers
    n_transitions = {}
    for state, actions in transitions
      n_actions = n_transitions[@state_num[state]] = {}
      for action, succs in actions
        n_succs = n_actions[@action_num[action]] = {}
        for succ, succ_pr in succs
          n_succs[@state_num[succ]] = succ_pr
        end
      end
    end

    # rewrite rewards, (initial) values and (initial) policy for state numbers
    n_reward = Hash[*@state_num.map{|n, s| [n, reward[s]]}.flatten(1)]
    n_value  = Hash[*@state_num.map{|n, s| [n, value[s]]}.flatten(1)]
    n_policy = Hash[*@state_num.map{|n, s| [n,
      @action_num[policy[s]]]}.flatten(1)]

    super(n_transitions, n_reward, discount, n_value, n_policy)
  end

  def value
    num_state = @state_num.invert
    Hash[*super.map{|ns, v| [num_state[ns], v]}.flatten(1)]
  end
  
  def policy
    num_state  = @state_num.invert
    num_action = @action_num.invert
    Hash[*super.map{|ns, na| [num_state[ns], num_action[na]]}.flatten(1)]
  end
end

module SiTaxi
  #
  # Common features for the A and B states.
  #
  class MDPStateBase
    include MarkovDecisionProcess::VectorValued

    def initialize model
      @model = model
    end

    attr_accessor :model

    #
    # The immediate reward for this state.
    #
    # @return [Float, nil] nil if state is infeasible
    #
    def reward
      -queue.sum.to_f if feasible?
    end

    #
    # Allowed actions in this state. 
    #
    # @return [Array<Array<Integer>>]
    #
    def actions
      actions = []
      @model.with_each_action_for(self) do |action|
        actions << action
      end
      actions
    end

    #
    # All successor states with non-zero probability under the given action. 
    # The probabilities are not returned; see also
    # {MDPModelA#with_each_successor_state}.
    #
    # @return [Array<MDPStateA>]
    #
    def successors action
      states = []
      @model.with_each_successor_state(self, action) do |ss, pr|
        states << ss
      end
      states
    end

    def inspect
      to_a.inspect
    end
  end

  #
  # Common features for the A and B models.
  #
  class MDPModelBase
    def initialize trip_time, num_veh, demand, max_queue
      @trip_time = trip_time
      @num_veh = num_veh
      @demand = demand
      @max_queue = max_queue

      @stations = (0...trip_time.size).to_a
      @vehicles = (0...num_veh).to_a

      # maximum time for j is the max_i T_ij
      @max_time = NArray[trip_time].max(1).to_a.first
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

    def num_stations; stations.size end

    #
    # Build the explicit transition matrices (as nested Hashes).
    #
    # @return Hash
    #
    def transitions
      # set up nested hashes using appropriate missing value defaults
      mat = Hash.new {|h0,k0|
        h0[k0] = Hash.new {|h1,k1|
          h1[k1] = Hash.new {0} } }

      with_each_state do |s0|
        with_each_action_for(s0) do |a|
          with_each_successor_state(s0, a) do |s1, pr|
            mat[s0][a][s1] = pr
          end
        end
      end
      mat
    end

    #
    # Print transition probabilities and rewards in sparse format.
    #
    def dump io=$stdout, delim=','
      io.puts %w(state action new_state probability reward).join(delim)

      tr = self.transitions
      ss = self.states
      tr.keys.sort.each do |action|
        tra = tr[action]
        ss.each do |s0|
          if tra.has_key?(s0)
            tr0 = tra[s0]
            ss.each do |s1|
              if tr0.has_key?(s1)
                io.puts [s0.inspect, action.inspect, s1.inspect,
                  tr0[s1], s0.reward].map(&:inspect).join(delim)
              end
            end
          end
        end
      end
    end

    #
    # Collect states from {#with_each_state} into an array.
    #
    def states
      states = []
      with_each_state do |state|
        states << state
      end
      states
    end

    #
    # Yield for all feasible states.
    #
    # @abstract
    #
    def with_each_state
      raise NotImplementedError
    end

  end
end
