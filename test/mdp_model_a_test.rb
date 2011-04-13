require 'test/si_taxi_helper'

class MDPModelATest < Test::Unit::TestCase
  include SiTaxi

  # shorthand
  def st *state_a
    MDPStateA.from_a(@m, state_a)
  end

  def pretty_print_transition_probabilities
    states = @m.states
    t = @m.transitions
    actions = t.keys.sort
    actions.each do |action|
      puts "action: #{action}"
      mat = states.map {|s0|
        if t[action].has_key?(s0)
          s0.inspect + "\t" +
          states.map {|s1|
            pr = t[action][s0][s1] if t[action][s0].has_key?(s1)
            if pr then "%.2f" % pr else '    ' end
          }.join(" ") + "\t" + ("%.2f" % t[action][s0].values.sum)
        else
          s0.inspect
        end
      }.join("\n")
      puts mat
    end
  end

  def check_transition_matrix
    # rows should sum to 1 if the action is valid
    @m.transitions.each do |state, actions|
      actions.each do |action, succ| 
        assert_in_delta 1, succ.values.sum, $delta
      end
    end
  end

  context "two station ring with one vehicle; max_queue=1" do
    setup do
      @m = MDPModelA.new([[0,1],[1,0]], 1,
                         ODMatrixWrapper.new([[0,0.2],[0.3,0]]), 1)

      # 16 possible states; 12 are feasible
      @feasible_states = [
         [0, 0, 0, 0],
        #[1, 0, 0, 0], # infeasible: pax at 0 and idle veh at 0
         [0, 1, 0, 0],
        #[1, 1, 0, 0], # infeasible: pax at 0 and idle veh at 0
         [0, 0, 1, 0],
         [1, 0, 1, 0],
        #[0, 1, 1, 0], # infeasible: pax at 1 and idle veh at 1
        #[1, 1, 1, 0], # infeasible: pax at 1 and idle veh at 1
         [0, 0, 0, 1],
         [1, 0, 0, 1],
         [0, 1, 0, 1],
         [1, 1, 0, 1],
         [0, 0, 1, 1],
         [1, 0, 1, 1],
         [0, 1, 1, 1],
         [1, 1, 1, 1]]
    end

    should "enumerate states" do
      assert_equal @feasible_states, @m.states.map(&:to_a)
    end

    should "enumerate actions" do
      actions = []
      @m.with_each_action do |action|
        actions << action
      end
      # only one vehicle and two destinations, so two actions
      assert_equal [[0], [1]], actions
    end

    should "enumerate actions for states" do
      # vehicle is idle, so we can move it
      assert_equal [[0], [1]], st(0, 0, 0, 0).actions
      assert_equal [[0], [1]], st(0, 1, 0, 0).actions
      assert_equal [[0], [1]], st(0, 0, 1, 0).actions
      assert_equal [[0], [1]], st(1, 0, 1, 0).actions

      # vehicle is not idle, so all we can do is preserve its destination
      assert_equal [[0]], st(0, 0, 0, 1).actions
      assert_equal [[0]], st(1, 0, 0, 1).actions
      assert_equal [[0]], st(0, 1, 0, 1).actions
      assert_equal [[0]], st(1, 1, 0, 1).actions
      assert_equal [[1]], st(0, 0, 1, 1).actions
      assert_equal [[1]], st(1, 0, 1, 1).actions
      assert_equal [[1]], st(0, 1, 1, 1).actions
      assert_equal [[1]], st(1, 1, 1, 1).actions
    end

    should "enumerate successor states" do
      assert_equal [
        [0, 0, 0, 0], #  no new pax
        [0, 0, 1, 1], #  1 pax at 0
        [1, 0, 1, 1], # >1 pax at 0
        [0, 1, 0, 0], #  1 pax at 1
        [0, 1, 1, 1], #  1 pax at 0, 1 pax at 1
        [1, 1, 1, 1], # >1 pax at 0, 1 pax at 1
        ], st(0,0,0,0).successors([0]).map(&:to_a) # keep vehicle at 0 

      assert_equal [
        [0, 0, 1, 1], # no new pax
        [1, 0, 1, 1], # >=1 pax at 0
        [0, 1, 1, 1], # >=1 pax at 1
        [1, 1, 1, 1], # >=1 pax at both 0 and 1
        ], st(0,0,0,0).successors([1]).map(&:to_a) # move vehicle to 1

      assert_equal [
        [0, 1, 0, 0], #  0 pax at 1 (stay at 0, even with a queue at 1)
        [0, 1, 1, 1], #  1 pax at 0 (vehicle goes full to 1)
        [1, 1, 1, 1], # >1 pax at 0 
        ], st(0,1,0,0).successors([0]).map(&:to_a) # keep idle at 0

      assert_equal [
        [0, 1, 1, 1], #   0 pax at 0
        [1, 1, 1, 1], # >=1 pax at 0 
        ], st(0,1,0,0).successors([1]).map(&:to_a) # move idle to 1

      assert_equal [
        [0, 0, 0, 1], # no new pax
        [1, 0, 0, 1], # >=1 pax at 0,   0 pax at 1
        [0, 1, 0, 1], # >=0 pax at 1,   0 pax at 0
        [1, 1, 0, 1], # >=1 pax at 0, >=1 pax at 1
        ], st(0,0,1,0).successors([0]).map(&:to_a) # move idle to 0

      assert_equal [
        [0, 0, 1, 0], # no new pax
        [1, 0, 1, 0], # >=1 pax at 0,   0 pax at 1
        [0, 0, 0, 1], #   0 pax at 0,   1 pax at 1
        [1, 0, 0, 1], # >=1 pax at 0,   1 pax at 1
        [0, 1, 0, 1], #   0 pax at 0, >=1 pax at 1
        [1, 1, 0, 1], # >=1 pax at 0, >=1 pax at 1
        ], st(0,0,1,0).successors([1]).map(&:to_a) # keep idle at 1

      assert_equal [
        [1, 0, 0, 1], #   0 pax at 1
        [1, 1, 0, 1], # >=1 pax at 1
        ], st(1,0,1,0).successors([0]).map(&:to_a) # move idle to 0

      assert_equal [
        [1, 0, 1, 0], # no new pax (keep idle at 1)
        [1, 0, 0, 1], #   1 pax at 1 
        [1, 1, 0, 1], # >=1 pax at 1
        ], st(1,0,1,0).successors([1]).map(&:to_a) # keep idle at 1
    end

    should "get valid transition matries" do
      tr = @m.transitions
      assert_equal 12, tr.size # 12 states
      assert_equal [0, 1], tr.map{|k,v| v.keys}.flatten.uniq # 2 actions

      # generic checks
      check_transition_matrix

      # dpois(0,0.2)*dpois(0,0.3) -- stay in state 0 if no new arrivals
      assert_in_delta 0.6065307, tr[st(0,0,0,0)][[0]][st(0,0,0,0)], $delta 

      # dpois(0,0.2)*dpois(0,0.3) -- no arrivals and move to 1
      assert_in_delta 0.6065307, tr[st(0,0,0,0)][[1]][st(0,0,1,1)], $delta 

      # dpois(0, 0.2) * (1-dpois(0, 0.3)) -- new arrival at 1
      assert_in_delta 0.2122001, tr[st(0,0,0,0)][[0]][st(0,1,0,0)]

      # new arrival at 0 forces us to move to 1
      assert_in_delta 0, tr[st(0,0,0,0)][[0]][st(1,0,0,0)], $delta
    end

    should "have non-positive rewards for states" do
      @m.with_each_state do |state|
        assert state.reward <= 0
      end
    end

    should "do value iteration" do
      solver = @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 12, solver.value.size
      solver.improve_policy
      assert_equal 12, solver.policy.size

      # only allowed actions should be in the policy
      assert solver.policy.all? {|s, a| s.eta == [0] || a == s.destin}
    end
  end

  context "two station ring with one vehicle; max_queue=2" do
    setup do
      @m = MDPModelA.new([[0,1],[1,0]], 1,
                         ODMatrixWrapper.new([[0,0.2],[0.3,0]]), 2)
    end

    should "have 24 states" do
      # 3*2 for when the vehicle is idle, and 3*3*2 when it is not
      assert_equal 24, @m.states.size
    end

    should "have valid transition matrix" do
      check_transition_matrix
    end

    should "do value iteration" do
      solver = @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 24, solver.value.size
      solver.improve_policy
      assert_equal 24, solver.policy.size

      # only allowed actions should be in the policy
      assert solver.policy.all? {|s, a| s.eta == [0] || a == s.destin}
    end
  end

  context "two station ring with one vehicle; distance 2; max_queue=2" do
    setup do
      @m = MDPModelA.new([[0,2],[1,0]], 1,
                         ODMatrixWrapper.new([[0,0.2],[0.3,0]]), 2)
    end

    should "have 33 states" do
      # 6 states for idle vehicles; 2*9 states when vehicle going from 0 to 1;
      # 9 states when vehicle going from 1 to 0 (travel time 1) 
      assert_equal 33, @m.states.size
    end

    should "have valid transition matrix" do
      check_transition_matrix
    end

    should "do value iteration" do
      solver = @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 33, solver.value.size
      solver.improve_policy
      assert_equal 33, solver.policy.size

      # only allowed actions should be in the policy
      assert solver.policy.all? {|s, a| s.eta == [0] || a == s.destin}
    end
  end

  context "two station ring with two vehicles" do
    setup do
      @m = MDPModelA.new([[0,1],[1,0]], 2,
                         ODMatrixWrapper.new([[0,0.2],[0.3,0]]), 1)
    end

    should "have valid transition matrix" do
      check_transition_matrix
    end

    should "do value iteration" do
      solver = @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 38, solver.value.size # 38 states
      solver.improve_policy
      assert_equal 38, solver.policy.size
    end
  end

  context "three station ring with one vehicle" do
    setup do
      @m = MDPModelA.new([[0,1,2],[2,0,1],[1,2,0]], 1,
        ODMatrixWrapper.new([[0,0.1,0.2],[0.1,0,0.2],[0.1,0.2,0]]), 1)
    end

    should "have valid transition matrix" do
      check_transition_matrix
    end

    should "do value iteration" do
      solver = @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 60, solver.value.size # 60 states
      solver.improve_policy
      assert_equal 60, solver.policy.size
    end
  end

  context "two station ring with zero demand from one station" do
    setup do
      @m = MDPModelA.new([[0,1],[1,0]], 1,
                         ODMatrixWrapper.new([[0,0.0],[0.1,0]]), 1)
    end

    should "have 7 states" do
      # five states infeasible because they have non-zero queues at 0
      assert_equal [[0, 0, 0, 0],
                    [0, 1, 0, 0],
                    [0, 0, 1, 0],
                    [0, 0, 0, 1],
                    [0, 1, 0, 1],
                    [0, 0, 1, 1],
                    [0, 1, 1, 1]], @m.states.map(&:to_a)
    end

    should "have valid transition matrix" do
      check_transition_matrix
    end

    should "do value iteration" do
      solver= @m.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 7, solver.value.size
      solver.improve_policy
      assert_equal 7, solver.policy.size
    end
  end
end

