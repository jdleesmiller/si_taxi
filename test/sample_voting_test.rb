require 'test/si_taxi_helper'

class SamplingVotingTest < Test::Unit::TestCase
  include BellWongTestHelper

  #
  # Add given passengers to the sample stream. The sample stream must be empty
  # before you call this method (otherwise an assertion fails).
  #
  # The intention is to feed the sample passengers in only as-needed.
  #
  def sample_pax *paxs
    assert @sample_stream.pax.size() == 0,
      "there are #{@sample_stream.pax.size()} passengers still in the stream"
    paxs.each do |pax|
      @sample_stream.pax.push BWPax.new(*pax)
    end
  end

  context "two station ring (10, 20)" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_10_20
      @rea = BWNNHandler.new(@sim)
      @sample_stream = BWTestPaxStream.new
      @pro = BWSamplingVotingHandler.new(@sim, @sample_stream)
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "have defaults set" do
      assert_equal 0, @pro.num_sequences
      assert_equal 0, @pro.num_pax
      assert_equal 0, @sample_stream.pax.size
    end

    should "handle tidal flow" do
      @pro.num_sequences = 1
      @pro.num_pax = 2

      sample_pax(*([[0, 1, 10]] * 12))

      # somewhat off-topic: we can prevent handle_idle from running when t = 0
      # by initialising the vehicles with arrive = -1; give this a try here; 
      # if we initialized with arrive = 0, we'd use 14 sample passengers
      put_veh_at [0, 0, -1], [0, 0, -1]
      
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

  context "two station ring (2, 3)" do
    setup do
      setup_sim TRIP_TIMES_2ST_RING_2_3
      @rea = BWNNHandler.new(@sim)
      @sample_stream = BWTestPaxStream.new
      @pro = BWSamplingVotingHandler.new(@sim, @sample_stream)
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "handle tidal demand" do
      put_veh_at 0, 1

      # with an accurate sample, both vehicles should return to station 0
      @pro.num_sequences = 1
      @pro.num_pax = 3

      # first pax: handle_pax_served is called; there are no vehicles at 0, so
      # one trip from 0 to 1 gives a non-trivial idle trip
      sample_pax  [0, 1, 1]
      pax         0,  1,   0
      assert_veh  0,  1,   2

      # vehicle becomes idle at 1; the first sample pax is handled by the
      # vehicle already on its way to 0; the second is non-trivial
      sample_pax  [0, 1, 1], [0, 1, 2]
      @sim.run_to 3
      assert_veh  1,  0,   3
      assert_veh  1,  0,   5

      # vehicle becomes idle at station 0; keep it there with 3 trivial trips
      sample_pax  [0, 1, 1], [0, 1, 2], [0, 1, 3]
      @sim.run_to 4

      # vehicle becomes idle at station 0; keep it there with 3 trivial trips
      sample_pax  [0, 1, 1], [0, 1, 2], [0, 1, 3]
      @sim.run_to 6

      # second pax: now we have two vehicles at 0; 3 trivial trips to keep them
      sample_pax  [0, 1, 1], [0, 1, 2], [0, 1, 3]
      pax         0,  1,   10
      assert_veh  0,  1,   12
      assert_veh  1,  0,    3

      # third pax: no idle vehicles, so no sample pax needed
      pax         0,  1,   11
      assert_veh  0,  1,   13

      # vehicles becomes idle at 1; one is enough to get it back to 0
      sample_pax  [0, 1, 1]
      @sim.run_to 13

      # vehicles becomes idle at 1; two needed to get it back to 0
      sample_pax  [0, 1, 1], [0, 1, 2]
      @sim.run_to 14
      assert_equal 0, @sample_stream.pax.size

      assert_wait_hists({0 => 3}, {})
    end

    should "handle balanced demand" do
      put_veh_at 0, 0, 0

      # sample is balanced, but actual demand is tidal
      @pro.num_sequences = 2
      @pro.num_pax = 3

      # no vehicles at station 0; it decides to send one
      sample_pax [0, 1, 1], [1, 0, 2],            # 1st vehicle, 1st sequence
                 [1, 0, 1],                       # 2nd vehicle, 2nd sequence
                 [0, 1, 1], [1, 0, 2], [0, 1, 3], # 2nd vehicle, 1st sequence
                 [1, 0, 1], [0, 1, 2], [1, 0, 3], # 2nd vehicle, 2nd sequence
                 [0, 1, 1], [1, 0, 2], [0, 1, 3], # 3rd vehicle, 1st sequence
                 [1, 0, 1], [0, 1, 2], [1, 0, 3]  # 3rd vehicle, 2nd sequence
      @sim.run_to 1 
      assert_veh  0,  1,   2, 0
      assert_veh  0,  0,   0, 1
      assert_veh  0,  0,   0, 2

      # vehicle arrives at 1; we don't send it back
      sample_pax [0, 1, 1], [1, 0, 2], [0, 1, 3], # 1st sequence
                 [1, 0, 1], [0, 1, 2], [1, 0, 3]  # 2nd sequence
      @sim.run_to 3 
      assert_veh  0,  1,   2, 0
      assert_veh  0,  0,   0, 1
      assert_veh  0,  0,   0, 2

      # after pax, there is still one vehicle left at station 0
      sample_pax [0, 1, 1], [1, 0, 2], [0, 1, 3], # 1st sequence
                 [1, 0, 1], [0, 1, 2], [1, 0, 3]  # 2nd sequence
      pax         0,  1,   5
      assert_veh  0,  1,   2, 0
      assert_veh  0,  1,   7, 1
      assert_veh  0,  0,   0, 2

      # vehicle becomes idle at 1; we don't send it back
      sample_pax [0, 1, 1], [1, 0, 2], [0, 1, 3], # 1st sequence
                 [1, 0, 1], [0, 1, 2], [1, 0, 3]  # 2nd sequence
      @sim.run_to 8 
      assert_veh  0,  1,   2, 0
      assert_veh  0,  1,   7, 1
      assert_veh  0,  0,   0, 2

      # after pax, there are no vehicles left at station 0
      sample_pax [0, 1, 1],            # 1st sequence
                 [1, 0, 1], [0, 1, 2]  # 2nd sequence
      pax         0,  1,  10
      assert_veh  1,  0,  13, 0
      assert_veh  0,  1,   7, 1
      assert_veh  0,  1,  12, 2
      assert_equal 0, @sample_stream.pax.size
    end

    should "keep idle vehicles where needed (single sample pax)" do
      # the following is based on the old "test_hybrid_all_idle" test
      # the sample just says that the next pax will arrive at station 0
      @pro.num_sequences = 2
      @pro.num_pax = 1
      sample_pax(*([[0, 1, 10]] * 10))
      
      # there are two vehicles idle at station 1; get one more inbound
      put_veh_at 0, 1, 1
      pax         0,  1,   0 
      assert_veh  0,  1,   2

      # should get a vehicle going back to 0 to replenish (and one staying at 1)
      assert_veh  1,  0,   3
      assert_veh  1,  1,   0
    end

    should "keep idle vehicles where needed (two sample pax)" do
      # the following is based on the old "test_hybrid_all_idle" test
      # the sample says that the next pax will arrive at station 0, but that the
      # following pax will arrive at 1, which makes it a bit more challenging;
      # however the behavior turns out to be the same as the test above
      @pro.num_sequences = 2
      @pro.num_pax = 2
      
      # there are two vehicles idle at station 1; get one more inbound
      put_veh_at 0, 1, 1
      sample_pax [0, 1, 10], [1, 0, 11], # one idle vehicle; 1st sequence
                 [0, 1, 10], [1, 0, 11]  # one idle vehicle; 2nd sequence
      pax         0,  1,   0 
      assert_veh  0,  1,   2

      # should get a vehicle going back to 0 to replenish (and one staying at 1)
      assert_veh  1,  0,   3
      assert_veh  1,  1,   0

      assert_equal 0, @sample_stream.pax.size
    end

    should "keep idle vehicles where needed (three sample pax)" do
      # the following is based on the old "test_hybrid_all_idle" test
      # as above, but the last two passengers arrive at 1; now it won't move
      # idle vehicles
      @pro.num_sequences = 2
      @pro.num_pax = 3

      
      # there are two vehicles idle at station 1; get one more inbound
      put_veh_at 0, 1, 1
      # note: timing of sample requests is important: if they're too spread
      # out, SNN uses the inbound vehicle for more than one vehicle
      sample_pax [0, 1, 6], [1, 0, 7], [1, 0, 7],
                 [0, 1, 6], [1, 0, 7], [1, 0, 7]
      pax         0,  1,   0 
      assert_veh  0,  1,   2

      # no vehicle sent back to 0
      assert_veh  0,  1,   2, 0
      assert_veh  1,  1,   0, 1
      assert_veh  1,  1,   0, 2

      assert_equal 0, @sample_stream.pax.size
    end
  end

  context "on three station ring (10s, 20s, 30s)" do
    setup do
      setup_sim TRIP_TIMES_3ST_RING_10_20_30
      @rea = BWNNHandler.new(@sim)
      @sample_stream = BWTestPaxStream.new
      @pro = BWSamplingVotingHandler.new(@sim, @sample_stream)
      @sim.reactive = @rea
      @sim.proactive = @pro
    end

    should "move proactively" do
      put_veh_at 0, 0, 0

      @pro.num_sequences = 3
      @pro.num_pax = 4

      # the idle handler runs once for each vehicle
      # first vehicle: three-way tie; no action
      sample_pax [1, 2,  1], # 1st vote
                 [2, 1,  1], # 2nd vote 
                 [0, 1,  3],
                 [0, 1,  6],
                 [0, 1,  9],
                 [0, 1, 12], # 3rd inconclusive
      # second vehicle: two votes for 0->1
                 [1, 2,  1], # 1st vote
                 [1, 2,  2], # 2nd vote
                 [0, 1,  3],
                 [0, 1,  6],
                 [0, 1,  9],
                 [0, 1, 12], # 3rd inconclusive
      # third vehicle: two votes for 0->2
                 [2, 1,  1], # use vehicle 0
                 [2, 1,  2], # 1st vote
                 [0, 1,  3],
                 [0, 1,  6],
                 [0, 1,  9],
                 [0, 1, 12], # 2nd inconclusive
                 [2, 1,  1], # use vehicle 0
                 [2, 1,  2]  # 3rd vote

      @sim.run_to 1
      assert_veh  0,  1,  10, 0
      assert_veh  0,  2,  30, 1
      assert_veh  0,  0,   0, 2
      assert_equal 0, @sample_stream.pax.size
    end

    should "handle station with idle vehicles but no sample pax" do
      @pro.num_sequences = 1
      @pro.num_pax = 1

      put_veh_at [0, 0, -1], [1, 1, -1]
      sample_pax [2, 0, 13]
      pax         1,  2,   10 
      assert_veh  0,  0,  -1
      assert_veh  1,  2,   30
    end
  end

  should "run on a three station ring (10s, 20s, 30s)" do
    setup_sim TRIP_TIMES_3ST_RING_10_20_30
    rea = BWNNHandler.new(@sim)
    @sim.reactive = rea

    SiTaxi.seed_rng(666)
    sample_stream = BWPoissonPaxStream.new(0,
      [[  0, 0.2, 0.4],
       [0.1,   0, 0.3],
       [  0, 0.1,   0]])
    pro = BWSamplingVotingHandler.new(@sim, sample_stream)
    pro.num_sequences = 3
    pro.num_pax = 5
    @sim.proactive = pro

    stream = BWPoissonPaxStream.new(0,
      [[  0, 0.1, 0.2],
       [  0,   0, 0.4],
       [0.2, 0.3,   0]])
    put_veh_at(*([0,1,2]*15))
    @sim.handle_pax_stream 100, stream
    assert_equal 100, @sim_stats.pax_wait.map(&:to_a).flatten.inject(:+)
  end
end

