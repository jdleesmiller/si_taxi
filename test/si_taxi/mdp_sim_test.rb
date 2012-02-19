require 'si_taxi/test_helper'

class MDPSimTest < Test::Unit::TestCase
  include TestHelper
  include SiTaxi

  context "two station ring with one vehicle" do
    setup do
      @m = MDPSim.new
      @m.trip_time = [[0, 1], [1, 0]]
      @m_stats = MDPSimStats.new(@m)
      @m.stats = @m_stats
      @m.init
      @m.add_vehicles_in_turn 1
    end

    should "be initialised" do
      assert_equal 0, @m.now
      assert_equal 2, @m.num_stations
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[-1],[]], @m.inbound.to_a

      # stats empty
      assert_equal [[], []], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[], []], @m.stats.pax_wait_simple.map(&:to_a)
      assert_equal [[], []], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[], []], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 0], [0, 0]], @m.stats.occupied_trips
      assert_equal [[0, 0], [0, 0]], @m.stats.empty_trips
    end

    should "check that an empty is available at 0" do
      @m.tick [[0,1],[0,0]], []
      assert_equal 1, @m.now
      assert_equal [[],[1]], @m.inbound.to_a

      assert_raises(RuntimeError) { @m.tick [[0,1],[0,0]], [] }
    end

    should "check that an empty is available at 1" do
      assert_raises(RuntimeError) { @m.tick [[0,0],[1,0]], [] }
    end

    should "tick" do
      # no empty vehicle action, no new arrivals
      @m.tick [[0,0],[0,0]], []
      assert_equal 1, @m.now
      assert_equal 1, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[-1],[]], @m.inbound.to_a

      # no pax served yet; empty queues observed
      assert_equal [[], []], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[], []], @m.stats.pax_wait_simple.map(&:to_a)
      assert_equal [[1], [1]], @m.stats.queue_len_simple.map(&:to_a)
      # one idle vehicle at 0; none at 1
      assert_equal [[0,1], [1]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 0], [0, 0]], @m.stats.occupied_trips
      assert_equal [[0, 0], [0, 0]], @m.stats.empty_trips

      # move vehicle empty to station 1
      @m.tick [[0,1],[0,0]], []
      assert_equal 2, @m.now
      assert_equal 1, @m.num_vehicles # conservation
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[],[2]], @m.inbound.to_a

      # no change in stats -- they measure at the start of the tick
      assert_equal [[], []], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[], []], @m.stats.pax_wait_simple.map(&:to_a)
      assert_equal [[2], [2]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[0,2], [2]], @m.stats.idle_vehs_simple.map(&:to_a)
      # but we do pick up the empty trip
      assert_equal [[0, 0], [0, 0]], @m.stats.occupied_trips
      assert_equal [[0, 1], [0, 0]], @m.stats.empty_trips

      # move the vehicle back to station 0
      @m.tick [[0,0],[1,0]], []
      assert_equal 3, @m.now
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[3],[]], @m.inbound.to_a

      # vehicle not idle at either station
      assert_equal [[3], [3]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[1,2], [3]], @m.stats.idle_vehs_simple.map(&:to_a)
      # but we do pick up the empty trip
      assert_equal [[0, 1], [1, 0]], @m.stats.empty_trips
      
      # put in a request at 1 (but don't move the empty)
      # the convention on passenger arrival times is effectively that we take
      # the ceiling of their actual arrival time; so, if the pax arrives in
      # the interval (3, 4], we count it as 4.
      @m.tick [[0,0],[0,0]], [MDPPax.new(1,0,3)]
      assert_equal 4, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[3],[]], @m.inbound.to_a

      # vehicle picks up request right away; does not become 'idle'
      assert_equal [[4], [4]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[2,2], [4]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 0], [0, 0]], @m.stats.occupied_trips
      assert_equal [[0, 1], [1, 0]], @m.stats.empty_trips

      # if we don't move the empty, the request should stay in the queue
      @m.tick [[0,0],[0,0]], []
      assert_equal 5, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[3],[]], @m.inbound.to_a

      # vehicle becomes idle at 0; request in queue but not yet served
      assert_equal [[], []], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[], []], @m.stats.pax_wait_simple.map(&:to_a)
      assert_equal [[5], [4,1]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[2, 3], [5]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 0], [0, 0]], @m.stats.occupied_trips
      assert_equal [[0, 1], [1, 0]], @m.stats.empty_trips

      # move the idle vehicle at 0 to serve the request at 1; it will arrive
      # at station 1 at time t + 1
      @m.tick [[0,1],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[],[6]], @m.inbound.to_a

      # no change to histograms yet, but we pick up the empty trip
      assert_equal [[6], [4,2]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[2, 4], [6]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 2], [1, 0]], @m.stats.empty_trips

      # vehicle is now at 1, where there is a queued pax, so we can't move it
      # away; it should go back to station 0 occupied
      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[7],[]], @m.inbound.to_a

      # pax arrived at t=3 and was served at t=6
      assert_equal [[], [0,0,0,1]], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[], [0,0,0,1]], @m.stats.pax_wait_simple.map(&:to_a)
      assert_equal [[7], [4,3]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[3, 4], [7]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 0], [1, 0]], @m.stats.occupied_trips
      assert_equal [[0, 2], [1, 0]], @m.stats.empty_trips

      # an arrival at 0 should be served by the idle vehicle there
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,7)]
      assert_equal 8, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[],[8]], @m.inbound.to_a

      # new request does not join queue; served directly
      assert_equal [[8], [5,3]], @m.stats.queue_len_simple.map(&:to_a)
      assert_equal [[4, 4], [8]], @m.stats.idle_vehs_simple.map(&:to_a)
      assert_equal [[0, 1], [1, 0]], @m.stats.occupied_trips
      assert_equal [[0, 2], [1, 0]], @m.stats.empty_trips
    end

    should "respect queue_max limit" do
      @m.queue_max = 1

      # add two pax at 1; only one will remain
      @m.tick [[0,0],[0,0]], [MDPPax.new(1,0,0),MDPPax.new(1,0,0)]
      assert_equal 1, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[-1],[]], @m.inbound.to_a
    end

    should "handle non-unit time step in stats" do

      # 10s per MDP timestep
      @m.stats.step = 10

      # two pax at 0; one is served with wait 0, since the vehicle was idle
      # the other will be have to wait
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,0.5), MDPPax.new(0,1,0.5)]
      assert_equal 1, @m.now
      assert_equal [1, 0], @m.queue.map(&:size)
      assert_equal [[],[1]], @m.inbound.to_a

      assert_equal [[1], []], @m.stats.pax_wait.map(&:to_a)
      assert_equal [[1], []], @m.stats.pax_wait_simple.map(&:to_a)

      @m.tick [[0,0],[1,0]], []
      assert_equal 2, @m.now
      assert_equal [1, 0], @m.queue.map(&:size)
      assert_equal [[2],[]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 3, @m.now
      assert_equal [0, 0], @m.queue.map(&:size)
      assert_equal [[],[3]], @m.inbound.to_a

      # second pax served at t=2 from queue by non-idle vehicle, so we use
      # 10 * (2 + 0.5) - 0.5 = 24.5, which rounds down to 24
      # the basic estimate is t=2 - t=0, which is 20s
      assert_equal 1, @m.stats.pax_wait[0].frequency[24]
      assert_equal 1, @m.stats.pax_wait_simple[0].frequency[20]

      @m.tick [[0,0],[0,0]], [MDPPax.new(1,0,31.5)]
      assert_equal 4, @m.now
      assert_equal [0, 0], @m.queue.map(&:size)
      assert_equal [[4],[]], @m.inbound.to_a

      # third pax is a new request served by a non-idle vehicle; calc is
      # (10 * (3 + 1) - 31.5) / 2 = (40 - 31.5) / 2 = 8.5 / 2 = 4
      assert_equal [0,0,0,0,1], @m.stats.pax_wait[1].to_a
      assert_equal [1], @m.stats.pax_wait_simple[1].to_a
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
      assert_equal [[-1],[]], @m.inbound.to_a

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
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,4), MDPPax.new(1,0,4)]
      assert_equal 5, @m.now
      assert_equal [1,1], @m.queue.map(&:size)
      assert_equal 0, @m.queue[0][0].origin
      assert_equal 1, @m.queue[0][0].destin
      assert_equal 1, @m.queue[1][0].origin
      assert_equal 0, @m.queue[1][0].destin
      assert_equal [[6],[]], @m.inbound.to_a

      # vehicle isn't available at t=5
      @m.tick [[0,0],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [1,1], @m.queue.map(&:size)
      assert_equal [[6],[]], @m.inbound.to_a

      # now it should serve the queued request at 0
      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now
      assert_equal [0,1], @m.queue.map(&:size)
      assert_equal [[],[8]], @m.inbound.to_a

      # vehicle is just travelling
      @m.tick [[0,0],[0,0]], []
      assert_equal 8, @m.now

      # when it becomes available (t=8), it should serve the queued request at 1
      @m.tick [[0,0],[0,0]], []
      assert_equal 9, @m.now
      assert_equal [0,0], @m.queue.map(&:size)
      assert_equal [[11],[]], @m.inbound.to_a

      # let it get to its destination
      @m.tick [[0,0],[0,0]], []
      @m.tick [[0,0],[0,0]], []
      @m.tick [[0,0],[0,0]], []
      assert_equal 12, @m.now
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
      assert_equal [[-1],[-1]], @m.inbound.to_a

      # add two pax that cause vehicles to swap places
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,1), MDPPax.new(1,0,1)]
      assert_equal 2, @m.now
      assert_equal 2, @m.num_vehicles
      assert_equal [[],[]], @m.queue.to_a
      assert_equal [[4],[3]], @m.inbound.to_a

      # add another pair of requests to both stations
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,2), MDPPax.new(1,0,2)]
      assert_equal 3, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[4],[3]], @m.inbound.to_a

      # the queued request at 1 can now be served, the other vehicle is still on
      # its first trip from 1 to 0, and it will continue
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,3), MDPPax.new(1,0,3)]
      assert_equal 4, @m.now
      assert_equal [2, 1], @m.queue.map(&:size)
      assert_equal [[4,6],[]], @m.inbound.to_a

      # now the first queued request at 0 will be served
      @m.tick [[0,0],[0,0]], [MDPPax.new(0,1,4), MDPPax.new(1,0,4)]
      assert_equal 5, @m.now
      assert_equal [2, 2], @m.queue.map(&:size)
      assert_equal [[6],[6]], @m.inbound.to_a

      # let the system run without new requests; queued pax should be served
      @m.tick [[0,0],[0,0]], []
      assert_equal 6, @m.now
      assert_equal [2, 2], @m.queue.map(&:size)
      assert_equal [[6],[6]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 7, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[9],[8]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 8, @m.now
      assert_equal [1, 1], @m.queue.map(&:size)
      assert_equal [[9],[8]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 9, @m.now
      assert_equal [1, 0], @m.queue.map(&:size)
      assert_equal [[9,11],[]], @m.inbound.to_a

      @m.tick [[0,0],[0,0]], []
      assert_equal 10, @m.now
      assert_equal [0, 0], @m.queue.map(&:size)
      assert_equal [[11],[11]], @m.inbound.to_a
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
      assert_equal [[-1],[-1],[]], @m.inbound.to_a

      # no action; should get no state change
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 1, @m.now
      assert_equal [[],[],[]], @m.queue.to_a
      assert_equal [[-1],[-1],[]], @m.inbound.to_a

      # move idle vehicle at hub 0 to spoke 2; leaves at 1, arrives at 1+3=4
      @m.tick [[0,0,1],[0,0,0],[0,0,0]], []
      assert_equal 2, @m.now
      assert_equal [[],[],[]], @m.queue.to_a
      assert_equal [[],[-1],[4]], @m.inbound.to_a

      # add requests at the hub; they will have to wait until we move the idle
      # vehicles back
      @m.tick [[0,0,0],[0,0,0],[0,0,0]],
        [MDPPax.new(0,1,2),MDPPax.new(0,2,2),
         MDPPax.new(0,1,2),MDPPax.new(0,2,2)]
      assert_equal 3, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[],[-1],[4]], @m.inbound.to_a

      # still waiting for the first vehicle to reach spoke 2...
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 4, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[],[-1],[4]], @m.inbound.to_a

      # now we can move them back to the center
      @m.tick [[0,0,0],[1,0,0],[1,0,0]], []
      assert_equal 5, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[6,7],[],[]], @m.inbound.to_a

      # nothing new at t=5
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 6, @m.now
      assert_equal [4,0,0], @m.queue.map(&:size)
      assert_equal [[6,7],[],[]], @m.inbound.to_a

      # first request (which was to spoke 1) should be served at t=6
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 7, @m.now
      assert_equal [3,0,0], @m.queue.map(&:size)
      assert_equal [[7],[8],[]], @m.inbound.to_a

      # second request (which was to spoke 2) should be served at t=7
      @m.tick [[0,0,0],[0,0,0],[0,0,0]], []
      assert_equal 8, @m.now
      assert_equal [2,0,0], @m.queue.map(&:size)
      assert_equal [[],[8],[10]], @m.inbound.to_a
    end
  end

  context "MDPPoissonPaxStream with high demand" do
    setup do
      @stream = MDPPoissonPaxStream.new(0, 10, [[0,0.1],[0.2,0]])
    end

    should "generate requests" do
      # initialisation
      assert_equal 0, @stream.now
      assert_equal 0, @stream.last_time
      assert_equal 10, @stream.step

      paxs = @stream.next_pax

      # one time step later
      assert_equal 10.0, @stream.now
      assert @stream.last_time >= @stream.now
      assert paxs.all? {|pax| 0 <= pax.arrive && pax.arrive < 10}

      paxs = @stream.next_pax

      # second time step
      assert_equal 20.0, @stream.now
      assert @stream.last_time >= @stream.now
      assert paxs.all? {|pax| 10 <= pax.arrive && pax.arrive < 20}

      # try some more time steps
      prev = @stream.now
      100.times do
        paxs = @stream.next_pax
        assert_close prev + @stream.step, @stream.now
        assert @stream.last_time >= @stream.now
        assert paxs.all? {|pax| prev <= pax.arrive && pax.arrive < @stream.now}
        prev = @stream.now
      end
    end
  end

  context "MDPPoissonPaxStream with low demand" do
    setup do
      @stream = MDPPoissonPaxStream.new(0, 2, [[0,0.01],[0.02,0]])
    end

    should "generate requests" do
      # initialisation
      assert_equal 0, @stream.now
      assert_equal 0, @stream.last_time
      assert_equal 2, @stream.step

      # generate some pax...
      prev = @stream.now
      100.times do
        paxs = @stream.next_pax
        assert_close prev + @stream.step, @stream.now
        assert @stream.last_time >= @stream.now
        assert paxs.all? {|pax| prev <= pax.arrive && pax.arrive < @stream.now}
        prev = @stream.now
      end
    end
  end
end

