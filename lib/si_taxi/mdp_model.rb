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
  # @return [Array<MDPStateBase>]
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
    @num_veh   = num_veh
    @demand    = demand
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
  # Sanity check.
  #
  def check_transition_probabilities_sum
    FiniteMDP::HashModel.new(self.to_hash).check_transition_probabilities_sum
  end

  #
  # Create an explicit solver for the model.
  #
  def solver discount
    FiniteMDP::Solver.new(FiniteMDP::HashModel.new(self.to_hash), discount)
  end

  #
  # Convert to hash for use with FiniteMDP models.
  #
  # @abstract
  #
  def to_hash
    raise NotImplementedError
  end
end
