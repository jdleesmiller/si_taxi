module SiTaxi
  #
  # Thrown when something goes wrong in a solver routine -- if possible, the
  # solve routine should avoid throwing out the (partial) answer when it fails.
  #
  class SolveError < RuntimeError
    attr :solver_input
    attr :solver_output
    attr :cause
    def initialize *opts
      @solver_input, @solver_output, @cause = opts 
    end
    def message; cause.message; end
  end

  #
  # Execute the given linear program (in lp-format) in lp_solve and parse the
  # results. Pass +args+ to the lp_solve command; note that if you pass -S0 or
  # S1, this method will fail.
  #
  def lp_solve lp_prog, *args
    begin
      out = disable_warnings {
          IO.popen("lp_solve #{args.join(' ')}", 'r+') {|p|
          p.puts lp_prog
          p.close_write
          p.readlines
        }
      }

      # Return codes appear to correspond to return values of solve(.) API call.
      status = nil
      case $?.exitstatus
      when 0
        status = :OPTIMAL
      when 1
        status = :SUBOPTIMAL
      when 13
        status = :NOFEASFOUND
      else
        raise "lp_solve failed with exit status #{$?.exitstatus}" 
      end

      out_i = 0...out.size
      obj_i = out_i.find{|i|out[i].strip=~/^Value of objective function:(.*)$/}
      raise "can't find objective" unless obj_i
      objective_value = $1.strip.to_f

      vars_i = out_i.find{|i|out[i].strip=~/^Actual values of the variables:$/}
      raise "can't find variables" unless vars_i
      variable_values = {}
      i = vars_i + 1
      while i < out.size && out[i].strip.size > 0
        raise "bad output #{i}" unless out[i]=~/(\S+)\s+(\S+)/
          variable_values[$1.strip] = $2.strip.to_f
        i += 1
      end

      [status, objective_value, variable_values, out]
    rescue
      raise SolveError.new(lp_prog, out.join, $!)
    end
  end
end

