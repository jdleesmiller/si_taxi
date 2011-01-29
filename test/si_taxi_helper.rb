require "test/unit"
require "shoulda"
require "si_taxi"

#
# Two station ring network.
#   +->-10->-+
#  (0)      (1)
#   +-<-20-<-+
#
TRIP_TIMES_2ST_RING_10_20 = [[0,10],
                             [20,0]]

#
# Three station ring network.
#       (0)
#      /   \
#     30    10
#    /        \
#  (2)-<-20-<-(1)
#
TRIP_TIMES_3ST_RING_10_20_30 = [[  0, 10, 30],
                                [ 50,  0, 20],
                                [ 30, 40,  0]]

module BellWongTestHelper
  include SiTaxi

  #
  # Tolerance for floating point comparison.
  #
  $delta = 1e-6

  #
  # Create sim with given trip times and call init.
  #
  def setup_sim trip_time
    @sim = BWSim.new
    @sim.trip_time = trip_time
    @sim.init
    nil
  end

  #
  # Create vehicles at given positions.
  #
  def put_veh_at *init_veh_pos
    @sim.vehs.clear
    init_veh_pos.each do |i|
      if i.is_a? Array
        @sim.vehs << BWVehicle.new(*i)
      else
        @sim.vehs << BWVehicle.new(i,i,0)
      end
    end
  end

  #
  # Create passenger request and give it to the sim.
  #
  def pax origin, destin, arrive
    @sim.handle_pax BWPax.new(origin, destin, arrive)
  end

  #
  # Assert that there is a vehicle going from origin to destin, arriving at
  # destin.
  # 
  def assert_veh origin, destin, arrive, index=nil
    vehs = @sim.vehs
    vehs = [vehs[index]] if index
    v = vehs.find {|vi|
      vi.origin == origin && vi.destin == destin && vi.arrive == arrive}
    assert v, "no veh w/ o=#{origin}, d=#{destin}, a=#{arrive}\n"\
              "#{@sim.vehs.map(&:inspect)}"
  end

  #
  # Assert that we get the given pax waiting time histograms (per station).
  #
  def assert_wait_hists *hists
    if hists.size > 1
      raise unless hists.size == @sim.num_stations
      for i in 0...hists.size
        case hists[i]
        when Array then
          assert_equal hists[i], @sim.pax_wait[i].to_a
        when Hash then
          assert_equal hists[i], @sim.pax_wait[i].to_h
        else
          raise "bad type for hist #{i}: #{hists[i]}"
        end
      end
    else
      raise "TODO aggregate all stations together?"
    end
  end

  #
  # Assert that we get the given queue length histograms (per station).
  #
  def assert_queue_hists *hists
    assert_equal hists, @sim.queue_len.map{|h| h.to_a}
  end
end
