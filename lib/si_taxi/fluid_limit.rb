module SiTaxi::FluidLimit
  include SiTaxi::LPSolve

  module_function

  #
  # Solve linear program to minimize the total number of concurrent empty
  # vehicles; computes the resulting empty vehicle flows.
  # 
  # The assumptions here are that there is no congestion on the line or in
  # stations, and that the demand matrix is in vehicle trips per unit time (i.e.
  # there is no allowance for ride sharing if the demand matrix is in passengers
  # per unit time).
  #
  # @param [Array<Array<Numeric>>] od_time trip times
  #
  # @param [Array<Array<Numeric>>] od_demand demand, in units appropriate
  # for the trip times
  #
  # @return [Array<Array<Float>>] computed ev flows, in the same units as the
  # od_demand 
  #
  def solve_fluid_limit_lp od_time, od_demand
    # Solve linear program to find required number of empty vehicles.
    lp_prog = make_fluid_limit_lp(od_time, od_demand)
    status, num_empty_veh, ev_flows = SiTaxi::LPSolve::lp_solve(lp_prog)

    # Recover the ev flows as a matrix.
    # Sometimes rounding errors give us very small negatives.
    zm = (0...(od_demand.size)).to_a
    ev_flows = zm.map{|i| zm.map{|j|
      eij = ev_flows["y#{i}_#{j}"] || 0
      raise "large negative e_#{i},#{j} = #{eij}" if eij < -1e-4
      [eij, 0].max
    }}

    ev_flows
  end

  #
  # Number of vehicles 
  #
  # @param [Array<Array<Numeric>>] od_time trip times
  #
  # @param [Array<Array<Numeric>>] od_occup vehicle flows, in vehicles per unit
  #        time (in time units appropriate for od_time)
  #
  # @param [Array<Array<Numeric>>] od_empty empty vehicle flows, in vehicles per
  #        unit time (in time units appropriate for od_time)
  #
  # @param [Numeric] num_veh number of vehicles; positive
  #
  # @return [Float] non-negative 
  #
  def fluid_limit_intensity od_time, od_occup, od_empty, num_veh
    od_time = NArray[*od_time].to_f
    od_occup = NArray[*od_occup].to_f
    od_empty = NArray[*od_empty].to_f

    (od_time * (od_occup + od_empty)).sum / num_veh.to_f
  end

  #
  # Build a tensor tau with
  #   tau[i][j][k] = od_time[i][j] + od_time[j][k]
  # Each such entry represents one possible vehicle trip occupied from i to j
  # and then empty from j to k.
  #
  # @param [Array<Array<Numeric>>] od_time trip times
  #
  # @return [Array<Array<Array<Numeric>>>]
  #
  def transaction_time_tensor od_time
    t = NArray[*od_time]
    n = t.shape[0]
    tau = NArray.new(t.typecode, n, n, n)
    for k in 0...n
      tau[true,true,k] = t + t[[k,k,k],true].transpose(1,0)
    end
    tau.to_a
  end

  #
  # NB: results may be misleading if the od_times used to compute od_empty did
  # not satisfy the strict triangle inequality. Without the strict triangle
  # inequality, the solver may decide to push flow from A to B and then B to C,
  # instead of just pushing from A to C. The calculations here assume that there
  # is only one empty trip following on from each occupied trip, so we
  # underestimate the true empty trip time in the former case.
  #
  # We could potentially extend the model with a probability of a second empty
  # trip: in the example above, if B has both inbound and outbound empty
  # vehicle flow, this should add to the expected empty trip time from A. 
  #
  # The real model here is a random walk model: after a trip to j, the vehicle
  # may do an occupied trip to some other station or an empty trip to some other
  # station; in the latter case, it may then do another empty trip. What we
  # really want for the service time distribution is the length of the random
  # *empty* walk. But, when od_empty is computed using the fluid limit LP and
  # the travel times satisfy the triangle inequality, it should always be a
  # walk of length 1, because no station should have both inbound and outbound
  # empty vehicle flow (always cheaper to go direct).
  #
  # @param [Array<Array<Numeric>>] od_occup vehicle flows, in vehicles per unit
  #        time (in whatever time units you choose)
  #
  # @param [Array<Array<Numeric>>] od_empty empty vehicle flows, in vehicles per
  #        unit time (in whatever time units you choose)
  #
  def transaction_probability_tensor od_occup, od_empty
    d = NArray[*od_occup]
    x = NArray[*od_empty]
    raise "dimensions do not match" if d.shape != x.shape
    n = d.shape[0]

    # normalize d by total demand, because we want the (unconditional)
    # probability of a trip from i to j
    d.div!(d.sum)
    
    # x needs more work; first, patch up
    
    # for x, however, we want the probability of an empty trip from j to k;
    # that is, we want the probability of a trip to station k, conditional on
    # starting at station j; so, here we normalise by row sums
    x.div!(x.sum(0))

    # the rows of x need not sum to 1, so 

    tau = NArray.new(t.typecode, n, n, n)
    for k in 0...n
      tau[true,true,k] = t + t[[k,k,k],true].transpose(1,0)
    end
    tau
  end

  #
  # Write linear program (in lp-format for lp_solve) to minimize the total
  # number of concurrent empty vehicles.
  #
  # @param [Array<Array<Numeric>>] od_time trip times
  #
  # @param [Array<Array<Numeric>>] od_demand demand, in units appropriate
  # for the trip times
  #
  # @return [String] lp for input to lp_solve
  #
  def make_fluid_limit_lp od_time, od_demand
    t, l = od_time, od_demand
    raise "demand and times must have same size" if l.size != t.size

    zm = (0...(l.size)).to_a

    # Flow conservation constraints.
    # For station i, row i gives the out-flows, and column i gives the in-flows.
    lhss = lp_str_sum(zm) {|i,j| "#{l[i][j]} + y#{i}_#{j}"}
    rhss = lp_str_sum(zm) {|i,j| "#{l[j][i]} + y#{j}_#{i}"}
    flow_cons = lhss.zip(rhss).map{|lhs,rhs| "#{lhs} = #{rhs};"}.join("\n")

    # Flow non-negativity constraints.
    nonneg_cons = zm.product(zm).map{|i,j| "y#{i}_#{j} >= 0;"}.join("\n")

    # Objective function.
    objective = lp_str_sum(zm) {|i,j| "#{t[i][j]} y#{i}_#{j}"}.join(' + ')

    <<LP
min: #{objective};
#{flow_cons}
#{nonneg_cons}
LP
  end

  # Helper method: sum a function of entries of an mxm matrix.
  def lp_str_sum zm
    zm.map {|i| zm.map {|j| yield(i,j)}.join(' + ')}
  end
end
