require 'si_taxi/test_helper'

class MDPSimTest < Test::Unit::TestCase
  include SiTaxi

  context "two station ring with one vehicle" do
    setup do
      @m = MDPSim.new
      @m.trip_time = [[0, 1], [1, 0]]
      @m.init
      @m.add_vehicles_in_turn 1
    end

    should "be initialised" do
      assert_equal 0, @m.now
      assert_equal 2, @m.num_stations
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[0],[]], @m.inbound.to_a
    end

    should "tick" do
      # no empty vehicle action, no new arrivals
      @m.tick [[0,0],[0,0]], []
      assert_equal 1, @m.now
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[0],[]], @m.inbound.to_a

      # ensure we can't move an empty when there isn't one
      assert_raises(RuntimeError) { @m.tick [[0,0],[1,0]], [] }
      assert_equal 1, @m.now

      # move vehicle empty to station 1
      @m.tick [[0,1],[0,0]], []
      assert_equal 2, @m.now
      assert_equal 1, @m.num_vehicles # conservation
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[],[2]], @m.inbound.to_a
      
      # ensure we can't move an empty when there isn't one
      assert_raises(RuntimeError) { @m.tick [[0,1],[0,0]], [] }
      assert_equal 2, @m.now

      # move the vehicle back to station 0
      @m.tick [[0,0],[1,0]], []
      assert_equal 3, @m.now
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[3],[]], @m.inbound.to_a

      # put in a request at 1 (but don't move the empty)
      # the convention on passenger arrival times is effectively that we take
      # the ceiling of their actual arrival time; so, if the pax arrives in
      # the interval (3, 4], we count it as 4.
      @m.tick [[0,0],[0,0]], [BWPax.new(1,0,4)]
      assert_equal 4, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[3],[]], @m.inbound.to_a

      # if we don't move the empty, the request should stay in the queue
      @m.tick [[0,0],[0,0]], []
      assert_equal 5, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[3],[]], @m.inbound.to_a

      # move the idle vehicle at 0 to serve the request at 1; it will pick
      # up the request at 1 and start its trip back to 0 at time t+1, so
      # it will arrive at 0 at time t + 2
      @m.tick [[0,1],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[7],[]], @m.inbound.to_a

      # vehicle now in motion, so we can't take any actions
      assert_raises(RuntimeError) { @m.tick [[0,1],[0,0]], [] }
      assert_raises(RuntimeError) { @m.tick [[0,0],[1,0]], [] }
      assert_equal 6, @m.now

      # vehicle moved at t=5 should become idle at 0
      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[7],[]], @m.inbound.to_a

      # an arrival at 0 should be served by the idle vehicle there
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,8)]
      assert_equal 8, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[],[9]], @m.inbound.to_a
    end

    should "respect queue_max limit" do
      @m.queue_max = 1

      # add two pax at 1; only one will remain
      @m.tick [[0,0],[0,0]], [BWPax.new(1,0,1),BWPax.new(1,0,1)]
      assert_equal 1, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[0],[]], @m.inbound.to_a
    end
  end

  context "two station ring with one vehicle and multi-tick travel times" do
    setup do
      @m = MDPSim.new
      @m.trip_time = [[0, 2], [3, 0]]
      @m.init
      @m.add_vehicles_in_turn 1
    end

    should "tick" do
      # no empty vehicle action, no new arrivals
      @m.tick [[0,0],[0,0]], []
      assert_equal 1, @m.now
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[0],[]], @m.inbound.to_a

      # move idle vehicle from 0 to 1; it should take two time steps 
      @m.tick [[0,1],[0,0]], []
      assert_equal 2, @m.now
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[],[3]], @m.inbound.to_a

      # can't do anything while vehicle is in transit
      assert_raises(RuntimeError) { @m.tick [[0,1],[0,0]], [] }
      assert_raises(RuntimeError) { @m.tick [[0,0],[1,0]], [] }
      assert_equal 2, @m.now
      @m.tick [[0,0],[0,0]], []
      assert_equal 3, @m.now
      assert_equal [[],[3]], @m.inbound.to_a

      # now we can move it back from 1 to 0; this should take 3 time steps
      @m.tick [[0,0],[1,0]], []
      assert_equal 4, @m.now
      assert_equal [[6],[]], @m.inbound.to_a

      # add a request at 0 and a request at 1
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,5), BWPax.new(1,0,5)]
      assert_equal 5, @m.now
      assert_equal [1,1], @m.queue.map(&:size)
      assert_equal 0, @m.queue[0][0].origin
      assert_equal 1, @m.queue[0][0].destin
      assert_equal 1, @m.queue[1][0].origin
      assert_equal 0, @m.queue[1][0].destin
      assert_equal [[6],[]], @m.inbound.to_a

      # vehicle becomes available this time step; it should serve the queued
      # request at 0
      @m.tick [[0,0],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[],[8]], @m.inbound.to_a

      # vehicle is just travelling
      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now

      # when it becomes available (t=8), it should serve the queued request at 1
      @m.tick [[0,0],[0,0]], []
      assert_equal 8, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[11],[]], @m.inbound.to_a

      # let it get to its destination
      @m.tick [[0,0],[0,0]], []
      @m.tick [[0,0],[0,0]], []
      @m.tick [[0,0],[0,0]], []
      assert_equal 11, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[11],[]], @m.inbound.to_a
    end
  end

  context "two station ring with two vehicles and multi-tick travel times" do
    setup do
      @m = MDPSim.new
      @m.trip_time = [[0, 2], [3, 0]]
      @m.init
      @m.add_vehicles_in_turn 2
    end

    should "tick" do
      # no empty vehicle action, no new arrivals
      @m.tick [[0,0],[0,0]], []
      assert_equal 1, @m.now
      assert_equal 2, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[0],[0]], @m.inbound.to_a

      # add two pax that cause vehicles to swap places
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,2), BWPax.new(1,0,2)]
      assert_equal 2, @m.now
      assert_equal 2, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[5],[4]], @m.inbound.to_a

      # add another pair of requests to both stations
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,2), BWPax.new(1,0,2)]
      assert_equal 3, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[5],[4]], @m.inbound.to_a

      # the queued request at 1 can now be served, the other vehicle is still on
      # its first trip from 1 to 0, and it will continue
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,4), BWPax.new(1,0,4)]
      assert_equal 4, @m.now
      assert_equal [2, 1], @m.queue.map(&:size)
      assert_equal [[5,7],[]], @m.inbound.to_a

      # now the first queued request at 0 will be served
      @m.tick [[0,0],[0,0]], [BWPax.new(0,1,5), BWPax.new(1,0,5)]
      assert_equal 5, @m.now
      assert_equal [2, 2], @m.queue.map(&:size)
      assert_equal [[7],[7]], @m.inbound.to_a

      # let the system run without new requests; queued pax should be served
      @m.tick [[0,0],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [2, 2], @m.queue.map(&:size)
      assert_equal [[7],[7]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[10],[9]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 8, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[10],[9]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 9, @m.now
      assert_equal [1, 0], @m.queue.map(&:size)
      assert_equal [[10,12],[]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 10, @m.now
      assert_equal [0, 0], @m.queue.map(&:size)
      assert_equal [[12],[12]], @m.inbound.to_a
    end
  end

  context "three station star with two vehicles" do
    setup do
      @m = MDPSim.new
      @m.trip_time = TRIP_TIMES_3ST_STAR_2_2_3_3
      @m.init
      @m.add_vehicles_in_turn 2
    end

    should "tick" do
      assert_equal 0, @m.now
      assert_equal 2, @m.num_vehicles
      assert_equal [[],[],[]], @m.queue.to_a
      assert_equal [[0],[0],[]], @m.inbound.to_a

      # no action; should get no state change
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 1, @m.now
      assert_equal [[],[],[]], @m.queue.to_a
      assert_equal [[0],[0],[]], @m.inbound.to_a

      # move idle vehicle at hub 0 to spoke 2; leaves at 1, arrives at 1+3=4
      @m.tick [[0,0,1],[0,0,0],[0,0,0]], []
      assert_equal 2, @m.now
      assert_equal [[],[],[]], @m.queue.to_a
      assert_equal [[],[0],[4]], @m.inbound.to_a

      # add requests at the hub; they will have to wait until we move the idle
      # vehicles back
      @m.tick [[0,0,0],[0,0,0],[0,0,0]],
        [BWPax.new(0,1,3),BWPax.new(0,2,3),BWPax.new(0,1,3),BWPax.new(0,2,3)]
      assert_equal 3, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[],[0],[4]], @m.inbound.to_a

      # still waiting for the first vehicle to reach spoke 2...
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 4, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[],[0],[4]], @m.inbound.to_a

      # now we can move them back to the center
      @m.tick [[0,0,0],[1,0,0],[1,0,0]], []
      assert_equal 5, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[6,7],[],[]], @m.inbound.to_a

      # first request (which was to spoke 1) should be served at t=6
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 6, @m.now
      assert_equal [3,0,0], @m.queue.map(&:size)
      assert_equal [[7],[8],[]], @m.inbound.to_a

      # second request (which was to spoke 2) should be served at t=7
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 7, @m.now
      assert_equal [2,0,0], @m.queue.map(&:size)
      assert_equal [[],[8],[10]], @m.inbound.to_a
    end
  end
end

=begin
  // the model may be somewhat misleading...
  // we take an action at time t (move a vehicle from A to B)
  // the successor state at time t+1 should have ETA = t_AB - 1, but I think it
  // currently sets ETA = t_AB, then we decide on the action, and then we
  // move the vehicle one step forward at the start of the next time step.
  // That's probably not too bad, but it's a bit strange.

      # HOPEFULLY FIXED:
      # NB no longer true that q_i > 0 => l_i = 0
      # this also means that we can technically steal an empty from a waiting
      # passenger when the minimum trip time is one time step
      # perhaps we should enforce that trip_time > 1
      # but it seems like a hack; on the other hand, all vehicles are
      # potentially 'available' at a station, if they're one timestep away,
      # which isn't very nice
=end
