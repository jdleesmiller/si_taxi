require 'test/si_taxi_helper'

class FluidLimitTest < Test::Unit::TestCase
  include TestHelper
  include SiTaxi
  include SiTaxi::AbstractNetworks

  should "compute ev_flows on 2 station ring" do
    times = [[0,  10], [ 20, 0]]
    l     = [[0, 0.1], [0.0, 0]]
    assert_equal <<LP, FluidLimit.make_lp(times, l)
min: 0 y0_0 + 10 y0_1 + 20 y1_0 + 0 y1_1;
0 + y0_0 + 0.1 + y0_1 = 0 + y0_0 + 0.0 + y1_0;
0.0 + y1_0 + 0 + y1_1 = 0.1 + y0_1 + 0 + y1_1;
y0_0 >= 0;
y0_1 >= 0;
y1_0 >= 0;
y1_1 >= 0;
LP

    # Ensure that LP solver actually runs.
    flows = FluidLimit.solve_lp(times, l)
    assert_all_in_delta [[0,0],[0.1,0]].flatten, flows.flatten, $delta

    # Compute intensity for 2 vehicles, say.
    assert_in_delta((0.1*30)/2.0,
                    FluidLimit.intensity(times, l, flows, 2), $delta)
  end

  def test_ring_3_capacity
    g = ring_network(1, 2, 3)
    times = network_trip_times(g)
    l = [[0,0.1,0.2],
         [0.3,0,0.4],
         [0.5,0.6,0]]

    # Make sure we're solving the right LP.
    assert_equal <<LP, FluidLimit.make_lp(times, l)
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
    flows = FluidLimit.solve_lp(times, l)

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
    assert_in_delta fv + ev, FluidLimit.intensity(times, l, flows, 1), $delta
  end

  def test_star_2_capacity
    g = star_network([10,20],[30,40])
    times = network_trip_times(g)
    l = [[0,1,1],
         [1,0,1],
         [1,1,0]] # uniform demand is easy

    # Make sure we're solving the right LP.
    assert_equal <<LP, FluidLimit.make_lp(times, l)
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
    flows = FluidLimit.solve_lp(times, l)

    # A 0.5 flow from 0 to 2 clearly satisfies the constraints... can't see a
    # better one.
    assert_equal [[0,0,0],
                  [0,0,0],
                  [0,0,0]], flows

    # Combining full and empty vehicle flows with the times gives intensity.
    assert_in_delta 10 + 30 + 20 + 50 + 40 + 50,
      FluidLimit.intensity(times, l, flows, 1), $delta
  end
end
