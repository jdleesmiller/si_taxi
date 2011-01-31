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

      # should count a non-trivial trip (empty from 1 to 0, which takes 50s)
      pax         0,  1,   5
      assert_veh  0,  1,  70 # pickup at 60s + 10s trip
      assert_wait_hists({0 => 1, 55 => 1}, [], [])

      assert_equal [1, 0, 0], @pro.call_time.call.to_a
      assert_in_delta 50, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta
      assert_in_delta 20, @pro.call_time.at(2), $delta
    end

    should "count inbound vehicles" do
      put_veh_at 0

      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(1)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(1)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(2)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(2)

      assert_equal 30, @pro.call_time.at(0), $delta
      assert_equal 10, @pro.call_time.at(1), $delta
      assert_equal 20, @pro.call_time.at(2), $delta

      pax         2,  0,   0
      assert_veh  2,  0,  60

      # should have updated the call time for station 2
      assert_equal 30, @pro.call_time.at(0), $delta
      assert_equal 10, @pro.call_time.at(1), $delta
      assert_equal 30, @pro.call_time.at(2), $delta

      # vehicle now inbound to 0, but it is still doing its empty trip, so it is
      # not "immediately" inbound, and it is outside of station 0's call time.
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 0, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)

      # the other stations shouldn't count the vehicle
      [1, 2].each do |i|
        assert_equal 0, @sim.num_vehicles_inbound(i)
        assert_equal 0, @sim.num_vehicles_immediately_inbound(i)
        assert_equal 0, @pro.num_vehicles_inbound_in_call_time(i)
        assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(i)
      end

      # just before the vehicle gets to 2, the situation is the same
      @sim.run_to 29
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 0, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)

      # once the vehicle reaches 2, it is immediately inbound; it's also inside
      # the call time, which is (still) 30
      @sim.run_to 30
      assert_equal 30, @pro.call_time.at(0), $delta
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 1, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(0)

      # make some trips to get station 0's call time to 40s; this allows us to
      # get different behavior with and without the call times
      pax         0,  1,  50
      assert_veh  0,  1,  70 # departs at 60s, 10s trip
      pax         0,  1,  60
      assert_veh  0,  1, 130 # 60s around the loop

      assert_in_delta 50, @pro.call_time.at(0), $delta

      pax         1,  2,  60
      assert_veh  1,  2, 150 # 20s
      pax         0,  1,  60
      assert_veh  0,  1, 190 # 30s + 10s

      assert_in_delta (30 + 50) / 2, @pro.call_time.at(0), $delta

      # now the call time at 0 should matter
      pax         2,  0,  60
      assert_veh  2,  0, 240 # 20s + 30s

      # vehicle not yet immediately inbound; outside call time
      @sim.run_to 199
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 0, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 0, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)

      # vehicle not yet immediately inbound; now inside call time
      @sim.run_to 200
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 0, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(0)

      # now immediately inbound, and it's inside the call time
      @sim.run_to 210
      assert_equal 1, @sim.num_vehicles_inbound(0)
      assert_equal 1, @sim.num_vehicles_immediately_inbound(0)
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(0)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(0)
    end
  end

  # edge case: some tolerance is provided on call time comparison -- if we
  # always pull from some station, but due to rounding the call time comes out
  # slightly less than the travel time, we won't pull proactively from that
  # station
end

