require 'si_taxi/test_helper'

class MDPTabularSarsaSolverTest < Test::Unit::TestCase
  include SiTaxi

  class FakeSarsaActor < SarsaActor
    def initialize solver, *actions
      super solver
      @actions = actions
    end

    attr_accessor :actions

    def select_action sa
      raise "fake sarsa actor out of actions" if @actions.empty?
      # don't have to look at sa; just update the solver's action
      solver.action = @actions.shift
    end
  end

  context "two station ring with one vehicle" do
    setup do
      @m = MDPSim.new
      @m.trip_time = [[0, 1], [1, 0]]
      @m.init
      @m.add_vehicles_in_turn 1
    end

    should "be ready to solve" do
      @s = TabularSarsaSolver.new(@m)
      @actor = FakeSarsaActor.new(@s, [[0,0],[0,0]])
      @s.actor = @actor
      @s.init

      # init calls select_action once, but it doesn't update the q function
      sa_0 = @s.state_action.dup
      assert_equal [0,0,1,0,0, 0,0,0,0], sa_0.to_a
      assert_equal 0, @s.q_size

      # look up q for a new (state, action) pair; should get default
      assert_equal 0, @s.lookup_q(sa_0) # the default value
      assert_equal -1, @s.lookup_q(IntVector.new([1,0,1,0,0, 0,0,0,0]))
      assert_equal -2, @s.lookup_q(IntVector.new([1,1,1,0,0, 0,0,0,0]))

      # don't yet know the value of any states, so policy is undefined
      assert_equal [[0,0,0,0], -SiTaxi.DOUBLE_MAX], @s.policy([1,0,1,0,0])

      @actor.actions << [[0,0],[0,0]]
      @s.tick [BWPax.new(0,1,1)]

      # the vehicle should now be on its way to 1 on an occupied trip
      sa_1 = @s.state_action.dup
      assert_equal [0,0,0,1,1, 0,0,0,0], sa_1.to_a

      # should have updated Q(s, a) for the initial state and the zero action;
      # both s and s' have zero queues, so our Q(s, a) estimate is zero
      assert_equal 1, @s.q_size
      assert_equal [[0,0,0,0], 0], @s.policy([0,0,1,0,0])

      # only one valid action now, because vehicle is in motion
      @actor.actions << [[0,0],[0,0]]
      @s.tick [BWPax.new(0,1,1)]

      # vehicle becomes idle at 1; request is queued at 0
      sa_2 = @s.state_action.dup
      assert_equal [1,0,0,1,0, 0,0,0,0], sa_2.to_a

      # should have updated the state in sa_1:
      # Q(s,a)   = Q([0,0,0,1,1],[0,0,0,0]) = 0  (not in table; default)
      # R(s,a)   = R([0,0,0,1,1],[0,0,0,0]) = 0
      # Q(s',a') = Q([1,0,0,1,0],[0,0,0,0]) = -1 (not in table; default)
      assert_equal 2, @s.q_size
      assert_equal [[0,0,0,0], 0], @s.policy([0,0,1,0,0])
      assert_equal [[0,0,0,0],-1], @s.policy([0,0,0,1,1])

      # for the next tick, set a non-unit discount factor
      @s.gamma = 0.9

      # we'll stay in the same state, which should update our Q(s,a) value;
      # it should start at -1 (the default)
      assert_equal -1, @s.lookup_q(IntVector.new([1,0,0,1,0, 0,0,0,0]))

      # try a different action for the tick after this one
      @actor.actions << [[0,0],[1,0]]
      @s.tick []

      # should stay in same state; action for next tick is now in sa
      sa_3 = @s.state_action.dup
      assert_equal [1,0,0,1,0, 0,0,1,0], sa_3.to_a

      # but we'll have updated Q(s,a):
      # Q(s,a)   = Q([1,0,0,1,0],[0,0,0,0]) = -1 (not in table; default)
      # R(s,a)   = R([1,0,0,1,0],[0,0,0,0]) = -1
      # Q(s',a') = Q([1,0,0,1,0],[0,0,1,0]) = -1 (not in table; default)
      assert_equal -1 + 1*(-1 + 0.9*-1 - -1),
        @s.lookup_q(IntVector.new([1,0,0,1,0, 0,0,0,0]))

      @actor.actions << [[0,0],[0,0]]
      @s.tick []

      sa_4 = @s.state_action.dup
      assert_equal [0,0,0,1,1, 0,0,0,0], sa_4.to_a

      # we will have updated [1,0,0,1,0, 0,0,1,0]:
      # Q(s,a)   = Q([1,0,0,1,0],[0,0,1,0]) = -1 (not in table; default)
      # R(s,a)   = R([1,0,0,1,0],[0,0,0,0]) = -1
      # Q(s',a') = Q([0,0,0,1,1],[0,0,0,0]) = -1 (in table from first tick)
      assert_equal -1 + 1*(-1 + 0.9*-1 - -1),
        @s.lookup_q(IntVector.new([1,0,0,1,0, 0,0,1,0]))
    end
  end
end

