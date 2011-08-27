require 'test/si_taxi_helper'

class MDPPolicyTest < Test::Unit::TestCase
  include BellWongTestHelper

  should "work" do
    setup_sim TRIP_TIMES_2ST_RING_10_20
    @rea = BWNNHandler.new(@sim)
    @pro = BWMDPPolicyHandler.new(@sim)
    @pro.set_policy [0,0],[1,0],[0],[[0,0],[0,0]]
    @sim.reactive = @rea
    @sim.proactive = @pro
    @sim.init
  end
end
