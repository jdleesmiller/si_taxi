require 'test/si_taxi_helper'

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

  context "two station ring with one vehicle; max_queue=1" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a  = MDPModelA.new([[0,1],[1,0]], 1, od, 1)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
    end

    should "have same number of state-action pairs" do
      assert_equal @tm_a.rows.size, @tm_b.rows.size
    end

    should "have valid transition probabilities" do
      @m_a.check_transition_probabilities_sum
      @m_b.check_transition_probabilities_sum
      @tm_b.check_transition_probabilities_sum
    end

    should "have 12 feasible states" do
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
                    [1, 1, 1, 0, 1]], @hm_b.states.uniq.sort.map{|s| s.to_a}
    end

    should "cover action space" do
      assert_equal [[[0, 0], [0, 0]],  # do nothing 
                    [[0, 1], [0, 0]],  # move from 0 to 1 
                    [[0, 0], [1, 0]]], # move from 1 to 0
        @hm_b.states.map {|s| @hm_b.actions(s)}.flatten(1).uniq!
    end

  end

  context "two station ring with one vehicle; max_queue=2" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a = MDPModelA.new([[0,1],[1,0]], 1, od, 2)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
    end

    should "have 24 states" do
      # same as the MDPModelA model
      assert_equal 24, @hm_b.states.size
    end

    should "have same number of transitions" do
      assert_equal @tm_a.rows.size, @tm_b.rows.size
    end

    should "have valid transition matrix" do
      @m_b.check_transition_probabilities_sum
    end
  end

  context "two station ring with two vehicles" do
    setup do
      od = ODMatrixWrapper.new([[0,0.2],[0.3,0]])
      @m_a = MDPModelA.new([[0,1],[1,0]], 2, od, 1)
      @hm_a = FiniteMDP::HashModel.new(@m_a.to_hash)
      @tm_a = FiniteMDP::TableModel.from_model(@hm_a)
      @m_b  = MDPModelB.new(@m_a)
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      @tm_b = FiniteMDP::TableModel.from_model(@hm_b)
    end
    
    should "have valid transition matrix" do
      @m_a.check_transition_probabilities_sum
      @m_b.check_transition_probabilities_sum
    end

    should "have 25 states" do
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
                    [1, 1, 2, 0, 1, 1]], @hm_b.states.sort.map{|s| s.to_a}
    end

    should "do value iteration" do
      solver = @m_b.solver(0.95)
      assert solver.evaluate_policy >= 0
      assert_equal 25, solver.value.size
      solver.improve_policy
      assert_equal 25, solver.policy.size
    end
  end
end


