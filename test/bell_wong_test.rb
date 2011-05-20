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

  #
  # Basic tests that all of the reactive handlers should pass.
  #
  [BWNNHandler, BWH1Handler, BWH2Handler,
    BWETNNHandler, BWSNNHandler].each do |reactive_class|
    context "reactive algorithm #{reactive_class}" do 
      context "on two station ring (10, 20)" do
        setup do
          setup_sim TRIP_TIMES_2ST_RING_10_20
          uniform_od = [[0,1],[1,0]]
          if reactive_class == BWH1Handler
            @sim.reactive = BWH1Handler.new(@sim, uniform_od, 0.1)
          elsif reactive_class == BWH2Handler
            @sim.reactive = BWH2Handler.new(@sim, uniform_od, 0.1, 2)
          else
            @sim.reactive = reactive_class.new(@sim)
          end
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
          assert_equal [30], @sim_stats.idle_vehs_total.to_a # veh never idle
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
          assert_queue_hists [1], [1] # no waiting

          # we count the idle vehicles for frame 0 only; there's one at 1
          assert_equal [0, 1], @sim_stats.idle_vehs_total.to_a
          assert_equal [1], @sim_stats.idle_vehs[0].to_a
          assert_equal [0, 1], @sim_stats.idle_vehs[1].to_a
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

          # vehicle spends last 30s idle at 1
          assert_equal [90, 30], @sim_stats.idle_vehs_total.to_a
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
          uniform_od = [[0,1,1],[1,0,1],[1,1,0]]
          if reactive_class == BWH1Handler
            @sim.reactive = BWH1Handler.new(@sim, uniform_od, 0.1)
          elsif reactive_class == BWH2Handler
            @sim.reactive = BWH2Handler.new(@sim, uniform_od, 0.1, 2)
          else
            @sim.reactive = reactive_class.new(@sim)
          end
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

          # no idle vehicles at 0
          assert_equal [25],     @sim_stats.idle_vehs[0].to_a
          # one vehicle idle from 0s-5s, then 10s-20s
          assert_equal [10, 15], @sim_stats.idle_vehs[1].to_a
          # one vehicle idle from 0s-10s
          assert_equal [15, 10], @sim_stats.idle_vehs[2].to_a
          # two vehicles idle from 0s-5s; one vehicle from 5s-10s + 10s-20s
          assert_equal [5, 15, 5], @sim_stats.idle_vehs_total.to_a
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

    should "not move proactively with BWETNN" do
      @sim.reactive  = BWETNNHandler.new(@sim)
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
    end

    # should try both vehicle numberings
    [[0,1], [1,0]].each do |vehicle_pos|
      context "vehicle positions: #{vehicle_pos.join(',')}" do
        setup do
          put_veh_at(*vehicle_pos)
        end

        should "break tie on ev time" do
          # both vehicles can reach 2 before time 120, so they give the same
          # waiting time; however, the vehicle at 1 has a shorter ev trip
          pax         2,  0, 120
          assert_veh  0,  0,   0
          assert_veh  2,  0, 150
        end

        should "then on arrival time (latest first)" do
          pax         0,  2,   0
          assert_veh  0,  2,  30
          pax         1,  2,  15
          assert_veh  1,  2,  35
          # now have two vehicles inbound to 2; a pax there at time 40 has 0
          # wait with either vehicle, and both have 0 empty trips; choose the
          # one that arrived last.
          pax         2,  0,  40
          assert_veh  0,  2,  30
          assert_veh  2,  0,  70
        end
      end
    end

    should "finally break ties on vehicle index" do
      put_veh_at 0, 0
      pax         2,  0,   5
      assert_veh  2,  0,  60, 0
      assert_veh  0,  0,   0, 1
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

  context "BWNN vs ETNN on three station ring" do
    # in both of the tests below, vehicle 0 is going from 0 to 2, and it could
    # pick up a new passenger at 2 with no new empty vehicle trip, but vehicle 1
    # is idle at station 1, and it could get there first
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
    end

    context "BWNN" do
      setup do
        @sim.reactive = BWNNHandler.new(@sim)
        @sim.init
      end
      should "prefer vehicle with lower waiting time" do
        put_veh_at 0, 1
        pax         0,  2,   0 
        assert_veh  0,  2,  30
        assert_veh  1,  1,   0

        pax         2,  0,   5
        assert_veh  0,  2,  30
        assert_veh  2,  0,  55
        assert_wait_hists  [1], [], {20 => 1} # time from 1 to 2
      end
    end

    context "ETNN" do
      setup do
        @sim.reactive = BWETNNHandler.new(@sim)
        @sim.init
      end
      should "prefer vehicle with lower empty trip time" do
        put_veh_at 0, 1
        pax         0,  2,   0 
        assert_veh  0,  2,  30
        assert_veh  1,  1,   0

        pax         2,  0,   5
        assert_veh  2,  0,  60
        assert_veh  1,  1,   0
        assert_wait_hists  [1], [], {25 => 1} # time until vehicle 0 gets to 2
      end
    end
  end

  context "with the 'myopic' test network" do
    # These tests demonstrate that immediately assigning a vehicle to an
    # arriving passenger (even with later revision) can cause problems. See also
    # 'myopic_trouble_sets' in some older code. The H1 heuristic mitigates these
    # to some extent.
    # The demand matrix is set so that
    # expected_next_wait[1] = 0
    # expected_next_wait[2] = 40
    # so the H1 objective is
    # for the vehicle at 1: 10 - alpha*ENW[1] = 10
    # for the vehicle at 2: 30 - alpha*ENW[2]
    # so alpha = 0.5 is the threshold. 
    setup do
      # This is derived from grid_7st_800m by choosing stations 2, 3 and 4 and
      # scaling the travel times down by 8 (convenience).
      setup_sim [[0, 50,10],
                 [10, 0,20],
                 [30,40, 0]]
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
      @od = [[0, 0, 0],   # pax/hr
             [0, 0, 1],
             [0, 0, 0]]
    end

    [BWNNHandler, BWH1Handler].each do |reactive_handler|
      should "move the wrong vehicle with #{reactive_handler} (alpha 0.4)" do
        if reactive_handler == BWNNHandler
          @sim.reactive = BWNNHandler.new(@sim)
        else
          @sim.reactive = BWH1Handler.new(@sim, @od, 0.4)
        end
        @sim.init

        put_veh_at 1, 2

        # passenger from 0 to 2 takes the vehicle from 1
        pax         0,  2,   0 
        assert_veh  0,  2,   0 + 10 + 10

        # passenger at 1 has to take the vehicle from 2
        pax         1,  2,   1 
        assert_veh  1,  2,   1 + 40 + 20

        assert_wait_hists({10 => 1}, {40 => 1}, {})
      end

      should "#{reactive_handler} move right vehicle if we reverse pax order" do
        @sim.reactive = BWH1Handler.new(@sim, @od, 0.6)
        @sim.init

        put_veh_at 1, 2

        # passenger from 1 to 2 takes the vehicle from 1
        pax         1,  2,   0 
        assert_veh  1,  2,   20

        # passenger from 0 to 2 takes the vehicle from 2
        pax         0,  2,   1 
        assert_veh  0,  2,   1 + 30 + 10

        assert_wait_hists({30 => 1}, {0 => 1}, {})
      end
    end

    should "move the wrong vehicle with SNN (but move it earlier)" do
      @sim.reactive = BWSNNHandler.new(@sim)
      @sim.init

      put_veh_at 1, 2

      # passenger from 0 to 2 takes the vehicle from 1
      pax         0,  2,   0 
      assert_veh  0,  2,   0 + 10 + 10

      # passenger at 1 has to take the vehicle from 2
      pax         1,  2,   1 
      assert_veh  1,  2,   0 + 40 + 20

      assert_wait_hists({10 => 1}, {39 => 1}, {})
    end

    should "move the right vehicle with BWH1 and alpha > 0.5" do
      @sim.reactive = BWH1Handler.new(@sim, @od, 0.6)
      @sim.init

      put_veh_at 1, 2

      # passenger from 0 to 2 takes the vehicle from 2
      pax         0,  2,   0 
      assert_veh  0,  2,   0 + 30 + 10

      # passenger from 1 to 2 takes the vehicle from 1
      pax         1,  2,   1 
      assert_veh  1,  2,   1 + 0 + 20

      assert_wait_hists({30 => 1}, {0 => 1}, {})
    end
  end

  context "BWH1 test on three station star network" do
    #
    # Here we tell the heuristic that there is a large demand from station 1, so
    # it will hold a vehicle there, even though this increases the waiting time
    # of the given requests.
    #
    setup do
      # This is derived from grid_7st_800m by choosing stations 2, 3 and 4 and
      # scaling the travel times down by 8 (convenience).
      setup_sim [[ 0, 2, 3],
                 [ 2, 0, 5],
                 [ 3, 5, 0]]
      @sim.proactive = BWProactiveHandler.new(@sim) # nop
      @od = [[0, 0, 1  ], # pax/hr
             [0, 0, 100],
             [0, 0, 0  ]]
    end

    [BWNNHandler, BWH1Handler].each do |reactive_handler|
      should "move the vehicle at 1 with #{reactive_handler} (alpha 0.0)" do
        if reactive_handler == BWNNHandler
          @sim.reactive = BWNNHandler.new(@sim)
        else
          @sim.reactive = BWH1Handler.new(@sim, @od, 0.0)
        end
        @sim.init

        put_veh_at 0, 1

        # pax at 0 takes vehicle at 0
        pax         0,  2,   0 
        assert_veh  0,  2,   0 + 3
        
        # next pax at 0 takes vehicle at 1
        pax         0,  2,   4 
        assert_veh  0,  2,   4 + 2 + 3

        assert_wait_hists({0 => 1, 2 => 1}, {}, {})
      end
    end

    should "not move the vehicle at 1 if alpha is 0.75" do
      @sim.reactive = BWH1Handler.new(@sim, @od, 0.75)
      @sim.init

      put_veh_at 0, 1

      # pax at 0 takes vehicle at 0
      pax         0,  2,   0 
      assert_veh  0,  2,   0 + 3

      # next pax at 0 uses the vehicle that just became idle at 2, even though
      # the vehicle at 1 is closer
      pax         0,  2,   4 
      assert_veh  0,  2,   4 + 3 + 3

      assert_wait_hists({0 => 1, 3 => 1}, {}, {})
    end
  end
end

