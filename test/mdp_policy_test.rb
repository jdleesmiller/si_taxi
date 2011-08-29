require 'test/si_taxi_helper'


class MDPPolicyTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "MDP policy on two-station ring with one vehicle; ~ tidal 1 to 0" do
    setup do
      times = [[0,1],[1,0]] # unit travel times

      # create MDP model
      od = ODMatrixWrapper.new([[0,0.1],[0.9,0]])
      @m_b = MDPModelB.new_from_scratch(times, 1, od, 1)

      # solve MDP model -- might as well use optimal policy for testing
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      discount = 0.99
      max_iters = 5
      solver = FiniteMDP::Solver.new(@hm_b, discount)
      raise "solve failed" unless solver.policy_iteration_exact(max_iters)

      setup_sim times
      @rea = BWNNHandler.new(@sim)
      @pro = BWMDPModelBHandler.new(@sim, @m_b, solver.policy)
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
    end

    should "move idle vehicles according to policy" do
      put_veh_at 0

      # handle first request at 0; vehicle left idle at 1
      pax         0,  1,   0
      assert_veh  0,  1,   1

      # handle a second request at 0; vehicle has to make a round trip
      pax         0,  1,   1
      assert_veh  0,  1,   3

      # request from 1 to 0; vehicle doesn't initially move back to 1, because
      # we can only send it a new trip when it becomes idle
      pax         1,  0,   4
      assert_veh  1,  0,   5

      @sim.run_to 6
      assert_veh  0,  1,   6

      # try two requests in the same timestep; the ETA for the vehicle (now
      # inbound to 1) is > the max travel time, so we should truncate it
      pax         0,  1,   8
      pax         0,  1,   8
      assert_veh  0,  1,  12 # two round trips now scheduled
      assert_equal 2, @sim_stats.queue_at(0)
      assert_equal [0, 0, 0, 1, 1], @pro.current_state.to_a

      # this generates one handle_idle call, and it leaves the vehicle at 1
      @sim.run_to 13
      assert_veh  0,  1,  12
    end
  end

  context "MDP policy on two-station ring with two vehicles; ~ tidal 0 to 1" do
    setup do
      times = [[0,1],[1,0]] # unit travel times

      # create MDP model
      od = ODMatrixWrapper.new([[0,0.9],[0.1,0]])
      @m_b = MDPModelB.new_from_scratch(times, 2, od, 1)

      # solve MDP model -- might as well use optimal policy for testing
      @hm_b = FiniteMDP::HashModel.new(@m_b.to_hash)
      discount = 0.99
      max_iters = 5
      solver = FiniteMDP::Solver.new(@hm_b, discount)
      raise "solve failed" unless solver.policy_iteration_exact(max_iters)

      setup_sim times
      @rea = BWNNHandler.new(@sim)
      @pro = BWMDPModelBHandler.new(@sim, @m_b, solver.policy)
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
    end

    should "move idle vehicles according to policy" do
      put_veh_at 0, 1
      assert_equal [0, 0, 1, 1, 0, 0], @pro.current_state.to_a

      # request from 0 to 1; policy is to move the other vehicle from 1 to 0
      pax         0,  1,   0
      assert_veh  0,  1,   1
      assert_veh  1,  0,   1
      assert_equal [0, 0, 1, 1, 1, 1], @pro.current_state.to_a

      # both vehicles become idle at t=1; we want them both at 0
      @sim.run_to 2
      assert_veh  1,  0,   1
      assert_veh  1,  0,   2
      assert_equal [0, 0, 2, 0, 0, 0], @pro.current_state.to_a

      # two requests at 1; no empty vehicle movements required
      pax         1,  0,   4
      assert_equal [0, 0, 2, 0, 0, 1], @pro.current_state.to_a
      pax         1,  0,   4
      assert_veh  1,  0,   6, 0
      assert_veh  1,  0,   6, 1
      assert_equal [0, 0, 2, 0, 1, 1], @pro.current_state.to_a

      # both vehicles become idle at 0; no further movements
      @sim.run_to 7
      assert_equal [0, 0, 2, 0, 0, 0], @pro.current_state.to_a
    end
  end
end
