#
# Build abstract networks. The main abstractions are that they are not spatial
# networks, and that there are no limitations on the in- or out-degrees of their
# nodes (no merge/diverge restrictions).
#
# Example:
#   ring_network(1, 2, 3).write_to_graphic_file('png','ring1')
#   star_network([1,2,3], [3,2,1]).write_to_graphic_file('png','star1')
#
#
require 'gratr'

module SiTaxi::AbstractNetworks
  module_function

  include GRATR
  include SiTaxi::Utility

  #
  # Create a ring network with the given link traversal times.
  # The first node is numbered 0.
  #
  def ring_network *edge_weights
    n = edge_weights.size
    e = (0...n).map{|i| [i, (i+1) % edge_weights.size]}
    raise "must have at least two edges in a ring" if e.size < 2
    g = Digraph[*e.flatten]
    e.zip(edge_weights).each do |ei,wi|
      g[Arc.new(*ei)] = wi
    end
    g
  end

  #
  # Create a star network with the given link traversal times.
  # The central node is numbered 0.
  #
  # Example:
  #   star_network([1,2,3], [3,2,1])
  # creates a star with two three-station rings, joined at a single node, which
  # we number 0; the ring traversal times are as given to ring_network.
  #
  def star_network *edge_weights
    i = 1 # non-center node index counter
    g = Digraph.new
    edge_weights.each do |ring_edges|
      n = ring_edges.size
      raise "must have at least two edges in a ring" if n < 2
      g.add_edge!(0,i,ring_edges[0])
      ring_edges[1...(n-1)].each do |w|
        g.add_edge!(i,i+1,w)
        i += 1
      end
      g.add_edge!(i,0,ring_edges[n-1])
      i += 1
    end
    g
  end

  #
  # Create a regular grid network with stations on corners and bidirectional
  # links between adjacent stations. The grid is axes-aligned, with +nodes_x+
  # nodes along x and +nodes_y+ nodes along y. The result is a Digraph with
  # edges between adjacent nodes in the grid (even though we could use an
  # undirected graph).
  #
  def grid_network_bidirectional edge_weight, nodes_x, nodes_y
    raise "not enough nodes" if nodes_x < 2 || nodes_y < 2

    g = Digraph.new

    # Add horizontals.
    for i in 0...nodes_y
      for j in 0...nodes_x
        n = i*nodes_x + j
        g.add_edge!(n,n+1,edge_weight) if j+1 < nodes_x
        g.add_edge!(n,n-1,edge_weight) if j > 0
      end
    end

    # Add verticals.
    for j in 0...nodes_x
      for i in 0...nodes_y
        n = i*nodes_x + j
        g.add_edge!(n,n+nodes_x,edge_weight) if i+1 < nodes_y
        g.add_edge!(n,n-nodes_x,edge_weight) if i > 0
      end
    end

    g
  end

  #
  # Array-of-arrays matrix of network trip times; every node in +g+ is
  # assumed to be a station, and the edge weights are assumed to be
  # station-to-station times.
  #
  def network_trip_times g
    times = hash_of_hashes_to_array_of_arrays(g.floyd_warshall[0])
    (0...(times.size)).each do |i| times[i][i] = 0; end
    times
  end
end
