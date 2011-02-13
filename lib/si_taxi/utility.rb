module SiTaxi::Utility
  module_function

  #
  # One way to encode a sparse matrix is as a hash of hashes; another way is to
  # use an array of arrays. This method orders the keys of +h+ in order to
  # produce the array-of-arrays matrix; this is perhaps best illustrated with an
  # example.
  #
  # Example:
  #  h = {'a'=>{'a'=>1, 'c'=>3}, 'b'=>{'a'=>4, 'b'=>5, 'c'=>6}, 'c'=>{'b'=>8}}
  # is converted to
  #  [[1, z, 3],
  #   [4, 5, 6],
  #   [z, 8, z]]
  # where +z+ is used where an element is missing. Note that the keys in +h+
  # will usually be numeric, denoting rows and columns of the sparse matrix.
  #
  def hash_of_hashes_to_array_of_arrays h, z=nil
    ks = h.keys.sort
    ks.map{|k0| ks.map{|k1| h[k0][k1] || z}}
  end
end
