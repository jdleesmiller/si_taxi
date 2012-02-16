require 'si_taxi/test_helper'

class MDPModelCTest < Test::Unit::TestCase
  include TestHelper
  include SiTaxi

  context "two station ring, unit trip times, one vehicle, queue_max=1" do
    setup do
      @model  = MDPModelC.new([[0,1],[1,0]], 1, [[0,0.1],[0.1,0]], 1)
      @hash_model = FiniteMDP::HashModel.from_model(@model)
      @table_model = FiniteMDP::TableModel.from_model(@model)
    end

    should "be valid" do
      @model.check_transition_probabilities_sum
      @hash_model.check_transition_probabilities_sum
      @table_model.check_transition_probabilities_sum
      assert_equal [], @model.terminal_states.to_a
      assert_equal [], @hash_model.terminal_states.to_a
      assert_equal [], @table_model.terminal_states.to_a

      # note: states marked with a * have both an idle vehicle and a queued
      # request, but the action space is restricted so that the idle vehicle is
      # reserved for the request on the next tick
      states = @model.states
      assert_equal [
        '[  0  0  ||0]', # no queues; veh at 1
        '[  0  0  |0|]', # no queues; veh at 0
        '[  1  0  ||0]', # one pax at 0; veh at 0
        '[  1  0  |0|]', # one pax at 0; veh at 0 *
        '[  0  1  ||0]', # one pax at 1; veh at 1 *
        '[  0  1  |0|]', # one pax at 1; veh at 0
        '[  1  1  ||0]',                        # *
        '[  1  1  |0|]'], states.map(&:inspect) # *

      # six successor states: the two that can't occur are:
      # [  0  1  ||0] 
      # [  1  1  ||0]
      # which both require new pax at 1 without the vehicle moving.
      nop = NArray[[0,0],[0,0]]
      state_0_succ = @model.next_states(states[0], nop)
      assert_equal [
        '[  0  0  ||0]', # nothing happened
        '[  1  0  ||0]', # new pax at 0
        '[  0  0  |0|]', # new pax at 1 (veh moves to 0)
        '[  1  0  |0|]', # new pax at 1 (veh moves to 0) and new pax at 0
        '[  0  1  |0|]', # two new pax at 0
        '[  1  1  |0|]'], state_0_succ.map(&:inspect)

      # probability of staying in same state is Poisson(0,0.1)^2, since we
      # require zero arrivals at both stations
      assert_close 0.818730753,
        @model.transition_probability(states[0], nop, state_0_succ[0])
    end
  end

  context "two station ring, non-unit trip times, one vehicle, queue_max=1" do
    setup do
      @model  = MDPModelC.new([[0,2],[2,0]], 1, [[0,0.2],[0.3,0]], 1)
      @table_model = FiniteMDP::TableModel.from_model(@model)
    end

    should "be valid" do
      @model.check_transition_probabilities_sum
      @table_model.check_transition_probabilities_sum
      assert_equal [], @model.terminal_states.to_a
      assert_equal [], @table_model.terminal_states.to_a

      # 16 states: two for each of the 8 in the unit trip time case
      assert_equal [
        '[  0  0  ||0]',
        '[  0  0  ||1]',
        '[  0  0  |0|]',
        '[  0  0  |1|]',
        '[  1  0  ||0]',
        '[  1  0  ||1]',
        '[  1  0  |0|]',
        '[  1  0  |1|]',
        '[  0  1  ||0]',
        '[  0  1  ||1]',
        '[  0  1  |0|]',
        '[  0  1  |1|]',
        '[  1  1  ||0]',
        '[  1  1  ||1]',
        '[  1  1  |0|]',
        '[  1  1  |1|]'], @model.states.map(&:inspect)
    end
  end

  context "two station ring, non-unit trip times, two vehicles, queue_max=2" do
    setup do
      @model  = MDPModelC.new([[0,2],[2,0]], 2, [[0,0.2],[0.3,0]], 2)
    end

    should "be valid" do
      @model.check_transition_probabilities_sum
      assert_equal [], @model.terminal_states.to_a
      assert_equal 90, @model.states.size
    end
  end

  context "two station ring tidal demand and two vehicles" do
    setup do
      @model = MDPModelC.new([[0,2],[2,0]], 2, [[0,0.0],[0.1,0]], 1)
    end

    should "be valid" do
      @model.check_transition_probabilities_sum
      assert_equal [], @model.terminal_states.to_a

      assert @model.states.all? {|s| s.queue[0] == 0}
    end
  end

  context "three station star with one vehicle" do
    setup do
      demand = [[  0,0.1,0.1],
                [0.1,  0,0.1],
                [0.1,0.1,  0]]
      @model = MDPModelC.new(TRIP_TIMES_3ST_STAR_2_2_3_3, 1, demand, 1)
      @hash_model = FiniteMDP::HashModel.from_model(@model)
    end

    should "be valid" do
      @hash_model.check_transition_probabilities_sum
      assert_equal [], @hash_model.terminal_states.to_a
    end
  end
end

