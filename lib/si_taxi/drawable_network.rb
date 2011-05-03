require 'gratr'

#
# Network with enough data to draw it in the plane.
#
class SiTaxi::DrawableNetwork

  include GRATR
  include SiTaxi::Utility

  module Node
    def euclidean_dist node
      dx, dy = self.x - node.x, self.y - node.y
      Math::sqrt(dx*dx + dy*dy)
    end
  end

  StationNode = Struct.new(:id, :x, :y, :index, :label)
  StructuralNode = Struct.new(:id, :x, :y)
  class StationNode; include Node; end
  class StructuralNode; include Node; end

  #
  # Digraph including both station and structural nodes with edge weights
  # set to travel times in seconds.
  #
  attr_reader :time_net

  #
  # Digraph including both station and structural nodes with edge weights set
  # to distances between nodes.
  #
  attr_reader :dist_net

  #
  # Shortest-paths successor matrix for both structural and station nodes.
  #
  attr_reader :time_succ

  # Bounding box of network, in meters.
  # @return [x0, y0, x1, y1] where (x0, y0) is the top left corner and (x1,
  # y1) is the bottom right corner.
  def bbox
    vx = nodes.map {|n| n.x}
    vy = nodes.map {|n| n.y}
    [vx.min, vy.max, vx.max, vy.min]
  end

  # Width of network, in meters.
  def width
    vx = nodes.map {|n| n.x}
    vx.max - vx.min
  end

  # Height of network, in meters.
  def height
    vy = nodes.map {|n| n.y}
    vy.max - vy.min
  end

  # Structural and station nodes.
  def nodes
    dist_net.vertices
  end

  # Station nodes in order by node.index.
  attr_reader :stations

  # 
  # Edge speeds.
  # 
  # @return [Hash<Arc, Float>]
  #
  attr_reader :speeds

  # Find a vehicle's position in space by tracing through the network.
  def vehicle_xy origin_index, destin_index, depart, now
    t = depart
    n = stations[origin_index]
    d = stations[destin_index]
    while n != d
      n_succ = time_succ[n][d]
      e = Arc[n, n_succ]
      t_e = time_net[e]

      t_succ = t + t_e
      if t_succ > now
        # Vehicle is on this edge (e) from n to n_succ, which is a line.
        progress = (now - t) / t_e
        dx_e = n_succ.x - n.x
        dy_e = n_succ.y - n.y
        x = n.x + progress * dx_e
        y = n.y + progress * dy_e
        return [x, y]
      end

      n = n_succ
      t = t_succ
    end
    return [d.x, d.y] # at destin
  end

  #
  # Create and do shortest path calcs.
  #
  # @param [Boolean] skip_trip_times, because this is depressingly slow
  #
  def initialize dist_net, time_net, speeds, skip_trip_times=false
    @dist_net, @time_net, @speeds = dist_net, time_net, speeds
    @stations = dist_net.vertices.select {|n| n.is_a?(StationNode)}.
      sort_by {|n| n.index}
    trip_times, @time_succ = time_net.floyd_warshall unless skip_trip_times
  end

  # Compute node-to-node times by dividing distance by given speeds.
  def self.time_net_from_dist_net dist_net, speeds
    time_net = Digraph[*dist_net.edges]
    for arc in time_net.edges
      time_net[arc] /= speeds[arc]
    end
    time_net
  end

  #
  # Read network from an ATS/CityMobil file.
  #
  # Curvature is ignored.
  #
  # @param [String] file_name for the XML inside the file (the .atscm file must
  #        be unzipped before this function can read it)
  #
  # @param [Numeric] speed assumed speed for each track segment, in meters per
  #        second (CityMobil doesn't currently save the speeds)
  #
  # @return [DrawableNetwork]
  #
  def self.from_atscm_xml file_name, speed=10, skip_trip_times=false
    doc = Hpricot.XML(File.new(file_name))

    # read structural nodes; treat depots as structural
    nodes = {}
    (doc/"atscm/nodes/{node|depot}").each do |e|
      id = e['id'].to_i
      nodes[id] = StructuralNode.new(id, e['x'].to_f, e['y'].to_f)
    end

    # read station nodes
    station_index = -1
    (doc/"atscm/nodes/station").each do |e|
      id = e['id'].to_i
      nodes[id] = StationNode.new(id, e['x'].to_f, e['y'].to_f,
                                  station_index += 1, e['name'])
    end

    # read edges
    dist_net = Digraph[]
    dist_net.add_vertices!(*nodes.values)
    (doc/"atscm/tracks/track").each do |e|
      sn_id = (e['source']).to_i
      dn_id = (e['target']).to_i
      sn, dn = nodes[sn_id], nodes[dn_id]
      dist_net.add_edge! sn, dn, sn.euclidean_dist(dn)
    end

    # we have only one speed; use a hash that returns this speed for all keys
    speeds = Hash.new(speed)
    self.new(dist_net, time_net_from_dist_net(dist_net, speeds), speeds,
             skip_trip_times)
  end

  #
  # Read parameters from graphml string.
  # Does not validate; assumes that the attribute *keys* (not just attr.names)
  # are x, y and label for nodes and speed for edges.
  # Assumes that nodes are listed in order by id, and the station nodes are
  # listed in the same order in which they appear in the OD matrix.
  #
  def self.from_graphml graphml, skip_trip_times=false
    require 'hpricot'
    doc = Hpricot.XML(StringIO.new(graphml))

    # The order of nodes is important; Hash in Ruby 1.9 preserves insert order.
    nodes = {}
    station_index = -1
    (doc/'graph/node').each do |e|
      id = e[:id].to_i
      x = (e % 'data[@key=x]').inner_text.to_f
      y = (e % 'data[@key=y]').inner_text.to_f
      label = (e % 'data[@key=label]')
      n = if label
            StationNode.new(id, x, y, station_index += 1, label.inner_text)
          else
            StructuralNode.new(id, x, y)
          end
      nodes[id] = n
    end

    # Arcs. Remember speeds so we can get arc traversal times.
    dist_net = Digraph[]
    dist_net.add_vertices!(*nodes.values)
    speeds = {}
    (doc/'graph/edge').each do |e|
      sn_id = e[:source].to_i
      dn_id = e[:target].to_i
      speed = (e % 'data[@key=speed]').inner_text.to_f

      sn, dn = nodes[sn_id], nodes[dn_id]
      dist_net.add_edge! sn, dn, sn.euclidean_dist(dn)
      speeds.merge! Arc[sn,dn] => speed
    end

    self.new(dist_net, time_net_from_dist_net(dist_net, speeds), speeds,
             skip_trip_times)
  end

  #
  # Representation of network in GraphML format.
  #
  # The graphml includes coordinates (x and y, in meters) for all nodes; station
  # nodes have a label; structural nodes do not. Edges have an average speed, in
  # meters per second.
  #
  # To plot in R:
  #   library(igraph)
  #   g <- read.graph('a_file.graphml',format='graphml')
  #   plot(g, layout=matrix(c(V(g)$x,V(g)$y),length(V(g)),2))
  #
  def print_graphml io=$stdout
    io.puts <<PREAMBLE
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns"  
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns
      http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">
  <key id="x" for="node" attr.name="x" attr.type="double" />
  <key id="y" for="node" attr.name="y" attr.type="double" />
  <key id="label" for="node" attr.name="label" attr.type="string" />
  <key id="speed" for="edge" attr.name="speed" attr.type="double" />
  <graph id="G" edgedefault="directed">
PREAMBLE
    for node in nodes.sort_by{|n| n.id}
      io.puts "<node id=\"#{node.id}\">"
      io.puts "  <data key=\"x\">#{node.x}</data>"
      io.puts "  <data key=\"y\">#{node.y}</data>"
      io.puts "  <data key=\"label\">#{node.label}</data>" rescue nil
      io.puts "</node>"
    end

    for arc in dist_net.edges
      io.puts "<edge source=\"#{arc.source.id}\" target=\"#{arc.target.id}\">"
      io.puts "  <data key=\"speed\">#{speeds[arc]}</data>"
      io.puts "</edge>"
    end
    io.puts <<CLOSING
  </graph>
</graphml>
CLOSING
  end
end

