require 'test/si_taxi_helper'

class AndreassonTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "two station ring (10, 20)" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_10_20
      @ct = BWCallTimeTracker.new(@sim)
      @rea = BWNNHandlerWithCallTimeUpdates.new(@sim, @ct)
      @pro = BWAndreassonHandler.new(@sim, @ct, [[  0, 120.0/3600], # veh / sec
                                                 [  0,   0]])
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "have defaults set" do
      assert_equal [0, 0], @pro.targets.to_a
      assert_equal [[false, false], [false, false]], @pro.preferred
    end

    should "update call times (trivial here)" do
      # initialized to shortest trip times
      assert_equal 0, @pro.call_time.call[0]
      assert_equal 0, @pro.call_time.call[1]
      assert_in_delta 20, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta

      put_veh_at 0 
      pax         0,  1,   0
      assert_veh  0,  1,  10

      # should not count the zero trip
      assert_equal 0, @pro.call_time.call[0]
      assert_equal 0, @pro.call_time.call[1]
      assert_in_delta 20, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta

      pax         0,  1,   5
      assert_veh  0,  1,  40

      # should count the 10 (no change in result, but ++ number of calls)
      assert_equal 1, @pro.call_time.call[0]
      assert_equal 0, @pro.call_time.call[1]
      assert_in_delta 20, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta
    end

    should "count inbound vehicles" do
      put_veh_at 0 

      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(1)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(1)

      pax         0,  1,   0
      assert_veh  0,  1,  10

      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(1)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(1)

      pax         0,  1,   5
      assert_veh  0,  1,  40

      # vehicle is not yet immediately inbound, and it's outside the call time
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(1)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(1)
    end

    should "compute demand" do
      @pro.use_call_times_for_targets = true
      assert_in_delta 20.0*(120.0/3600.0), @pro.demand_at(0), $delta
      assert_in_delta 0, @pro.demand_at(1), $delta # no outbound demand
    end

    should "compute supply" do
      put_veh_at 0 

      # the immediate and call time constraints don't matter here
      [true, false].each do |b1|
        @pro.immediate_inbound_only = b1
        [true, false].each do |b2|
          @pro.use_call_times_for_inbound = b2
          assert_in_delta 1, @pro.supply_at(0), $delta
          assert_in_delta 0, @pro.supply_at(1), $delta
        end
      end
    end

    should "find call origins" do
      put_veh_at 0 

      # no supply and no demand at station 1
      assert_equal 1, @pro.find_call_origin(0, 0) 
      assert_equal SiTaxi.SIZE_T_MAX, @pro.find_call_origin(0, 1) 

      # supply 1 and some demand at station 0
      assert_equal 0, @pro.find_call_origin(1, 0.1) 
      assert_equal SiTaxi.SIZE_T_MAX, @pro.find_call_origin(1, 1) 
    end

    should "find send destinations" do
      put_veh_at 0 

      # neither station has a deficit
      assert_equal SiTaxi.SIZE_T_MAX, @pro.find_send_destin(0)
      assert_equal SiTaxi.SIZE_T_MAX, @pro.find_send_destin(1)

      pax         0,  1,   0
      assert_veh  0,  1,  10

      # now station 0 has a deficit
      assert_equal SiTaxi.SIZE_T_MAX, @pro.find_send_destin(0)
      assert_equal 0, @pro.find_send_destin(1)
    end
  end

  context "on three station ring (10s, 20s, 30s)" do
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @ct = BWCallTimeTracker.new(@sim)
      @rea = BWNNHandlerWithCallTimeUpdates.new(@sim, @ct)
      @pro = BWAndreassonHandler.new(@sim, @ct,
                                     [[  0, 120.0/3600, 0], # veh / sec
                                      [  0,          0, 0],
                                      [  0,          0, 0]])
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "have defaults set" do
      assert_equal [0, 0, 0], @pro.targets.to_a
      assert_equal [[false, false, false],
                    [false, false, false],
                    [false, false, false]], @pro.preferred
    end

    should "update call times (trivial here)" do
      # initialized to shortest trip times
      assert_equal [0, 0, 0], @pro.call_time.call.to_a
      assert_in_delta 30, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta
      assert_in_delta 20, @pro.call_time.at(2), $delta

      put_veh_at 0 
      pax         0,  1,   0
      assert_veh  0,  1,  10

      # should not count the zero trip
      assert_equal [0, 0, 0], @pro.call_time.call.to_a
      assert_in_delta 30, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta
      assert_in_delta 20, @pro.call_time.at(2), $delta

      pax         0,  1,   5
      assert_veh  0,  1,  70 # pickup at 60s + 10s trip
      assert_wait_hists({0 => 1, 55 => 1}, [], [])
    end
  end
end

