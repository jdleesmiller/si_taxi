require 'test/si_taxi_helper'


class MDPPolicyTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "two-station ring with one vehicle; nearly tidal from 1 to 0" do
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
      unless solver.policy_iteration_exact(max_iters) {|num_iters|
        $stderr.puts "iters=%4d" % num_iters if num_iters % 2 == 0}
        $stderr.puts "NO STABLE POLICY OBTAINED"
      end

      setup_sim times
      @rea = BWNNHandler.new(@sim)
      @pro = BWMDPModelBHandler.new(@sim, @sim_stats, @m_b, solver.policy)
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
    end

    should "move vehicles according to policy" do
      put_veh_at 0

      # handle first request at 0; vehicle left idle at 1
      pax         0,  1,   0
      assert_veh  0,  1,   1

      pax         1,  0,   0 # try with pax at same time, diff. stations
      pax         0,  1,   1
      pax         1,  0,   1
      @sim.run_to 10

      ## no queued requests; one vehicle at station 0
      #assert_equal [0, 0, 1, 0, 0], @pro.current_state.to_a

      ## have to use custom sim driver to put passengers in
      #pax_stream = BWTestPaxStream.new
      ##                             origin, destin, arrive
      #pax_stream.pax.push BWPax.new(     0,      1,      0) 
      #pax_stream.pax.push BWPax.new(     0,      1,      2) # gets thrown away
      #pax_stream.pax.push BWPax.new(     0,      1,      2) 
      #pax_stream.pax.push BWPax.new(     0,      1,      3) # gets thrown away
      #pax_stream.pax.push BWPax.new(     1,      0,      5)
      #pax_stream.pax.push BWPax.new(     1,      0,      6) # gets thrown away
      #pax_stream.pax.push BWPax.new(     1,      0,      8) 
      #pax_stream.pax.push BWPax.new(     1,      0,      8) 
      #pax_stream.pax.push BWPax.new(     1,      0,      9) # gets thrown away

      ## handle first request at 0; vehicle left idle at 1
      #@pro.handle_pax_stream pax_stream, 1
      #assert_equal 1, @sim.now             # have to finish timestep 0
      #assert_equal [0, 0, 0, 1, 0], @pro.current_state.to_a

      ## handle second request at 0; vehicle was idle at 1, so it takes two time
      ## steps to finish serving this passenger
      #@pro.handle_pax_stream pax_stream, 1
      #assert_equal 3, @sim.now             # have to finish timestep 2
      #assert_equal [1, 0, 0, 1, 1], @pro.current_state.to_a

      ## handle first request at 1; vehicle was idle at 1, so there's no delay;
      ## the vehicle moves back to 1 (after the pax_served event)
      #@pro.handle_pax_stream pax_stream, 1
      #assert_equal 6, @sim.now             # have to finish timestep 5
      #assert_equal [0, 0, 0, 1, 1], @pro.current_state.to_a

      ## handle the next two requests at 1; they happen in the same time step
      #@pro.handle_pax_stream pax_stream, 1
      #p @sim.now
      #p @pro.current_state

    end
  end
end
