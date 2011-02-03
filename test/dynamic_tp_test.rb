require 'test/si_taxi_helper'

class DynamicTransportationProblemTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "two station ring (10, 20)" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_10_20
      @rea = BWNNHandler.new(@sim)
      @pro = BWDynamicTransportationProblemHandler.new(@sim)
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "have defaults set" do
      assert_equal [0, 0], @pro.targets.to_a
    end

    should "handle tidal flow" do
      @pro.targets[0] = 2
      @pro.targets[1] = 0

      put_veh_at 0, 0
      pax         0,  1,   0 
      assert_veh  0,  1,  10
      pax         0,  1,   5
      assert_veh  0,  1,  15
      pax         0,  1,  20
      assert_veh  0,  1,  40 # depart at 30s, because it went to 0 proactively
      pax         0,  1,  25
      assert_veh  0,  1,  45 # depart at 35s, because it went to 0 proactively

      assert_wait_hists({0 => 2, 10 => 2}, {})
    end
  end

  context "on three station ring (10s, 20s, 30s)" do
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @rea = BWNNHandler.new(@sim)
      @pro = BWDynamicTransportationProblemHandler.new(@sim)
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "move proactively" do
      put_veh_at 0, 0, 0, 0
      @pro.targets[0] = 2
      @pro.targets[1] = 0
      @pro.targets[2] = 2

      @sim.strobe = 1
      @sim.run_to 1

      assert_veh  0,  2,  30, 0
      assert_veh  0,  2,  30, 1
      assert_veh  0,  0,   0, 2
      assert_veh  0,  0,   0, 3
    end

    should "move proactively when targets are low" do
      put_veh_at 0, 0, 0, 0
      @pro.targets[0] = 0
      @pro.targets[1] = 0
      @pro.targets[2] = 2

      @sim.strobe = 1
      @sim.run_to 1

      assert_veh  0,  2,  30, 0
      assert_veh  0,  2,  30, 1
      assert_veh  0,  0,   0, 2
      assert_veh  0,  0,   0, 3
    end
  end
end
