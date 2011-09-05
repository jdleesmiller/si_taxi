require 'si_taxi/test_helper'

# TODO maybe add to gem
module FiniteMDP::Model
  def transition_probability_sums tol=1e-6
    prs = []
    states.each do |state|
      actions(state).each do |action|
        pr = next_states(state, action).map{|next_state|
          transition_probability(state, action, next_state)}.inject(:+)
        prs << [state, action, pr]
      end
    end
    prs
  end
end

class MDPModelBTest < Test::Unit::TestCase
  include SiTaxi

  context "models on two station ring with one vehicle; max_queue=1" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a  = MDPModelA.new([[0,1],[1,0]], 1, od, 1)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new_from_model_a(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
      @m_b_scratch  = MDPModelB.new_from_scratch([[0,1],[1,0]], 1, od, 1)
      @hm_b_scratch = FiniteMDP::HashModel.new(@m_b_scratch.to_hash)
      @tm_b_scratch = FiniteMDP::TableModel.from_model(@hm_b_scratch)
    end

    should "match up" do
      # only one vehicle: same number of transitions in all models
      assert_equal @tm_a.rows.size, @tm_b.rows.size
      assert_equal @tm_a.rows.size, @tm_b_scratch.rows.size

      # should all be valid
      @m_a.check_transition_probabilities_sum
      @m_b.check_transition_probabilities_sum
      @m_b_scratch.check_transition_probabilities_sum
      @tm_b.check_transition_probabilities_sum

      # the model B's should both have same states and actions
      for model in [@hm_b, @hm_b_scratch]
        assert_equal [[0, 0, 0, 1, 0], # idle at 1
                      [0, 0, 0, 1, 1], # going to 1
                      [0, 0, 1, 0, 0], # idle at 0
                      [0, 0, 1, 0, 1], # going to 0
                      [0, 1, 0, 1, 1],
                      [0, 1, 1, 0, 0],
                      [0, 1, 1, 0, 1],
                      [1, 0, 0, 1, 0],
                      [1, 0, 0, 1, 1],
                      [1, 0, 1, 0, 1],
                      [1, 1, 0, 1, 1],
                      [1, 1, 1, 0, 1]], model.states.map(&:to_a).sort!

        assert_equal [[[0, 0], [0, 0]],  # do nothing 
                      [[0, 0], [1, 0]],  # move from 0 to 1 
                      [[0, 1], [0, 0]]], # move from 1 to 0
          model.states.map {|s| model.actions(s)}.flatten(1).sort!.uniq
      end

      # should get same rows for both B models
      assert_equal Set[*@tm_b.rows], Set[*@tm_b_scratch.rows]
    end
  end

  context "models on the two station ring with one vehicle; max_queue=2" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a  = MDPModelA.new([[0,1],[1,0]], 1, od, 2)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new_from_model_a(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
      @m_b_scratch  = MDPModelB.new_from_scratch([[0,1],[1,0]], 1, od, 2)
      @hm_b_scratch = FiniteMDP::HashModel.new(@m_b_scratch.to_hash)
      @tm_b_scratch = FiniteMDP::TableModel.from_model(@hm_b_scratch)
    end

    should "match up" do
      # one vehicle, so should have same number of states as MDPModelA model
      assert_equal 24, @hm_a.states.size
      assert_equal 24, @hm_b.states.size
      assert_equal 24, @hm_b_scratch.states.size
      
      # and the same number of transitions
      assert_equal @tm_a.rows.size, @tm_b.rows.size
      assert_equal @tm_a.rows.size, @tm_b_scratch.rows.size

      # states from_scratch should match from_a 
      assert_equal Set[*@hm_b.states], Set[*@hm_b_scratch.states]

      # should all be valid
      @m_b.check_transition_probabilities_sum
      @m_b_scratch.check_transition_probabilities_sum

      # should get same rows for both B models
      assert_equal Set[*@tm_b.rows], Set[*@tm_b_scratch.rows]
    end
  end

  context "models for two station ring with two vehicles" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a = MDPModelA.new([[0,1],[1,0]], 2, od, 1)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new_from_model_a(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
      @m_b_scratch  = MDPModelB.new_from_scratch([[0,1],[1,0]], 2, od, 1)
      @hm_b_scratch = FiniteMDP::HashModel.new(@m_b_scratch.to_hash)
      @tm_b_scratch = FiniteMDP::TableModel.from_model(@hm_b_scratch)
    end
    
    should "match up" do
      # should all be valid
      @m_a.check_transition_probabilities_sum
      @m_b.check_transition_probabilities_sum
      @m_b_scratch.check_transition_probabilities_sum

      # should get same states for the B models
      for model in [@hm_b, @hm_b_scratch]
        assert_equal [[0, 0, 0, 2, 0, 0],
                      [0, 0, 0, 2, 0, 1],
                      [0, 0, 0, 2, 1, 1],
                      [0, 0, 1, 1, 0, 0],
                      [0, 0, 1, 1, 0, 1],
                      [0, 0, 1, 1, 1, 0],
                      [0, 0, 1, 1, 1, 1],
                      [0, 0, 2, 0, 0, 0],
                      [0, 0, 2, 0, 0, 1],
                      [0, 0, 2, 0, 1, 1],
                      [0, 1, 0, 2, 1, 1],
                      [0, 1, 1, 1, 0, 1],
                      [0, 1, 1, 1, 1, 1],
                      [0, 1, 2, 0, 0, 0],
                      [0, 1, 2, 0, 0, 1],
                      [0, 1, 2, 0, 1, 1],
                      [1, 0, 0, 2, 0, 0],
                      [1, 0, 0, 2, 0, 1],
                      [1, 0, 0, 2, 1, 1],
                      [1, 0, 1, 1, 1, 0],
                      [1, 0, 1, 1, 1, 1],
                      [1, 0, 2, 0, 1, 1],
                      [1, 1, 0, 2, 1, 1],
                      [1, 1, 1, 1, 1, 1],
                      [1, 1, 2, 0, 1, 1]], model.states.map(&:to_a).sort!
      end

      # should be able to solve either one
      solver = @m_b.solver(0.95)
      assert solver.evaluate_policy >= 0
      solver.improve_policy
    end
  end

  context "building model from scratch" do
    context "two station ring with one vehicle; max_queue=1" do
      setup do
        od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
        @m_b  = MDPModelB.new_from_scratch([[0,1],[1,0]], 1, od, 1)
      end

      should "create new states" do
        s = MDPStateB.new(@m_b)

        # not valid when first constructed in this way 
        assert_equal [], s.inbound

        # can make it valid by adding some vehicles in
        s.inbound[0] = [0]
        s.inbound[1] = []
        assert_equal [1,0], s.num_inbound
        assert_equal [1,0], s.idle
      end
    end

    context "two station ring with two vehicles; max_queue=1" do
      setup do
        od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
        @m_b  = MDPModelB.new_from_scratch([[0,1],[1,0]], 2, od, 1)
      end

      should "count idle vehicles in state" do
        s = MDPStateB.new(@m_b)

        # initial state is invalid: no inbound vehicles
        assert_equal [], s.inbound

        # make inbound feasible; should get one idle vehicles at each station
        s.inbound[0] = [0]
        s.inbound[1] = [0]
        assert s.feasible?
        assert_equal [1,1], s.idle

        # set one vehicle to move to 1; the other remains idle at 0
        s.inbound[1][0] = 1
        assert_equal [1,0], s.idle

        # try with no idle vehicles
        s.inbound[0][0] = 1
        assert_equal [0,0], s.idle

        # try the final permutation
        s.inbound[1][0] = 0
        assert_equal [0,1], s.idle
      end
    end
  end
end

