require 'test/si_taxi_helper'

class MDPModelATest < Test::Unit::TestCase
  include SiTaxi

  context "two station ring with one vehicle" do
    setup do
      @m = MDPModelA.new([[0,1],[1,0]], 1,
                         ODMatrixWrapper.new([[0,0.2],[0.3,0]]), 1)
    end

    should "enumerator states" do
      states = []
      @m.with_each_state do |state|
        states << state
      end
      # get 16 states, of which 12 are feasible
      assert_equal [
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
         [1, 1, 1, 1]], states.map(&:to_a)
    end

    should "enumerate actions" do
      actions = []
      @m.with_each_action do |action|
        actions << action
      end
      # only one vehicle and two destinations, so two actions
      assert_equal [[0], [1]], actions
    end

    def actions_for state_a
      actions = []
      state = MDPStateA.from_a(@m, state_a)
      @m.with_each_action_for(state) do |action| actions << action end
      actions
    end

    should "enumerate actions for states" do
      # vehicle is idle, so we can move it
      assert_equal [[0], [1]], actions_for([0, 0, 0, 0])
      assert_equal [[0], [1]], actions_for([0, 1, 0, 0])
      assert_equal [[0], [1]], actions_for([0, 0, 1, 0])
      assert_equal [[0], [1]], actions_for([1, 0, 1, 0])

      # vehicle is not idle, so all we can do is preserve its destination
      assert_equal [[0]], actions_for([0, 0, 0, 1])
      assert_equal [[0]], actions_for([1, 0, 0, 1])
      assert_equal [[0]], actions_for([0, 1, 0, 1])
      assert_equal [[0]], actions_for([1, 1, 0, 1])
      assert_equal [[1]], actions_for([0, 0, 1, 1])
      assert_equal [[1]], actions_for([1, 0, 1, 1])
      assert_equal [[1]], actions_for([0, 1, 1, 1])
      assert_equal [[1]], actions_for([1, 1, 1, 1])
    end

    def successors_for state_a, action
      states = []
      state = MDPStateA.from_a(@m, state_a)
      @m.with_each_successor_state(state, action) do |ss, pr| states << ss end
      states
    end

    def transition_probabilities
      res = {}
      @m.with_each_action do |a|
        mat = {}
        @m.with_each_state do |s0|
          if actions_for(s0.to_a).member?(a) 
            mat_row = {}
            @m.with_each_successor_state(s0, a) do |s1, pr|
              raise "got transition #{s0} -> #{s1} twice" if mat_row[s1]
              mat_row[s1] = pr
            end
            mat[s0] = mat_row
          end
        end
        res[a] = mat
      end
      res
    end

    def pretty_print_transition_probabilities t
      actions = t.keys.sort
      actions.each do |action|
        puts "action: #{action}"
        states = t[action].keys.sort
        p states
        mat = states.map {|s0| t[action][s0]}
        p mat
      end
    end

    should "enumerate successor states" do
      assert_equal [
        [0, 0, 0, 0],
        [0, 0, 1, 1], # 1 pax at 0
        [1, 0, 1, 1], # 2 pax at 0
        [0, 1, 0, 0], # 1 pax at 1
        [0, 1, 1, 1], # 1 pax at 0, 1 pax at 1
        [1, 1, 1, 1], # 2 pax at 0, 1 pax at 1
        ], successors_for([0,0,0,0], [0]).map(&:to_a)
#      p successors_for([0,0,0,0], [1])
#      puts "0100"
#      p successors_for([0,1,0,0], [0])
#      p successors_for([0,1,0,0], [1])
#      puts "0010"
#      p successors_for([0,0,1,0], [0])
#      p successors_for([0,0,1,0], [1])
#      puts "1010"
#      p successors_for([1,0,1,0], [0])
#      p successors_for([1,0,1,0], [1])
    end

    should "get valid transition probability matrix" do
      pretty_print_transition_probabilities(transition_probabilities)
    end
  end
end

