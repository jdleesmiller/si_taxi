require 'test/si_taxi_helper'

class FluidLimitTest < Test::Unit::TestCase
  include TestHelper
  include SiTaxi
  include SiTaxi::AbstractNetworks
  include SiTaxi::FluidLimit

  should "compute ev_flows on 2 station ring" do
    times = [[0,  10], [ 20, 0]]
    l     = [[0, 0.1], [0.0, 0]]
    assert_equal <<LP, make_fluid_limit_lp(times, l)
min: 0 y0_0 + 10 y0_1 + 20 y1_0 + 0 y1_1;
0 + y0_0 + 0.1 + y0_1 = 0 + y0_0 + 0.0 + y1_0;
0.0 + y1_0 + 0 + y1_1 = 0.1 + y0_1 + 0 + y1_1;
y0_0 >= 0;
y0_1 >= 0;
y1_0 >= 0;
y1_1 >= 0;
LP

    # Ensure that LP solver actually runs.
    flows = solve_fluid_limit_lp(times, l)
    assert_all_in_delta [[0,0],[0.1,0]].flatten, flows.flatten, $delta

    # Compute intensity for 2 vehicles, say.
    assert_in_delta((0.1*30)/2.0,
                    fluid_limit_intensity(times, l, flows, 2), $delta)
  end

  def test_ring_3_capacity
    g = ring_network(1, 2, 3)
    times = network_trip_times(g)
    l = [[0,0.1,0.2],
         [0.3,0,0.4],
         [0.5,0.6,0]]

    # Make sure we're solving the right LP.
    assert_equal <<LP, make_fluid_limit_lp(times, l)
min: 0 y0_0 + 1 y0_1 + 3 y0_2 + 5 y1_0 + 0 y1_1 + 2 y1_2 + 3 y2_0 + 4 y2_1 + 0 y2_2;
0 + y0_0 + 0.1 + y0_1 + 0.2 + y0_2 = 0 + y0_0 + 0.3 + y1_0 + 0.5 + y2_0;
0.3 + y1_0 + 0 + y1_1 + 0.4 + y1_2 = 0.1 + y0_1 + 0 + y1_1 + 0.6 + y2_1;
0.5 + y2_0 + 0.6 + y2_1 + 0 + y2_2 = 0.2 + y0_2 + 0.4 + y1_2 + 0 + y2_2;
y0_0 >= 0;
y0_1 >= 0;
y0_2 >= 0;
y1_0 >= 0;
y1_1 >= 0;
y1_2 >= 0;
y2_0 >= 0;
y2_1 >= 0;
y2_2 >= 0;
LP

    # Ensure that LP solver actually runs.
    flows = solve_fluid_limit_lp(times, l)

    # A 0.5 flow from 0 to 2 works; so does 0.5 from 0 to 1 and 0.5 from 1 to 2.
    assert [[[  0,  0,0.5],
             [  0,  0,  0],
             [  0,  0,  0]],
            [[  0,0.5,  0],
             [  0,  0,0.5],
             [  0,  0,  0]]].any? {|sol|
      sol.flatten.zip(flows.flatten).all?{|x,y|(x-y).abs < $delta}}

    # Combining full and empty vehicle flows with the times gives intensity.
    fv = 0.1*1 + 0.2*3 + 0.3*5 + 0.4*2 + 0.5*3 + 0.6*4
    ev = 0.5*3
    assert_in_delta fv + ev, fluid_limit_intensity(times, l, flows, 1), $delta
  end

  def test_star_2_capacity
    g = star_network([10,20],[30,40])
    times = network_trip_times(g)
    l = [[0,1,1],
         [1,0,1],
         [1,1,0]] # uniform demand is easy

    # Make sure we're solving the right LP.
    assert_equal <<LP, make_fluid_limit_lp(times, l)
