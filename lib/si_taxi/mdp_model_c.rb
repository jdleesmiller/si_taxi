module SiTaxi
  class MDPStateC
    include FiniteMDP::VectorValued

    def initialize queue, inbound
      @queue, @inbound = queue, inbound
    end

    attr_reader :queue, :inbound 

    def num_veh_inbound
      inbound.map(&:size)
    end
    
    def num_veh_at
      inbound.map {|inb|
        count = 0
        count += 1 while inb[count] == 0
        count
      }
    end

    def num_veh
      num_veh_inbound.inject(:+)
    end

    #
    # Return a new state that is the result of
    #
    def transition queue_change, m, trip_time
      #puts "m: #{m.inspect}"
      # move vehicles according to m
      n = inbound.size
      new_queue = (0...n).map {|i| queue[i] + queue_change[i]}
      new_inbound = inbound.map {|inb| inb.dup}
      (0...n).each do |i|
        (0...n).each do |j|
          m_ij = m[j,i] # column major
          if m_ij > 0
            #puts "i: #{i}, j: #{j}, m_ij: #{m_ij}"
            raise "nonzero diagonal" if i == j
            shifted = new_inbound[i].shift(m_ij)
            raise "moved vehicle too early" unless shifted.all?(&:zero?)
            new_inbound[j].push(*[trip_time[i][j]]*m_ij)
            new_inbound[j].sort!
          end
        end
      end

      # move vehicles closer to their destinations
      new_inbound.each do |inb|
        inb.map! {|inb_i| inb_i == 0 ? 0 : inb_i - 1 }
      end

      new_state = MDPStateC.new(new_queue, new_inbound)

      # sanity checks
      raise "negative queue" if new_state.queue.any? {|qi| qi < 0}
      raise "num_veh not conserved" if new_state.num_veh != self.num_veh 

      new_state
    end

    def inspect
      "[" + ("%3d"*queue.size) % queue + "  |" +
        inbound.map{|inb| inb.join(' ')}.join('|') + "]"
    end

    def <=> other
      self.inspect <=> other.inspect
    end

    def to_a
      (queue + inbound.map(&:size) + inbound).flatten
    end
  end

  class MDPModelC
    include FiniteMDP::Model

    #
    # @param [Array<Array<Float>>] demand
    #
    def initialize trip_time, num_veh, demand, queue_max_nominal
      @trip_time = trip_time
      @num_veh = num_veh
      @demand = ODMatrixWrapper.new(demand)

      # convenient to set queue_max[i] = 0 if there is no demand out
      demand_out = NArray[*demand].sum(0)
      @queue_max = NArray[*[queue_max_nominal]*num_stations]
      @queue_max[demand_out.eq(0)] = 0

      # maximum time for j is the max_i T_ij
      @max_time = NArray[trip_time].max(1).to_a.first

      # used to memoize in next_states
      @next_states = {}
      @transition_probability = Hash.new {0}
    end

    def num_stations
      @trip_time.size
    end

    def state_size
      2 * num_stations + num_veh
    end

    def action_size
      # leaving the diagonal in for convenience
      num_stations**2
    end

    attr_reader :queue_max, :num_veh, :trip_time, :demand, :max_time

    def states
      # list feasible queue lengths
      feas_queues = Utility.mixed_radix_sequence(queue_max.to_a).to_a

      # list feasible numbers of inbound vehicles; the total must sum to the
      # fleet size, but there are no other constraints
      feas_inbound = Utility.integer_partitions(num_veh, num_stations)

      # now the inbound lists; the constraints are:
      #   1) there are inbound[i] entries in the list
      #   2) the etas are in non-descending order
      #   3) the max eta is max_{j}{trip_time[j][i]} - 1
      result = []
      Utility.cartesian_product(feas_queues,
                                feas_inbound).each do |queue, inbound|
        feas_etas = (0...num_stations).map {|i|
          Utility.all_non_descending_sequences(0, max_time[i] - 1, inbound[i])
        }
        Utility.cartesian_product(*feas_etas).each do |eta|
          result << MDPStateC.new(queue, eta)
        end
      end
      result
    end

    def actions state
      num_free = state.queue.zip(state.num_veh_at).map {|qi, vi|
        [vi - qi, 0].max
      }
      SiTaxi.all_square_matrices_with_row_sums_lte(num_free).map {|data|
        NArray[*data].reshape!(num_stations, num_stations)
      }
    end

    def next_states state, action
      #puts "STATE: #{state.inspect}"
      #puts "ACTION: #{action.inspect}"
      # easier to build the transition probabilities at the same time
      result = @next_states[[state, action]]
      unless result
        result = []

        num_queued    = NArray[*state.queue]
        num_veh_at    = NArray[*state.num_veh_at]
        num_veh_moved = action.sum(0)

        max_pax = (queue_max - num_queued) + (num_veh_at - num_veh_moved)
        #puts "max_pax: #{max_pax.inspect}"
        raise "negative max_pax: #{max_pax.inspect}" unless (max_pax >= 0).all?
        Utility.mixed_radix_sequence(max_pax.to_a).each do |num_pax|
          # num_pax[i] is the number of new passengers at i; we only need to
          # generate destinations for those that are served
          num_served = (0...num_stations).map {|i|
            [(num_veh_at - num_veh_moved)[i], num_queued[i] + num_pax[i]].min}
          num_queued_change = (0...num_stations).map {|i|
            num_pax[i] - num_served[i]}

          #puts "-"
          #p num_pax
          #p num_served
          #p num_queued_change 

          # work out probability of given numbers of new pax arrivals
          pr_pax = (0...num_stations).map {|i|
            pr_i  = demand.poisson_origin_pmf(i, num_pax[i])
            pr_i += demand.poisson_origin_cdf_complement(i, num_pax[i]) if
              num_queued[i] + num_queued_change[i] == queue_max[i]
            pr_i
          }.inject(:*)
          raise "pr_pax > 1" if pr_pax > 1
          #puts "pr_pax: #{pr_pax}"

          # now need destinations for served passengers
          #puts "num_served: #{num_served}"
          SiTaxi.all_square_matrices_with_row_sums(num_served).each do |ov|
            occup = NArray[*ov].reshape!(num_stations, num_stations)
            new_state = state.transition(
              num_queued_change, action + occup, trip_time)

            # sanity checks
            raise "queue too long" if
              (0...num_stations).any?{|i| new_state.queue[i] > queue_max[i]}

            pr_od = (0...num_stations).map {|i|
              demand.multinomial_trip_pmf(i, occup[true,i].to_a)
            }.inject(:*)

            if pr_od > 1
              puts "pr_od: #{pr_od}"
              p num_served
              p occup
              p (0...num_stations).map {|i|
                p occup[true,i]
                p demand.multinomial_trip_pmf(i, occup[true,i].to_a)
              }
            end
            raise "pr_od > 1" if pr_od > 1

            result << new_state
            #puts "new_state: #{new_state.inspect}"

            # note that multiple transitions can lead to the same state, so we
            # have to accumulate probabilities
            pr = pr_pax * pr_od
            @transition_probability[[state, action, new_state]] += pr
          end
        end
        @next_states[[state, action]] = result.uniq!
      end
      result
    end

    def transition_probability state, action, next_state
      # computed in next_states, which should be called first
      @transition_probability[[state, action, next_state]]
    end

    def reward state, action, next_state
      -state.queue.inject(:+)
    end
  end
end

