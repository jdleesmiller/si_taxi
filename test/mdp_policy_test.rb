require 'test/si_taxi_helper'

module SiTaxi
  class TestHandler < BWProactiveHandler
    def initialize sim, detailed_stats
      super(sim)
      @detailed_stats = detailed_stats
    end

    def init
      puts sim
      puts "test init"
    end

    def handle_pax_served empty_origin
      puts "handle_pax_served eo=#{empty_origin}"
      p current_state
    end

    def handle_idle veh
      puts "handle_idle #{veh.inspect}"
      p current_state
    end

    def current_state
      [@detailed_stats.queue_at(0),@detailed_stats.queue_at(1)]
    end
  end
end

class MDPPolicyTest < Test::Unit::TestCase
  include BellWongTestHelper

  should "work" do
    setup_sim TRIP_TIMES_2ST_RING_10_20
    @rea = BWNNHandler.new(@sim)
    @pro = TestHandler.new(@sim, @sim_stats)
    #@pro = BWMDPPolicyHandler.new(@sim)
    #@pro.set_policy BWMDPPolicyState.new([0,0],[1,0],[0]),[[0,0],[0,0]]
    @sim.reactive = @rea
    @sim.proactive = @pro
    @sim.init

    put_veh_at 0, 1
    pax         0,  1,   0
    pax         1,  0,   0 # try with pax at same time, diff. stations
    pax         0,  1,   1
    pax         1,  0,   1
    @sim.run_to 100
  end
end