min: 0 y0_0 + 10 y0_1 + 30 y0_2 + 20 y1_0 + 0 y1_1 + 50 y1_2 + 40 y2_0 + 50 y2_1 + 0 y2_2;
0 + y0_0 + 1 + y0_1 + 1 + y0_2 = 0 + y0_0 + 1 + y1_0 + 1 + y2_0;
1 + y1_0 + 0 + y1_1 + 1 + y1_2 = 1 + y0_1 + 0 + y1_1 + 1 + y2_1;
1 + y2_0 + 1 + y2_1 + 0 + y2_2 = 1 + y0_2 + 1 + y1_2 + 0 + y2_2;
y0_0 >= 0;
y0_1 >= 0;
y0_2 >= 0;
y1_0 >= 0;
y1_1 >= 0;
y1_2 >= 0;
y2_0 >= 0;
y2_1 >= 0;
y2_2 >= 0;
LP

    # Ensure that LP solver actually runs.
    flows = solve_fluid_limit_lp(times, l)

    # A 0.5 flow from 0 to 2 clearly satisfies the constraints... can't see a
    # better one.
    assert_equal [[0,0,0],
                  [0,0,0],
                  [0,0,0]], flows

    # Combining full and empty vehicle flows with the times gives intensity.
    assert_in_delta 10 + 30 + 20 + 50 + 40 + 50,
      fluid_limit_intensity(times, l, flows, 1), $delta
  end

  def test_transaction_time_tensor 
    t = NArray[
      [0,1,2],
      [2,0,1],
      [1,2,0]].to_f # 3 station ring with unit edges
    tau = transaction_time_tensor(t)
    assert_equal [
      [[0.0, 3.0, 3.0],  # T_11+T_11, T_12+T_21, T_13+T_31
       [2.0, 2.0, 2.0],  # T_21+T_11, T_22+T_21, T_23+T_31
       [1.0, 4.0, 1.0]], # T_31+T_11, T_32+T_21, T_33+T_31
      [[1.0, 1.0, 4.0],
       [3.0, 0.0, 3.0], 
       [2.0, 2.0, 2.0]],
      [[2.0, 2.0, 2.0],
       [4.0, 1.0, 1.0],
       [3.0, 3.0, 0.0]]], tau
  end

  def test_transaction_probability_tensor 
    # need times that satisfy the triangle inequality
    t = [[   0,1.01,2.01],
         [2.01,   0,1.01],
         [1.01,2.01,   0]] # 3 station ring with unit edges
    d = [[0, 1, 1],
         [5, 0, 0],
         [5, 1, 0]]
    x = solve_fluid_limit_lp(t, d)
    assert_all_in_delta [
      [0,3,5],
      [0,0,0],
      [0,0,0]].flatten, x.flatten, $delta

    tau_pr = transaction_probability_tensor(d, x)
    assert_all_in_delta [
     [[         0,      0,      0],  # s1 is an empty source: no empties in
      [         0,      0,      0],
      [         0,      0,      0]],
     [[         0, 1.0/13,      0],  # s1->s2->s2; s2 uses all of its empties
      [5.0/13*3/8,      0,      0],  # s2->s1->s2
      [5.0/13*3/8, 1.0/13,      0]], # s3->s1->s2, s3->s2->s2
     [[         0,      0, 1.0/13],  # s1->s3->s3; s3 uses all of its empties
      [5.0/13*5/8,      0,      0],  # s2->s1->s3
      [5.0/13*5/8,      0,      0]]].flatten, tau_pr.flatten, $delta
  end

  def test_transaction_probability_tensor_depot
    # make sure we get a sensible answer if there is a station with no demand
    t = [[   0,1.01,2.01],
         [2.01,   0,1.01],
         [1.01,2.01,   0]] # 3 station ring with unit edges
    d = [[0, 0, 0],
         [0, 0, 0],
         [0, 1, 0]]
    x = solve_fluid_limit_lp(t, d)
    assert_all_in_delta [
      [0,0,0],
      [0,0,1],
      [0,0,0]].flatten, x.flatten, $delta

    tau_pr = transaction_probability_tensor(d, x)
    # only one trip is possible: s3->s2->s3
    assert_all_in_delta [
      [[0,0,0],[0,0,0],[0,0,0]],
      [[0,0,0],[0,0,0],[0,0,0]],
      [[0,0,0],[0,0,0],[0,1,0]]].flatten, tau_pr.flatten, $delta
  end

  def test_mgk_simulation
    t = [[ 0, 10.1, 30.1], 
         [ 20.1, 0, 50.1], 
         [ 40.1, 50.1, 0]] # 3 station star
    d = [[   0,   0,   0],
         [ 0.1,   0, 0.1],
         [ 0.1, 0.1,   0]]
    x = solve_fluid_limit_lp(t, d)
    assert_all_in_delta [
      [   0, 0.1, 0.1],
      [   0,   0,   0],
      [   0,   0,   0]].flatten, x.flatten, $delta

    sim = MGKSimulation.new(t,d,x,30,100)
    sim.run
    assert_equal 100, sim.obs_pax_queue.size
    assert_equal 100, sim.obs_pax_wait.size
  end
end

