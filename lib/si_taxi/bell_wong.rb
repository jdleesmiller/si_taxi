module SiTaxi
  class BWSim
    #
    # Add num_veh vehicles, one to each station, starting at the given station.
    #
    # @param [Fixnum] num_veh
    # @param [Fixnum] station non-negative
    # @return [nil]
    #
    def add_vehicles_in_turn num_veh, station=0
      raise "no stations defined" if num_stations < 1
      if num_veh > 0
        station = station % num_stations
        vehs << BWVehicle.new(station, station, now)
        add_vehicles_in_turn num_veh - 1, station + 1
      end
      nil
    end
  end

  class BWVehicle
    def inspect
      "(o=#{origin},d=#{destin},a=#{arrive})"
    end
  end

  class BWPax
    def inspect
      "(o=#{origin},d=#{destin},a=#{arrive})"
    end
  end
end

