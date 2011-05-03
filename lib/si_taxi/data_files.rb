require 'gratr'

module SiTaxi::DataFiles
  module_function

  include GRATR
  include SiTaxi::Utility

  #
  # Read an origin-destination matrix from a human-readable text file.
  #
  # The format is:
  #  [blank] tab name 1 tab name 2 tab ...
  #  name 1 tab [blank] tab number tab ...
  #  name 2 tab number tab [blank] tab ...
  #  ...
  # (that is, tab delimited with station names on the first row and blank (not
  # zero) entries on the diagonal).
  # Result is a square array-of-arrays matrix with zeros on the diagonal.
  #
  # @param [String] s
  #
  # @return the matrix (array of arrays) and the station names
  #
  def read_annotated_od_matrix s
    vls = s.split(/\n/)

    head = vls[0].rstrip.split(/\t/).map{|name| name.strip}
    raise "bad format (header line)" unless head[0].size == 0
    names = head.drop(1)

    l = vls.drop(1).map {|vl|
      vl = vl.strip
      vl.split(/\t/).drop(1).map{|lij| lij.to_f} if vl != ""
    }.compact

    # The above sometimes misses the bottom-right zero entry.
    l[l.size-1] << 0.0 if l[l.size-1].size < l[0].size

    raise "matrix non-rectangular" unless l.all?{|li| li.size == l[0].size}

    [l, names]
  end

  #
  # Read in an ATS/CityMobil file as a {DrawableNetwork} and a demand matrix.
  #
  def read_atscm_file atscm_file
    require 'fileutils'
    require 'tmpdir'

    raise "file not found: #{atscm_file}" unless File.exists?(atscm_file)
    atscm_base = File.basename(atscm_file)

    network, demand = nil
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.cp atscm_file, '.'
        system "unzip -qq #{atscm_base}"
        raise "failed to unzip: #{$?.inspect}" unless $?.exitstatus == 0

        raise "could not find atscm.xml" unless File.exists?('atscm.xml')
        network = SiTaxi::DrawableNetwork.from_atscm_xml('atscm.xml')

        demand = read_atscm_demand_from_xml(network.stations, 'atscm.xml')
      end
    end

    [network, demand]
  end

  #
  # Read OD matrix from ATS/CityMobil file.
  #
  # @param [Array<DrawableNetwork::StationNode>] stations; each must have a node
  #        id and an index; the rows and columns of the returned matrix are
  #        ordered by index
  #
  # @param [String] file_name for the XML inside the file (the .atscm file must
  #        be unzipped before this function can read it)
  #
  # @return [Array<Array<Float>>] array-of-arrays matrix with entries in trips
  #        per hour and zeros on the diagonal
  #
  def read_atscm_demand_from_xml stations, file_name
    doc = Hpricot.XML(File.new(file_name))

    od = (0...stations.size).map{[]}
    (doc/"atscm/odm/d").each do |e|
      sn_id = e['source'].to_i
      dn_id = e['target'].to_i
      sn_index = stations.find{|s| s.id == sn_id}.index
      dn_index = stations.find{|s| s.id == dn_id}.index
      od[sn_index][dn_index] = e['lambda'].to_f
    end

    # zero out the diagonal
    for i in 0...stations.size
      raise "got an entry for the diagonal on row #{i}" if od[i][i]
      od[i][i] = 0.0
    end

    od
  end
end
