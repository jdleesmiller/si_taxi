require 'test/si_taxi_helper'

class DataFilesTest < Test::Unit::TestCase
  include SiTaxi

  context "ATS/CityMobil airport case study" do
    setup do
      data_dir = File.join(File.dirname(__FILE__), 'data')
      @atscm_name = File.join(data_dir, 'airport_case_study.atscm')

      # read in the OD matrix copied out of the sim, for checking
      @ref_demand, @ref_names = DataFiles.read_annotated_od_matrix(
        File.read(File.join(data_dir, 'airport_case_study_demand_matrix.txt')))
    end

    should "read ATS/CityMobil file, save in graphml, and read it back" do 
      network, demand = DataFiles.read_atscm_file(@atscm_name)

      # make sure we got the reference demand back
      assert_equal @ref_names,  network.stations.map{|s| s.label}
      assert_equal @ref_demand, demand
      assert_equal 458, NArray[*demand].sum
      assert network.width < network.height # taller than it is wide

      # save the network to graphml
      io = StringIO.new
      network.print_graphml(io)

      # read it back in
      new_network = DrawableNetwork.from_graphml(io.string)
      assert_equal @ref_names, new_network.stations.map{|s| s.label}
      assert_equal network.nodes, new_network.nodes
      assert_equal network.dist_net.edges, new_network.dist_net.edges
      assert_equal network.time_net.edges, new_network.time_net.edges

      assert_equal network.bbox, new_network.bbox
      assert_equal network.width, new_network.width
      assert_equal network.height, new_network.height
    end
  end
end

