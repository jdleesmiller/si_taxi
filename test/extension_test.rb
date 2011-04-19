require 'test/si_taxi_helper'

class CommonTest < Test::Unit::TestCase
  def assert_narray_close exp, obs
    assert exp.shape == obs.shape && ((exp - obs).abs < $delta).all?,
      "#{exp.inspect} expected; got\n#{obs.inspect}"
  end

  def test_narray_cumsum
    # Degenerate case: dimension 0.
    assert_equal NArray.float(0), NArray.float(0).cumsum
    assert_equal NArray.int(0),   NArray.int(0).cumsum

    # Single-element vector.
    v = NArray.float(1).fill!(42)
    assert_equal v, v.cumsum
    assert_equal v.typecode, v.cumsum.typecode
    v = NArray.int(1).fill!(42)
    assert_equal v, v.cumsum
    assert_equal v.typecode, v.cumsum.typecode

    # Vector.
    v = NArray.float(2).indgen!
    assert_narray_close NArray[   0.0,  1.0], v.cumsum
    v = NArray.float(3).indgen! + 1
    assert_narray_close NArray[   1.0,  3.0,  6.0], v.cumsum
    assert_equal v, v.cumsum(1) # dim 1 doesn't exist; cumsum has no effect

    # Matrix.
    m = NArray.float(3,2).indgen! + 1
    assert_narray_close NArray[[  1.0,  3.0,  6.0],
                               [  4.0,  9.0, 15.0]], m.cumsum
    assert_narray_close NArray[[  1.0,  2.0,  3.0],
                               [  5.0,  7.0,  9.0]], m.cumsum(1)
    assert_equal m, m.cumsum(2) # dim 2 doesn't exist; cumsum has no effect

    # Array with dim 3 with one extra dim.
    d3 = NArray.int(3,2,1).indgen! - 1
    assert_equal NArray[[[  -1,  -1,   0],
                         [   2,   5,   9]]], d3.cumsum(0)
    assert_equal NArray[[[  -1,   0,   1],
                         [   1,   3,   5]]], d3.cumsum(1)
    assert_equal NArray[[[  -1,   0,   1],
                         [   2,   3,   4]]], d3.cumsum(2)
    assert_equal NArray[[[  -1,   0,   1],
                         [   2,   3,   4]]], d3.cumsum(3) # dim 3 doesn't exist
  end

  def test_narray_tile
    # Degenerate case: tile on a dimension 0 array.
    assert_equal NArray.float(0), NArray.float(0).tile
    assert_equal NArray.float(0), NArray.float(0).tile(0)
    assert_equal NArray.float(0), NArray.float(0).tile(0,0)
    assert_equal NArray.float(0), NArray.float(0).tile(1,1)

    # Degenerate case: tile 0 times on some dimension.
    assert_equal NArray.float(0), NArray.float(1).tile(0)
    assert_equal NArray.float(0), NArray.float(1).tile(0,0)
    assert_equal NArray.float(0), NArray.float(2,3).tile(0)
    assert_equal NArray.float(0), NArray.float(3,4,2).tile(1,2,0)
    assert_equal NArray.float(0), NArray.float(3,4,2).tile(1,0,2)

    # Degenerate case: tile with no args returns copy of original.
    assert_equal NArray.float(1).fill!(1), NArray.float(1).fill!(1).tile
    assert_equal NArray.float(1,2).indgen!, NArray.float(1,2).indgen!.tile

    # Tile a scalar.
    assert_equal NArray[1.0, 1.0],
                 NArray.float(1).fill!(1).tile(2) # row vector
    assert_equal NArray[[1.0],
                        [1.0]],
                 NArray.float(1).fill!(1).tile(1,2) # column vector
    assert_equal NArray[[[1.0]],
                        [[1.0]]],
                 NArray.float(1).fill!(1).tile(1,1,2) # add a dimension
    assert_equal NArray[[1.0, 1.0, 1.0],
                        [1.0, 1.0, 1.0]],
                 NArray.float(1).fill!(1).tile(3,2) # matrix

    # Tile a vector.
    v = NArray.float(2).indgen!
    assert_equal NArray[0.0, 1.0, 0.0, 1.0], v.tile(2)
    assert_equal NArray[0.0, 1.0, 0.0, 1.0, 0.0, 1.0], v.tile(3)
    assert_equal NArray[[0.0, 1.0],
                        [0.0, 1.0]], v.tile(1,2)
    assert_equal NArray[[0.0, 1.0],
                        [0.0, 1.0],
                        [0.0, 1.0]], v.tile(1,3)

    # Tile a matrix.
    m = NArray.float(2,3).indgen!
    assert_equal NArray[[0.0, 1.0],
                        [2.0, 3.0],
                        [4.0, 5.0]], m.tile
    assert_equal NArray[[0.0, 1.0, 0.0, 1.0],
                        [2.0, 3.0, 2.0, 3.0],
                        [4.0, 5.0, 4.0, 5.0]], m.tile(2)
    assert_equal m.tile(2), m.tile(2,1)
    assert_equal NArray[[0.0, 1.0],
                        [2.0, 3.0],
                        [4.0, 5.0],
                        [0.0, 1.0],
                        [2.0, 3.0],
                        [4.0, 5.0]], m.tile(1,2)
    assert_equal NArray[[[0.0, 1.0],
                         [2.0, 3.0],
                         [4.0, 5.0]],
                        [[0.0, 1.0],
                         [2.0, 3.0],
                         [4.0, 5.0]]], m.tile(1,1,2)

    # Tile another matrix.
    m = NArray.float(3,2).indgen!
    assert_equal NArray[[0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0]], m.tile
    assert_equal NArray[[0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0, 3.0, 4.0, 5.0]], m.tile(2)
    assert_equal NArray[[0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0],
                        [0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0],
                        [0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0]], m.tile(1,3)
    assert_equal NArray[[0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0, 3.0, 4.0, 5.0],
                        [0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0, 3.0, 4.0, 5.0],
                        [0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
                        [3.0, 4.0, 5.0, 3.0, 4.0, 5.0]], m.tile(2,3)
  end

  def test_narray_sample_pmf
    # Sample from vector.
    v = NArray.float(3).fill!(1)
    v /= v.sum
    assert_equal 0, v.sample_pmf(0,NArray[0.0])
    assert_equal 0, v.sample_pmf(0,NArray[0.333])
    assert_equal 1, v.sample_pmf(0,NArray[0.334])
    assert_equal 1, v.sample_pmf(0,NArray[0.666])
    assert_equal 2, v.sample_pmf(0,NArray[0.667])
    assert_equal 2, v.sample_pmf(0,NArray[0.999])

    # Sample from vector with sum < 1.
    v = NArray[0.5,0.2,0.2]
    assert_equal 0, v.sample_pmf(0,NArray[0.0])
    assert_equal 1, v.sample_pmf(0,NArray[0.5])
    assert_equal 2, v.sample_pmf(0,NArray[0.89])
    assert_equal 2, v.sample_pmf(0,NArray[0.91])

    # Zero at start won't be sampled.
    v = NArray[0.0,0.5,0.5]
    assert_equal 1, v.sample_pmf(0,NArray[0.0])
    assert_equal 1, v.sample_pmf(0,NArray[0.1])
    assert_equal 2, v.sample_pmf(0,NArray[0.9])

    # If all entries are zero, we just choose the last one arbitrarily.
    v = NArray[0.0,0.0,0.0]
    assert_equal 2, v.sample_pmf(0,NArray[0.9])

    # Sample from square matrix.
    m = NArray.float(3,3).fill!(1)
    m /= 3
    assert_equal NArray[0, 0, 0], m.sample_pmf(0, NArray[[0.0], [0.0], [0.0]])
    assert_equal NArray[1, 0, 0], m.sample_pmf(0, NArray[[0.4], [0.0], [0.0]])
    assert_equal NArray[1, 2, 0], m.sample_pmf(0, NArray[[0.4], [0.7], [0.0]])
    assert_equal NArray[0, 0, 0], m.sample_pmf(1, NArray[[0.0, 0.0, 0.0]])
    assert_equal NArray[1, 0, 0], m.sample_pmf(1, NArray[[0.4, 0.0, 0.0]])
    assert_equal NArray[1, 2, 0], m.sample_pmf(1, NArray[[0.4, 0.7, 0.0]])

    # Sample from non-square matrix.
    m = NArray.float(3,2).fill!(1)
    m /= 3
    assert_equal NArray[0, 0], m.sample_pmf(0, NArray[[0.0], [0.0]])
    assert_equal NArray[1, 0], m.sample_pmf(0, NArray[[0.4], [0.0]])
    assert_equal NArray[1, 2], m.sample_pmf(0, NArray[[0.4], [0.7]])

    m = m.transpose(1,0)
    assert_equal NArray[0, 0], m.sample_pmf(1, NArray[[0.0, 0.0]])
    assert_equal NArray[1, 0], m.sample_pmf(1, NArray[[0.4, 0.0]])
    assert_equal NArray[1, 2], m.sample_pmf(1, NArray[[0.4, 0.7]])

    # Sample from a 3D array.
    a = NArray.float(4,3,2).fill!(1)
    a /= 2
    sa = a.sample_pmf(2)
    assert_equal 2, sa.dim
    assert_equal [0, 1], sa.to_a.flatten.uniq.sort
  end

  def test_narray_index_to_subscript
    assert_raises(IndexError) {NArray[].index_to_subscript(0)}

    assert_equal [0], NArray[0].index_to_subscript(0)

    assert_equal [0], NArray[0,0].index_to_subscript(0)
    assert_equal [1], NArray[0,0].index_to_subscript(1)

    assert_equal [0,0], NArray[[0,0]].index_to_subscript(0)
    assert_equal [1,0], NArray[[0,0]].index_to_subscript(1)
    assert_raise(IndexError) {NArray[[0,0]].index_to_subscript(2)}
    assert_raise(IndexError) {NArray[[0,0]].index_to_subscript(3)}
    assert_raise(IndexError) {NArray[[0,0]].index_to_subscript(4)}

    a = NArray.int(2,2).indgen!
    assert_equal [0,0], a.index_to_subscript(0)
    assert_equal [1,0], a.index_to_subscript(1)
    assert_equal [0,1], a.index_to_subscript(2)
    assert_equal [1,1], a.index_to_subscript(3)
    assert_raise(IndexError) { a.index_to_subscript(4) }

    a = NArray.int(2,3).indgen!
    for j in 0...2
      for i in 0...3
        assert_equal [j,i], a.index_to_subscript(a[j,i])
      end
    end

    a = NArray.int(3,2).indgen!
    for j in 0...3
      for i in 0...2
        assert_equal [j,i], a.index_to_subscript(a[j,i])
      end
    end

    a = NArray.int(3,2,4).indgen!
    for j in 0...3
      for i in 0...2
        for h in 0...4
          assert_equal [j,i,h], a.index_to_subscript(a[j,i,h])
        end
      end
    end
  end

  def test_narray_sample
    assert_equal [0], NArray[1.0].sample

    assert_equal [0], NArray[0.5,0.5].sample(NArray[0])
    assert_equal [0], NArray[0.5,0.5].sample(NArray[0.49])
    assert_equal [1], NArray[0.5,0.5].sample(NArray[0.5])
    assert_equal [1], NArray[0.5,0.5].sample(NArray[1.0])

    a = NArray[[0.5,0.5]]
    assert_equal [0,0], a.sample(NArray[0])
    assert_equal [0,0], a.sample(NArray[0.49])
    assert_equal [1,0], a.sample(NArray[0.5])
    assert_equal [1,0], a.sample(NArray[1.0])

    a = NArray[[0.2,0],[0.3,0.2]]
    assert_equal [0,0], a.sample(NArray[0])
    assert_equal [0,0], a.sample(NArray[0.19])
    assert_equal [0,1], a.sample(NArray[0.2]) # not [1,0], which has 0 mass
    assert_equal [1,1], a.sample(NArray[0.5])
    assert_equal [1,1], a.sample(NArray[0.51])

    a = NArray[[[0,0.2],[0.2,0.2]],[[0.1,0.1],[0.1,0.1]]]
    assert_equal [1,0,0], a.sample(NArray[0]) # not [0,0,0], which has 0 mass
    assert_equal [1,0,0], a.sample(NArray[0.1])
    assert_equal [0,1,0], a.sample(NArray[0.21])
    assert_equal [1,1,0], a.sample(NArray[0.41])
    assert_equal [1,1,0], a.sample(NArray[0.59])
    assert_equal [0,0,1], a.sample(NArray[0.61])
    assert_equal [1,0,1], a.sample(NArray[0.71])
    assert_equal [0,1,1], a.sample(NArray[0.81])
    assert_equal [1,1,1], a.sample(NArray[0.91])
    assert_equal [1,1,1], a.sample(NArray[1.0])
  end
end

