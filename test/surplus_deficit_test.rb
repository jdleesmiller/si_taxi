require 'test/si_taxi_helper'

class SurplusDeficitTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "three station star" do
    setup do
      setup_sim TRIP_TIMES_3ST_STAR_2_2_3_3
      @ct = BWCallTimeTracker.new(@sim)
      @rea = BWNNHandlerWithCallTimeUpdates.new(@sim, @ct)
      @pro = BWSurplusDeficitHandler.new(@sim, @ct, [[   0, 0.1, 0.2],
                                                     [ 0.3,   0, 0.4],
                                                     [ 0.5, 0.6,   0]])
      @sim.reactive = @rea
      @sim.proactive = @pro
      @sim.init
    end

    should "work" do
      # initialized to shortest trip times
      assert_equal [0,0,0], @pro.call_time.call.to_a # counts zero
      assert_in_delta 2, @pro.call_time.at(0), $delta # from 1
      assert_in_delta 2, @pro.call_time.at(1), $delta # from 0
      assert_in_delta 3, @pro.call_time.at(2), $delta # from 0

      # check surplus calculations 
      put_veh_at 0, 0, 1, 2
      assert_in_delta 2 - 2*0.3, @pro.surplus_at(0), $delta # greater than 1
      assert_in_delta 1 - 2*0.7, @pro.surplus_at(1), $delta
      assert_in_delta 1 - 3*1.1, @pro.surplus_at(2), $delta

      # all vehicles arrive idle at time 0; there is a surplus at 0, so one
      # vehicle moves to the nearest station with a surplus, which is 1 
      @sim.run_to 1
      assert_veh 0, 1, 2
      assert_veh 0, 0, 0
      assert_veh 1, 1, 0
      assert_veh 2, 2, 0

      # the empty trip is a call to 1, but the call time is the same
      assert_equal [0,1,0], @pro.call_time.call.to_a
      assert_in_delta 2, @pro.call_time.at(0), $delta 
      assert_in_delta 2, @pro.call_time.at(1), $delta
      assert_in_delta 3, @pro.call_time.at(2), $delta

      # new surplus calculations; no one has surplus > 1
      assert_in_delta 1 - 2*0.3, @pro.surplus_at(0), $delta
      assert_in_delta 2 - 2*0.7, @pro.surplus_at(1), $delta
      assert_in_delta 1 - 3*1.1, @pro.surplus_at(2), $delta

      # no surplus > 1 means no action on idle
      @sim.run_to 3
      assert_veh 0, 1, 2
      assert_veh 0, 0, 0
      assert_veh 1, 1, 0
      assert_veh 2, 2, 0

      # there is one idle vehicle at 0; if we send it to 1, it should come back
      # when it becomes idle 
      pax        0, 1, 3
      assert_veh 0, 1, 5 # occupied
      assert_veh 1, 0, 5 # idle proactively moved back to 0
      assert_veh 1, 1, 0
      assert_veh 2, 2, 0

      # the empty trip is a call to 0, but the call time is the same
      assert_equal [1,1,0], @pro.call_time.call.to_a
      assert_in_delta 2, @pro.call_time.at(0), $delta
      assert_in_delta 2, @pro.call_time.at(1), $delta
      assert_in_delta 3, @pro.call_time.at(2), $delta

      # surpluses stay the same
      assert_in_delta 1 - 2*0.3, @pro.surplus_at(0), $delta
      assert_in_delta 2 - 2*0.7, @pro.surplus_at(1), $delta
      assert_in_delta 1 - 3*1.1, @pro.surplus_at(2), $delta
      
      # if we have a trip from 2 to 1, the idle vehicle at 1 goes to 2
      pax        2, 1, 3
      assert_veh 0, 1, 5 # occupied
      assert_veh 1, 0, 5 # idle proactively moved back to 0
      assert_veh 1, 2, 8
      assert_veh 2, 1, 8

      # the empty trip is a call to 2; this changes the call time
      assert_equal [1,1,1], @pro.call_time.call.to_a
      assert_in_delta 2, @pro.call_time.at(0), $delta
      assert_in_delta 2, @pro.call_time.at(1), $delta
      assert_in_delta 5, @pro.call_time.at(2), $delta

      # surplus for 2 changes due to call time change
      assert_in_delta 1 - 2*0.3, @pro.surplus_at(0), $delta
      assert_in_delta 2 - 2*0.7, @pro.surplus_at(1), $delta
      assert_in_delta 1 - 5*1.1, @pro.surplus_at(2), $delta

      # if we send an idle vehicle from 0, it should go to 2
      @sim.run_to 10
      @pro.send_idle_veh_to_nearest_deficit(0)
      assert_veh 0, 2, 13
      assert_veh 0, 1,  5
      assert_veh 1, 2,  8
      assert_veh 2, 1,  8

      # the empty trip is a call to 2; the call time should average
      assert_equal [1,1,2], @pro.call_time.call.to_a
      assert_in_delta 2, @pro.call_time.at(0), $delta
      assert_in_delta 2, @pro.call_time.at(1), $delta
      assert_in_delta (3+5)/2.0, @pro.call_time.at(2), $delta

      assert_in_delta 0 - 2*0.3, @pro.surplus_at(0), $delta
      assert_in_delta 2 - 2*0.7, @pro.surplus_at(1), $delta
      assert_in_delta 2 - 4*1.1, @pro.surplus_at(2), $delta
    end
  end
