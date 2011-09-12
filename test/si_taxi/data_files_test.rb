require 'si_taxi/test_helper'

class DataFilesTest < Test::Unit::TestCase
  include SiTaxi

  context "ATS/CityMobil airport case study" do
    setup do
      data_dir = File.join(File.dirname(__FILE__), 'data')
      @atscm_name = File.join(data_dir, 'airport_case_study.atscm')

      # read in the OD matrix copied out of the sim, for checking
      @ref_demand, @ref_names = DataFiles.read_annotated_od_matrix(
        File.read(File.join(data_dir, 'airport_case_study_demand_matrix.txt')))

      # read in trip times copied out of the sim, for checking
      @ref_times, ref_names_times = DataFiles.read_annotated_od_matrix(
        File.read(File.join(data_dir, 'airport_case_study_trip_times.txt')))

      assert_equal @ref_names, ref_names_times
    end

    should "read ATS/CityMobil file, save in graphml, and read it back" do 
      network, demand = DataFiles.read_atscm_file(@atscm_name)

      # make sure we got the reference demand back
      assert_equal @ref_names,  network.stations.map{|s| s.label}
      assert_equal @ref_demand, demand
      assert_equal 458, NArray[*demand].sum
      assert network.width < network.height # taller than it is wide

      # check station-to-station trip times; these won't be exactly the same,
      # because we are ignoring curvature
      ref_times = NArray[*@ref_times]
      trip_times = NArray[*network.station_trip_times]
      assert((ref_times - trip_times).abs.max < 5) # seconds

      # save the network to graphml
      io = StringIO.new
      network.print_graphml(io)

      # read it back in
      new_network = DrawableNetwork.from_graphml(io.string)
      assert_equal @ref_names, new_network.stations.map{|s| s.label}
      assert_equal network.nodes, new_network.nodes
      assert_equal network.dist_net.edges, new_network.dist_net.edges
      assert_equal network.time_net.edges, new_network.time_net.edges

      # should get the same station-to-station trip times back
      new_trip_times = NArray[*new_network.station_trip_times]
      assert((trip_times - new_trip_times).abs.max < $delta)

      assert_equal network.bbox, new_network.bbox
      assert_equal network.width, new_network.width
      assert_equal network.height, new_network.height
    end

    should "read and save reference demand matrix" do
      io = StringIO.new
      DataFiles.print_annotated_od_matrix(@ref_demand, @ref_names, io)

      new_demand, new_names = DataFiles.read_annotated_od_matrix(io.string)

      assert_equal @ref_demand, new_demand 
      assert_equal @ref_names, new_names 
    end
  end
end

