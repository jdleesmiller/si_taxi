require 'si_taxi/test_helper'

class MDPModelBTest < Test::Unit::TestCase
  include SiTaxi

  context "models on the two station ring with one vehicle; max_queue=2" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a  = MDPModelA.new([[0,1],[1,0]], 1, od, 2)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b_scratch  = MDPModelB.new([[0,1],[1,0]], 1, od, 2)
      @hm_b_scratch = FiniteMDP::HashModel.new(@m_b_scratch.to_hash)
      @tm_b_scratch = FiniteMDP::TableModel.from_model(@hm_b_scratch)
    end

    should "match up" do
      # should be valid
      @m_b_scratch.check_transition_probabilities_sum

      # one vehicle, so should have same number of states as MDPModelA model
      assert_equal 24, @hm_a.states.size
      assert_equal 24, @hm_b_scratch.states.size
    end
  end

  context "models for two station ring with two vehicles" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a = MDPModelA.new([[0,1],[1,0]], 2, od, 1)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b_scratch  = MDPModelB.new([[0,1],[1,0]], 2, od, 1)
      @hm_b_scratch = FiniteMDP::HashModel.new(@m_b_scratch.to_hash)
      @tm_b_scratch = FiniteMDP::TableModel.from_model(@hm_b_scratch)
    end
    
    should "match up" do
      # should all be valid
      @m_a.check_transition_probabilities_sum
      @m_b_scratch.check_transition_probabilities_sum

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
                    [1, 1, 2, 0, 1, 1]], @hm_b_scratch.states.map(&:to_a).sort!

      # should be able to solve it
      solver = @m_b_scratch.solver(0.95)
      assert solver.evaluate_policy >= 0
      solver.improve_policy
    end
  end

  context "building model from scratch" do
    context "two station ring with one vehicle; max_queue=1" do
      setup do
        od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
        @m_b = MDPModelB.new([[0,1],[1,0]], 1, od, 1)
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
        @m_b  = MDPModelB.new([[0,1],[1,0]], 2, od, 1)
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

