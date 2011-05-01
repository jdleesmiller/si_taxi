require 'test/si_taxi_helper'

class AndreassonTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "two station ring (10, 20)" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_10_20
      @ct = BWCallTimeTracker.new(@sim)
      @rea = BWNNHandlerWithCallTimeUpdates.new(@sim, @ct)
      @pro = BWAndreassonHandler.new(@sim, @ct, [[  0, 120.0/3600], # veh / sec
                                                 [  0,          0]])
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
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

      # if we restart the sim, call times should be cleared
      @sim.init
      assert_equal 0, @pro.call_time.call[0]
      assert_equal 0, @pro.call_time.call[1]
      assert_equal 0, @rea.call_time.call[0]
      assert_equal 0, @rea.call_time.call[1]
      assert_in_delta 20, @pro.call_time.at(0), $delta
      assert_in_delta 10, @pro.call_time.at(1), $delta
      assert_in_delta 20, @rea.call_time.at(0), $delta
      assert_in_delta 10, @rea.call_time.at(1), $delta
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
                                     [[  0, 180.0/3600, 0], # veh / sec
                                      [  0,          0, 0],
                                      [  0,          0, 0]])
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
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

      # if we restart the sim, call times should be cleared
      @sim.init
      assert_equal [0, 0, 0], @pro.call_time.call.to_a
      assert_in_delta 30, @pro.call_time.at(0), $delta
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

      assert_in_delta((30 + 50) / 2, @pro.call_time.at(0), $delta)

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

    should "cope with call time rounding errors when counting inbound" do
      # edge case: some tolerance is provided on call time comparison -- if we
      # always call from some station, but due to rounding the call time comes
      # out slightly less than the travel time, we won't call proactively from
      # that station, unless there is a tolerance (EPSILON)
      
      put_veh_at 0
      pax         1,  2,   0
      assert_veh  1,  2,  30 

      @sim.run_to 5
      assert_equal 1, @sim.num_vehicles_inbound(2)
      assert_equal 0, @sim.num_vehicles_immediately_inbound(2)

      @ct.call_time[2] = 100.0 # directly modifying the call time
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(2)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(2)

      @ct.call_time[2] = 25.0
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(2)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(2)

      @ct.call_time[2] = 24.9999 # tolerance is 1e-3
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(2)
      assert_equal 0, @pro.num_vehicles_immediately_inbound_in_call_time(2)

      @sim.run_to 10

      assert_equal 1, @sim.num_vehicles_inbound(2)
      assert_equal 1, @sim.num_vehicles_immediately_inbound(2)
      assert_equal 1, @pro.num_vehicles_inbound_in_call_time(2)
      assert_equal 1, @pro.num_vehicles_immediately_inbound_in_call_time(2)
    end

    should "move proactively" do
      put_veh_at 0

      # 30s call time at 180 trips / hr => 1.5 vehicles - one vehicle idle at 0
      assert_in_delta(-0.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta(   0, @pro.surplus(2), $delta)

      # move vehicle to 2
      pax         1,  2,   0
      assert_veh  1,  2,  30

      # vehicle left has left, but it's outside of station 2's call time (20s),
      # so it isn't initially counted.
      assert_in_delta(-1.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta(   0, @pro.surplus(2), $delta)

      # run until vehicle inside station 2's call time
      @sim.run_to 9
      assert_in_delta(-1.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta(   0, @pro.surplus(2), $delta)
      @sim.run_to 10
      assert_in_delta(-1.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta( 1.0, @pro.surplus(2), $delta)
      
      # vehicle is moved proactively when it becomes idle at 2
      @sim.run_to 30
      assert_in_delta(-1.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta( 1.0, @pro.surplus(2), $delta)
      @sim.run_to 31
      assert_in_delta(-0.5, @pro.surplus(0), $delta)
      assert_in_delta(   0, @pro.surplus(1), $delta)
      assert_in_delta(   0, @pro.surplus(2), $delta)

      # This should have updated the call time at 0.
      assert_equal [1, 1, 0], @ct.call.to_a
      assert_in_delta 30.0, @ct.call_time[0], $delta # no change -- still 30
      assert_in_delta 10.0, @ct.call_time[1], $delta
      assert_in_delta 20.0, @ct.call_time[2], $delta
    end

    should "move proactively when there are two vehicles" do
      put_veh_at 0, 2

      pax         1,  2,   0
      assert_veh  1,  2,  30

      # this should prompt the vehicle that is idle at 2 to move to station 0
      assert_veh  2,  0,  30
    end

    should "use the call queue" do
      # here we'll set targets instead of using the call times and od matrix
      @pro.use_call_times_for_targets = false
      @pro.targets[0] = 1
      @pro.targets[1] = 1
      @pro.targets[2] = 1

      assert_equal 0, @pro.call_queue.size

      # targets are set so that no immediate replacement is available; it is
      # placed in the call queue
      put_veh_at 0, 2
      pax        0, 1,  0
      assert_veh 0, 1, 10
      assert_veh 2, 2,  0

      assert_equal 1, @pro.call_queue.size

      # lower target at 0, so it no longer (thinks it) wants a vehicle, and
      # lower the target at 1, so that it's willing to give up
      @pro.targets[0] = 0
      @pro.targets[1] = 0

      @sim.run_to 11
      assert_equal 0, @pro.call_queue.size
      assert_veh 1, 0, 60
      assert_veh 2, 2,  0
    end

    should "handle vehicle becoming idle at a station with a queued call" do
      # an edge case: if a station has a queued call, and a vehicle becomes idle
      # there, the call should remain outstanding; the rationale is that the
      # vehicle was already inbound when the call was made, so the station still
      # wanted/wants more vehicles.
      
      # here we'll set targets instead of using the call times and od matrix
      @pro.use_call_times_for_targets = false
      @pro.targets[0] = 1
      @pro.targets[1] = 1
      @pro.targets[2] = 1

      assert_equal 0, @pro.call_queue.size

      # targets are set so that no immediate replacement is available; a call to
      # station 0 is placed on the queue
      put_veh_at 0, 2
      pax        0, 1,  0
      assert_veh 0, 1, 10
      assert_veh 2, 2,  0

      assert_equal 1, @pro.call_queue.size

      # vehicle 0 now idle at 1; the call remains on the queue; send vehicle 1
      # to station 0, where it becomes idle; if we lower the target at station
      # 0, station 0 now has a surplus, so it will try to use the incoming
      # vehicle to service a call
      @sim.run_to 11
      assert_equal 1, @pro.call_queue.size

      pax        1, 0,  15
      @pro.targets[0] = 0

      @sim.run_to 66
      assert_veh 1, 0, 65
      assert_veh 2, 2,  0

      # note that another call will have been queued, this time to station 1
      assert_equal 2, @pro.call_queue.size
    end

    should "use reset the call queue on a call to init" do
      @pro.use_call_times_for_targets = false
      @pro.targets[0] = 1
      @pro.targets[1] = 1
      @pro.targets[2] = 1

      # targets are set so that no immediate replacement is available; it is
      # placed in the call queue
      put_veh_at 0, 2
      pax        0, 1,  0
      assert_veh 0, 1, 10
      assert_veh 2, 2,  0

      assert_equal 1, @pro.call_queue.size
      @sim.run_to 9
      assert_equal 1, @pro.call_queue.size

      # reset the sim; this should reset the call queue
      @sim.init
      assert_equal 0, @pro.call_queue.size

      # it does not change the vehicle states, however
      assert_veh 0, 1, 10
      assert_veh 2, 2,  0
    end

    [true, false].each do |send_when_over|
      should "send when over (when #{send_when_over})" do
        @pro.send_when_over = send_when_over

        # just set the targets rather than using call times
        # make station 2 think it needs lots of vehicles
        @pro.use_call_times_for_targets = false
        @pro.targets[0] = 0
        @pro.targets[1] = 0
        @pro.targets[2] = 3

        # send vehicles to 1
        put_veh_at 0, 0, 0
        pax        0, 1,  0
        pax        0, 1,  0
        pax        0, 1,  0

        # they should all want to move to 2
        @sim.run_to 10
        assert_veh 0, 1, 10, 0
        assert_veh 0, 1, 10, 1
        assert_veh 0, 1, 10, 2
        @sim.run_to 11

        # the target at station 0 is 0, but the surplus threshold is 1, so it
        # queues a call when the last vehicle leaves; when the vehicles reach
        # station 1 (which has target 0), one is assigned due to this call
        assert_veh 1, 0, 60, 0

        if send_when_over
          # the remaining vehicles continue on to station 2
          assert_veh 1, 2, 30, 1
          assert_veh 1, 2, 30, 2

          # before they get to 2, tell them 2 no longer wants vehicles (for fun)
          @pro.targets[0] = 2
          @pro.targets[1] = 1
          @pro.targets[2] = 0
          @sim.run_to 31
          assert_veh 1, 0, 60, 0
          assert_veh 2, 0, 60, 1
          assert_veh 2, 1, 70, 2
        else
          # the remaining vehicles stay at station 1
          assert_veh 0, 1, 10, 1
          assert_veh 0, 1, 10, 2
        end
      end
    end

    [true, false].each do |call_only_from_surplus|
      should "pull only from surplus (#{call_only_from_surplus})" do
        @pro.call_only_from_surplus = call_only_from_surplus 

        # just set the targets rather than using call times
        # give station 0 a large target; set station 2's target so that when
        # there is one vehicle at station 2, it does not have a surplus, but it
        # does have a smaller deficit than station 0
        @pro.use_call_times_for_targets = false
        @pro.targets[0] = 3
        @pro.targets[1] = 0
        @pro.targets[2] = 1

        put_veh_at 0, 2
        pax        0, 1,  0
        assert_veh 0, 1, 10

        if call_only_from_surplus
          assert_veh 2, 2,  0
        else
          assert_veh 2, 0, 30
        end
      end
    end

    [true, false].each do |use_preferred|
      should "respect preferred stations on call (#{use_preferred})" do
        # set all targets to zero (ignore call times)
        @pro.use_call_times_for_targets = false

        # if there are no preferred stations set, we'd rather call from 1 to 2
        # than from 0 to 2, because 1 is closer; however, if we tell the sim to
        # prefer 0 to 2, it should do that instead
        if use_preferred
          @pro.preferred = [[false, false, true],
                            [false, false, false],
                            [false, false, false]]
        end

        put_veh_at 0, 1, 2
        pax        2, 0,  0
        assert_veh 2, 0, 30

        if use_preferred
          assert_veh 0, 2, 30
          assert_veh 1, 1,  0
        else
          assert_veh 0, 0,  0
          assert_veh 1, 2, 20
        end
      end

      should "respect preferred stations on send (#{use_preferred})" do
        @pro.use_call_times_for_targets = false
        @pro.targets[0] = 2
        @pro.targets[1] = 0
        @pro.targets[2] = 1

        # if there are no preferred stations set, we'd rather send from 1 to 0
        # than from 1 to 2, because 0 has a larger deficit; however, if we tell
        # the sim to prefer to send from 1 to 2, it should do that instead
        if use_preferred
          @pro.preferred = [[false, false, false],
                            [false, false, true],
                            [false, false, false]]
        end

        put_veh_at 0, 1
        pax        0, 1,  0
        assert_veh 0, 1, 10
        assert_veh 1, 0, 50

        @sim.run_to 15
        if use_preferred
          assert_veh 1, 2, 30
        else
          assert_veh 1, 0, 60
        end
      end
     end
  end
end

