module SiTaxi
  class BWSim
    #
    # Add num_veh vehicles, one to each station, starting at the given station.
    #
    # @param [Fixnum] num_veh
    #
    # @param [Fixnum] station non-negative
    #
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

    #
    # Park all existing vehicles; as with {#add_vehicles_in_turn}, the vehicles
    # are parked one to a station, starting at the given station.
    #
    # Internally, this destroys and recreates all of the vehicles.
    #
    # @param [Fixnum] station non-negative
    #
    # @return [nil]
    #
    def park_vehicles_in_turn station=0
      num_veh = vehs.size
      vehs.clear
      add_vehicles_in_turn num_veh, station
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

