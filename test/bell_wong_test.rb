require 'test/si_taxi_helper'

class BellWongTest < Test::Unit::TestCase
  include BellWongTestHelper

  context "new sim" do
    setup do
      @sim = BWSim.new
      @sim_stats = BWSimStatsDetailed.new(@sim)
    end

    should "have defaults" do
      assert_equal 0, @sim.now
      assert_equal 0, @sim.strobe
      assert_equal nil, @sim.reactive
      assert_equal nil, @sim.proactive
      assert_equal [], @sim.vehs.to_a
      assert_equal [], @sim.trip_time

      assert_equal [], @sim_stats.pax_wait.to_a
      assert_equal [], @sim_stats.queue_len.to_a
      assert_equal [], @sim_stats.occupied_trips
      assert_equal [], @sim_stats.empty_trips
    end
  end

  [BWNNHandler, BWSNNHandler].each do |reactive_class|
    context "reactive algorithm #{reactive_class}" do 
      context "on two station ring (10, 20)" do
        setup do
          setup_sim TRIP_TIMES_2ST_RING_10_20
          @sim.reactive = reactive_class.new(@sim)
          @sim.proactive = BWProactiveHandler.new(@sim) # nop
          @sim.init
        end

        should "have zero wait with ideal arrivals (one vehicle) " do
          # Passengers arrive just as vehicle is ready.
          put_veh_at 0
          pax         0,  1,   0 
          assert_veh  0,  1,  10
          pax         1,  0,  10
          assert_veh  1,  0,  30
          pax         0,  1,  30 
          assert_veh  0,  1,  40

          assert_wait_hists  [2],  [1]   # zero waiting
          assert_queue_hists [30], [30]
          assert_equal [[2,0],[0,1]], @sim_stats.empty_trips
          assert_equal [[0,2],[1,0]], @sim_stats.occupied_trips
        end

        should "have zero wait with ideal arrivals (two vehicles)" do
          # One vehicle and one passenger at each station.
          put_veh_at 0, 1
          pax         0,  1,   0 
          assert_veh  0,  1,  10
          pax         1,  0,   1
          assert_veh  1,  0,  21
          assert_wait_hists [1], [1] # zero waiting
          assert_equal [[1,0],[0,1]], @sim_stats.empty_trips
          assert_equal [[0,1],[1,0]], @sim_stats.occupied_trips
        end

        should "get waiting times; no e.v. trips; two vehicles" do
          put_veh_at 0, 1
          pax         0,  1,   0
          assert_veh  0,  1,  10, 0
          pax         1,  0,   0 # try with pax at same time, diff. stations
          assert_veh  1,  0,  20, 1
          pax         0,  1,   1
          assert_veh  0,  1,  30, 1
          pax         1,  0,   1
          assert_veh  1,  0,  30, 0
          assert_wait_hists({0=>1, 19=>1}, {0=>1, 9=>1})
          assert_equal [[2,0],[0,2]], @sim_stats.empty_trips
          assert_equal [[0,2],[2,0]], @sim_stats.occupied_trips
        end

        should "handle tidal demand" do
          put_veh_at 1
          pax         0,  1,   0
          assert_veh  0,  1,  30 # 10s empty trip
          pax         0,  1,   1
          assert_veh  0,  1,  60 # 10s empty trip
          pax         0,  1,   2
          assert_veh  0,  1,  90 # 10s empty trip
          assert_wait_hists({20 => 1, 49 => 1, 78 => 1}, {})
          assert_equal [[0,0],[3,0]], @sim_stats.empty_trips
          assert_equal [[0,3],[0,0]], @sim_stats.occupied_trips

          pax         0,  1, 120 # to compute queue length stats
          assert_queue_hists [10+30,30+1,30+1,20-2], [120]
        end

        should "count inbound vehicles" do
          put_veh_at 0 
          pax         0,  1,   0
          assert_veh  0,  1,  10
          assert_equal 0, @sim.num_vehicles_inbound(0)
          assert_equal 0, @sim.num_vehicles_immediately_inbound(0)
          assert_equal 1, @sim.num_vehicles_inbound(1)
          assert_equal 1, @sim.num_vehicles_immediately_inbound(1)
        end

        should "handle strobe" do
          put_veh_at 0 
          @sim.strobe = 1
          pax         0,  1,   5
          assert_veh  0,  1,  15
          @sim.run_to 20
        end

        should "run" do
          put_veh_at 0, 1
          SiTaxi.seed_rng 1
          stream = BWPoissonPaxStream.new(0, [[0, 0.1],[0.2, 0]])
          @sim.handle_pax_stream 100, stream
          assert_equal 100, @sim_stats.pax_wait.map(&:to_a).flatten.inject(:+)
        end
      end

      context "on three station ring (10s, 20s, 30s)" do
        setup do
          setup_sim TRIP_TIMES_3ST_RING_10_20_30
          @sim.reactive = reactive_class.new(@sim)
          @sim.proactive = BWProactiveHandler.new(@sim) # nop
          @sim.init
        end

        should "handle two requests that form a round trip" do
          put_veh_at 0
          pax         1,  2,   0
          assert_veh  1,  2,  30 # 10s empty trip from 0
          pax         2,  0,   1
          assert_veh  2,  0,  60

          assert_wait_hists({}, {10 => 1}, {29 => 1})
          assert_equal [[0,1,0],
                        [0,0,0],
                        [0,0,1]], @sim_stats.empty_trips
          assert_equal [[0,0,0],
                        [0,0,1],
                        [1,0,0]], @sim_stats.occupied_trips

          pax         0,  1, 120 # to compute queue length stats
          assert_queue_hists [120], [110,10], [91,29]
        end

        should "take the closer vehicle (from 1 not 0, then from 2 not 1)" do
          # Note: both vehicles must become idle at 60s in order to get same
          # behavior from SNN and BWNN; this also tests a SNN tie-breaker,
          # since both vehicles could deliver zero waiting time.
          put_veh_at 0, 1
          pax         2,  0,   0 # choose between vehs idle at 0 and 1
          assert_veh  2,  0,  50, 1
          assert_wait_hists({}, {}, {20 => 1})
          pax         0,  2,  30
          assert_veh  0,  2,  60, 0
          assert_wait_hists({0 => 1}, {}, {20 => 1})
          pax         0,  1,  50
          assert_veh  0,  1,  60, 1
          assert_wait_hists({0 => 2}, {}, {20 => 1})
          pax         0,  1,  60 # choose between vehs idle at 1 and 2
          assert_veh  0,  1, 100, 0
          assert_wait_hists({0 => 2, 30 => 1}, {}, {20 => 1})
        end

        should "handle three vehicles" do
          put_veh_at 0,1,2
          pax         0,  1,   0
          pax         1,  2,   5
          pax         2,  0,  10
          pax         0,  1,  15 # vehicle from 2 arrives at 40
          pax         1,  2,  20 # vehicle from 0 arrives at 10
          pax         2,  0,  25 # vehicle from 1 arrives at 25
          assert_wait_hists({0=>1, 25=>1},{0=>2},{0=>2})
          assert_equal [[2,0,0],
                        [0,2,0],
                        [0,0,2]], @sim_stats.empty_trips
          assert_equal [[0,2,0],
                        [0,0,2],
                        [2,0,0]], @sim_stats.occupied_trips
        end
      end
    end
  end

  # After serving the first passenger (takes 2s), the vehicle could go back
  # to station 0 to reduce the waiting time of the second passenger; some
  # heuristics do this, and some do not.
  context "two station ring with proactive movement opportunity" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_10_20
      put_veh_at 0
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
    end

    should "not move proactively with BWNN" do
      @sim.reactive  = BWNNHandler.new(@sim)
      @sim.init
      pax 0, 1,  0
      pax 0, 1, 60
      assert_wait_hists({0=>1, 20=>1}, {})
    end

    should "move proactively with SNN" do
      @sim.reactive  = BWSNNHandler.new(@sim)
      @sim.init
      pax 0, 1,  0
      pax 0, 1, 60
      assert_wait_hists [2], [] # zero wait
    end

    should "move proactively with SNN and two vehicles" do
      @sim.reactive  = BWSNNHandler.new(@sim)
      @sim.init
      put_veh_at 0, 0
      pax 0, 1,  0
      pax 0, 1, 60
      assert_wait_hists [2], [] # zero wait
    end
  end
  
  context "SNN tie breaker tests on 3 station ring" do
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @sim.reactive = BWSNNHandler.new(@sim)
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
      @sim.init
      put_veh_at 0, 1
    end

    should "break tie on ev time" do
      pax         2,  0, 120
      assert_veh  0,  0,   0, 0
      assert_veh  2,  0, 150, 1 # chooses vehicle 1 (from station 1)
    end

    should "then on arrival time (latest first)" do
      pax         0,  2,   0
      assert_veh  0,  2,  30, 0
      pax         1,  2,  15
      assert_veh  1,  2,  35, 1
      # Now have two vehicles inbound to 2; a pax there has 0 wait with
      # either, and both have 0 empty trips; choose the one that arrived last.
      pax         2,  0,  40
      assert_veh  0,  2,  30, 0
      assert_veh  2,  0,  70, 1
    end
  end

  context "SV example from UTSG slides; two vehicles" do
    setup do
      setup_sim [[  0, 180, 300],
                 [300,   0, 120],
                 [180, 240,   0]]
      put_veh_at [2, 0, 60], 
                 [2, 2,  0]
      @sim.reactive = BWSNNHandler.new(@sim)
      @sim.proactive = BWProactiveHandler.new(@sim)
      @sim.init
    end

    should "handle test sequence 1" do
      pax         0,  1,  30 
      assert_veh  0,  1, 240, 0
      assert_veh  2,  2,   0, 1
      pax         0,  2,  120 
      assert_veh  0,  1, 240, 0
      assert_veh  0,  2, 480, 1
      pax         1,  2,  150 
      assert_veh  1,  2, 360, 0
      assert_veh  0,  2, 480, 1

      assert_wait_hists({30 => 1, 60 => 1}, {90 => 1}, {})
      assert_queue_hists [90, 60], [150], [150]

      # NB: queue hist stops at last passenger; if we give it one more:
      pax         1,  2, 300
      assert_queue_hists [210, 90], [210, 90], [300] # NB: stops at last pax
    end
  end

  context "mean pax wait recording only" do
    setup do
      @sim = BWSim.new
      @sim.trip_time = TRIP_TIMES_2ST_RING_10_20
      @sim_stats = BWSimStatsMeanPaxWait.new(@sim)
      @sim.stats = @sim_stats
      put_veh_at 0
      @sim.reactive = BWSNNHandler.new(@sim)
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
      @sim.init
    end

    should "default to zero" do
      assert_equal 0, @sim_stats.mean_pax_wait
      assert_equal 0, @sim_stats.pax_count
    end

    should "record single waiting time" do
      # no wait
      pax         0,  1,  10 
      assert_veh  0,  1,  20
      assert_equal 0, @sim_stats.mean_pax_wait
      assert_equal 1, @sim_stats.pax_count

      # wait 25s
      pax         0,  1,  15 
      assert_veh  0,  1,  20+20+10
      assert_in_delta 12.5, @sim_stats.mean_pax_wait, $delta
      assert_equal 2, @sim_stats.pax_count

      # wait 5s
      pax         1,  0,  45 
      assert_veh  1,  0,  70
      assert_in_delta 10, @sim_stats.mean_pax_wait, $delta
      assert_equal 3, @sim_stats.pax_count

      # should start back at zero after restart
      @sim.init
      assert_veh  1,  0,  70 # init does not reset this
      put_veh_at 0
      assert_veh  0,  0,  0
      assert_equal 0, @sim_stats.mean_pax_wait
      assert_equal 0, @sim_stats.pax_count

      # no wait, again
      pax         0,  1,  10 
      assert_veh  0,  1,  20
      assert_equal 0, @sim_stats.mean_pax_wait
      assert_equal 1, @sim_stats.pax_count
      
      # wait 5s
      pax         1,  0,  15 
      assert_veh  1,  0,  40
      assert_in_delta 2.5, @sim_stats.mean_pax_wait, $delta
      assert_equal 2, @sim_stats.pax_count
    end
  end

  context "for vehicle parking" do
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @sim.reactive = BWNNHandler.new(@sim)
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
      @sim.init
    end

    should "be able to add vehicles and repark" do
      assert_equal 0, @sim.vehs.size

      @sim.add_vehicles_in_turn 3
      assert_equal 3, @sim.vehs.size
      assert_veh  0,  0,  0
      assert_veh  1,  1,  0
      assert_veh  2,  2,  0

      @sim.add_vehicles_in_turn 1
      assert_equal 4, @sim.vehs.size
      assert_equal 2, @sim.vehs.to_a.select{|v| v.destin == 0}.size

      pax         0,  1,  10 
      assert_veh  0,  1,  20
      assert_equal 1, @sim.vehs.to_a.select{|v| v.destin == 0}.size

      # should go back to being parked
      @sim.init
      @sim.park_vehicles_in_turn
      assert_veh  0,  0,  0
      assert_veh  1,  1,  0
      assert_veh  2,  2,  0
      assert_equal 2, @sim.vehs.to_a.select{|v| v.destin == 0}.size

    end
  end
end

