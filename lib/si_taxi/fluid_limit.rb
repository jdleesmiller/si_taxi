module SiTaxi
  #
  # Solve linear program to minimize the total number of concurrent empty
  # vehicles; computes the resulting empty vehicle flows.
  # 
  # The assumptions here are that there is no congestion on the line or in
  # stations, and that the demand matrix is in vehicle trips per unit time (i.e.
  # there is no allowance for ride sharing if the demand matrix is in passengers
  # per unit time).
  #
  # @param [Array<Array<Numeric>>] od_time_matrix trip times
  #
  # @param [Array<Array<Numeric>>] od_demand_matrix demand, in units appropriate
  # for the trip times
  #
  # @return [Array<Array<Float>>] computed ev flows, in the same units as the
  # od_demand_matrix 
  #
  def solve_fluid_limit_lp od_time_matrix, od_demand_matrix
    # Solve linear program to find required number of empty vehicles.
    lp_prog = make_fluid_limit_lp(od_time_matrix, od_demand_matrix)
    status, num_empty_veh, ev_flows = lp_solve(lp_prog)

    # Recover the ev flows as a matrix.
    # Sometimes rounding errors give us very small negatives.
    zm = (0...(od_demand_matrix.size)).to_a
    ev_flows = zm.map{|i| zm.map{|j|
      eij = ev_flows["y#{i}_#{j}"] || 0
      raise "large negative e_#{i},#{j} = #{eij}" if eij < -1e-4
      [eij, 0].max
    }}

    ev_flows
  end

  #
  # Write linear program (in lp-format for lp_solve) to minimize the total
  # number of concurrent empty vehicles.
  #
  # @param [Array<Array<Numeric>>] od_time_matrix trip times
  #
  # @param [Array<Array<Numeric>>] od_demand_matrix demand, in units appropriate
  # for the trip times
  #
  # @return [String] lp for input to lp_solve
  #
  def make_fluid_limit_lp od_time_matrix, od_demand_matrix
    t, l = od_time_matrix, od_demand_matrix
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

  private
  # Helper method: sum a function of entries of an mxm matrix.
  def lp_str_sum zm
    zm.map {|i| zm.map {|j| yield(i,j)}.join(' + ')}
  end
end