end

__END__
  demand_matrix_t<double> lambda;
  from_s(lambda, "[3,3]((0,0.1,0.2),(0.3,0,0.4),(0.5,0.6,0))");
  lambda.recompute_stats();
  matrix_t<int> trip_times;
  from_s(trip_times, TIMES_THREE_STAR_2_2_3_3); // 3 stations
  vector<double> call_times;
  vector<int> calls;
  F_surplus_deficit_base sd(lambda, trip_times, 0.1, call_times, calls);

  CHECK(sd.call_times.size() == 3);
  CHECK(sd.call_times[0] == 2); // from 1
  CHECK(sd.call_times[1] == 2); // from 0
  CHECK(sd.call_times[2] == 3); // from 0

  vector<veh_t> vehs;
  vehs.push_back(veh_t(0, 0));
  vehs.push_back(veh_t(0, 0));
  vehs.push_back(veh_t(1, 0));
  vehs.push_back(veh_t(2, 0));

  CHECK(sd.vehicle_supply(0, vehs, 0) == 2);
  CHECK(sd.vehicle_supply(0, vehs, 1) == 1);
  CHECK(sd.vehicle_supply(0, vehs, 2) == 1);

  CHECK_CLOSE(sd.demand(0), 2*0.3, TEST_EPS);
  CHECK_CLOSE(sd.demand(1), 2*0.7, TEST_EPS);
  CHECK_CLOSE(sd.demand(2), 3*1.1, TEST_EPS);

  // Need to record some trips; don't want output to go to terminal.
  ostringstream ss;
  synchronous::trip_stream = &ss;

  sd.send_surplus_to_poorest(1, vehs, 2); // no effect
  sd.send_surplus_to_poorest(1, vehs, 1); // no effect
  sd.send_surplus_to_poorest(1, vehs, 0);

  CHECK(ss.str() == "trip: 0 1 0 2 0\n"); // destin = 2
  CHECK(vehs[0].destin == 2);
  CHECK(vehs[0].arrive == 4); // called at 1; travel time 3

  CHECK_CLOSE(call_times[0], 2, TEST_EPS);
  CHECK_CLOSE(call_times[1], 2, TEST_EPS);
  CHECK_CLOSE(call_times[2], 3, TEST_EPS); // no change since travel time = 3

  CHECK(sd.vehicle_supply(1, vehs, 0) == 1);
  CHECK(sd.vehicle_supply(1, vehs, 1) == 1);
  CHECK(sd.vehicle_supply(1, vehs, 2) == 2); // within call time
  CHECK(sd.vehicle_supply(2, vehs, 0) == 1);
  CHECK(sd.vehicle_supply(2, vehs, 1) == 1);
  CHECK(sd.vehicle_supply(2, vehs, 2) == 2);

  sd.send_surplus_to_nearest(2, vehs, 2); // no effect (surplus -1.3)
  sd.send_surplus_to_nearest(2, vehs, 1); // no effect (surplus -0.4)
  sd.send_surplus_to_nearest(2, vehs, 0); // no effect (surplus 0.4 < 1)

  // Start all vehicles at 1; some will go to 2.
  for (size_t i = 0; i < 4; ++i) {
    vehs[i].arrive = 5;
    vehs[i].destin = 1;
  }

  sd.send_surplus_to_nearest(5, vehs, 1); // send to 0
  CHECK(sd.vehicle_supply(5, vehs, 2) == 0);
  CHECK(sd.vehicle_supply(5, vehs, 1) == 3);
  CHECK(sd.vehicle_supply(5, vehs, 0) == 1);

  sd.send_surplus_to_poorest(5, vehs, 1); // send to 2

  // This causes a change in the call time for station 2.
  CHECK_CLOSE(call_times[0], 2, TEST_EPS);
  CHECK_CLOSE(call_times[1], 2, TEST_EPS);
  CHECK_CLOSE(call_times[2], 0.1*5 + 0.9*3, TEST_EPS);

  CHECK(sd.vehicle_supply(5, vehs, 2) == 0); // has not shown up yet
  CHECK(sd.vehicle_supply(6, vehs, 2) == 0);
  CHECK(sd.vehicle_supply(7, vehs, 2) == 1); // now within 3.2s
  CHECK(sd.vehicles_inbound(5, vehs, 2) == 1); // but they are inbound
  CHECK(sd.vehicles_inbound(6, vehs, 2) == 1); // but they are inbound
  CHECK(sd.vehicles_inbound(7, vehs, 2) == 1); // but they are inbound
  CHECK(sd.vehicle_supply(5, vehs, 1) == 2);
  CHECK(sd.vehicle_supply(5, vehs, 0) == 1);

