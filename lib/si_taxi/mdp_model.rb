require 'finite_mdp'

#
# Common features for the A and B states.
#
class SiTaxi::MDPStateBase
  include FiniteMDP::VectorValued
  include Comparable

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

  #
  # Redefine comparison so we can sort states lexically.
  #
  def <=> state
    self.to_a <=> state.to_a
  end

  def inspect
    to_a.inspect
  end
end

#
# Common features for the A and B models.
#
class SiTaxi::MDPModelBase
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

  def check_transition_probabilities_sum
    FiniteMDP::HashModel.new(self.to_hash).check_transition_probabilities_sum
  end

#  #
#  # Print transition probabilities and rewards in sparse format.
#  #
#  def dump io=$stdout, delim=','
#    io.puts %w(state action new_state probability reward).join(delim)
#
#    tr = self.transitions
#    ss = self.states
#    tr.keys.sort.each do |action|
#      tra = tr[action]
#      ss.each do |s0|
#        if tra.has_key?(s0)
#          tr0 = tra[s0]
#          ss.each do |s1|
#            if tr0.has_key?(s1)
#              io.puts [s0.inspect, action.inspect, s1.inspect,
#                tr0[s1], s0.reward].map(&:inspect).join(delim)
#            end
#          end
#        end
#      end
#    end
#  end

  #
  # Yield for all feasible states.
  #
  # @abstract
  #
  def with_each_state
    raise NotImplementedError
  end
end
