require 'test/si_taxi_helper'

class TestSiTaxi < Test::Unit::TestCase
  include TestHelper
  include SiTaxi
  include Utility

  #
  # Tolerance for floating point comparison.
  #
  $delta = 1e-6

  context "natural histogram" do
    setup do
      @h = SiTaxi::NaturalHistogram.new
    end

    should "be empty" do
      assert_equal [], @h.to_a
      assert_equal 0, @h.size
      assert_equal 0, @h.count
      assert_is_nan @h.mean
      assert_is_nan @h.variance
      assert_is_nan @h.sample_variance
      assert_is_nan @h.central_moment(3)
      assert_equal nil, @h.quantile(0)
      assert_equal nil, @h.quantile(0.5)
      assert_equal nil, @h.quantile(1)
    end

    should "work with single zero" do
      @h.increment(0)
      assert_equal [1], @h.to_a
      assert_in_delta 0, @h.mean, $delta
      assert_in_delta 0, @h.variance, $delta
      assert_is_nan @h.sample_variance
      assert_equal 0, @h.quantile(0)
      assert_equal 0, @h.quantile(0.5)
      assert_equal 0, @h.quantile(1)
    end

    should "work with single one" do
      @h.increment(1)
      assert_equal [0,1], @h.to_a
      assert_in_delta 1, @h.mean, $delta
      assert_in_delta 0, @h.variance, $delta
      assert_is_nan @h.sample_variance
      assert_equal 1, @h.quantile(0)
      assert_equal 1, @h.quantile(0.5)
      assert_equal 1, @h.quantile(1)
    end

    should "compute basic stats" do
      @h.accumulate(0, 9)
      @h.accumulate(1, 3)
      @h.accumulate(2, 6);
      @h.accumulate(3, 7);
      @h.accumulate(4, 5);
      @h.accumulate(5, 2);
      @h.accumulate(6, 1);
      @h.accumulate(7, 4);
      @h.accumulate(8, 8);
      @h.accumulate(9, 8);

      assert_equal 53, @h.count
      assert_equal 236, @h.total
      assert_equal 9, @h.max
      assert_equal 0, @h.quantile(0)
      assert_equal 4, @h.quantile(0.5)
      assert_equal 9, @h.quantile(0.9)
      # from Excel
      assert_in_delta 4.452830189, @h.mean, $delta
      assert_in_delta 3.284965974, Math.sqrt(@h.sample_variance), $delta
    end

    should "handle big numbers" do
      @h.accumulate(65536, 65536) # this can cause overflow if not careful
      assert_in_delta 65536, @h.mean, $delta
    end

    should "merge" do
      h0 = SiTaxi::NaturalHistogram.from_h 1 => 1, 2 => 1
      h1 = SiTaxi::NaturalHistogram.from_h 2 => 1, 3 => 1

      h = SiTaxi::NaturalHistogram.merge(SiTaxi::NaturalHistogram.new, h0)
      assert_equal 2, h.count
      assert_equal 0, h.frequency[0]
      assert_equal 1, h.frequency[1]
      assert_equal 1, h.frequency[2]

      h = SiTaxi::NaturalHistogram.merge(h0, h1)
      assert_equal 4, h.count
      assert_equal 0, h.frequency[0]
      assert_equal 1, h.frequency[1]
      assert_equal 2, h.frequency[2]
      assert_equal 1, h.frequency[3]

      assert_equal 3, h.quantile(1)
      assert_equal 2, h.quantile(0.5)
    end
  end

  context "od matrix wrapper" do
    context "empty matrix" do
      setup do
        @w = SiTaxi::ODMatrixWrapper.new []
      end
      should "be empty" do
        assert_equal [], @w.od_matrix
      end
      should "have infinite expected interarrival time" do
        assert @w.expected_interarrival_time.infinite?
      end
    end

    context "2x2 matrix" do
      setup do
        @w = SiTaxi::ODMatrixWrapper.new [[0,1],[2,0]]
      end
      should "give the matrix back" do
        assert_equal [[0,1],[2,0]], @w.od_matrix
      end
      should "have right entries" do
        assert_in_delta 0, @w.at(0, 0), $delta
        assert_in_delta 1, @w.at(0, 1), $delta
        assert_in_delta 2, @w.at(1, 0), $delta
        assert_in_delta 0, @w.at(1, 1), $delta
      end
      should "have right expected interarrival time" do
        assert_in_delta 1.0/3, @w.expected_interarrival_time, $delta
      end
      should "have right trip probabilities" do
        assert_in_delta     0, @w.trip_prob(0, 0), $delta
        assert_in_delta 1.0/3, @w.trip_prob(0, 1), $delta
        assert_in_delta 2.0/3, @w.trip_prob(1, 0), $delta
        assert_in_delta     0, @w.trip_prob(1, 1), $delta
      end
      should "have right rates from" do
        assert_in_delta 1, @w.rate_from(0), $delta
        assert_in_delta 2, @w.rate_from(1), $delta
      end
      should "have right rates to" do
        assert_in_delta 2, @w.rate_to(0), $delta
        assert_in_delta 1, @w.rate_to(1), $delta
      end
      should "be able to sample" do
        SiTaxi.seed_rng(123)
        100.times do
          origin, destin, interval = @w.sample
          assert [0, 1].member?(origin) && [0, 1].member?(destin)
          assert origin != destin
          assert interval >= 0
        end
      end
      should "compute poisson probabilities" do
        # reference values from R: dpois(0:2, 1) and dpois(0:2, 2)
        assert_in_delta 0.36787944, @w.poisson_origin_pmf(0, 0), $delta
        assert_in_delta 0.36787944, @w.poisson_origin_pmf(0, 1), $delta
        assert_in_delta 0.18393972, @w.poisson_origin_pmf(0, 2), $delta
        assert_in_delta 0.06131324, @w.poisson_origin_pmf(0, 3), $delta

        assert_in_delta 0.1353353, @w.poisson_origin_pmf(1, 0), $delta
        assert_in_delta 0.2706706, @w.poisson_origin_pmf(1, 1), $delta
        assert_in_delta 0.2706706, @w.poisson_origin_pmf(1, 2), $delta
        assert_in_delta 0.1804470, @w.poisson_origin_pmf(1, 3), $delta

        assert_in_delta 1-0.36787944,
          @w.poisson_origin_cdf_complement(0, 0), $delta
        assert_in_delta 1-0.36787944-0.36787944,
          @w.poisson_origin_cdf_complement(0, 1), $delta

        assert_in_delta 1-0.1353353,
          @w.poisson_origin_cdf_complement(1, 0), $delta
        assert_in_delta 1-0.1353353-0.2706706,
          @w.poisson_origin_cdf_complement(1, 1), $delta
      end
    end

    context "2x2 matrix with zero entry" do
      setup do
        @w = SiTaxi::ODMatrixWrapper.new [[0,0],[1,0]]
      end
      should "compute poisson probabilities" do
        assert_in_delta 1.0, @w.poisson_origin_pmf(0, 0), $delta
        assert_in_delta 0.0, @w.poisson_origin_pmf(0, 1), $delta
        assert_in_delta 0.0, @w.poisson_origin_pmf(0, 2), $delta

        assert_in_delta 0.36787944, @w.poisson_origin_pmf(1, 0), $delta
        assert_in_delta 0.36787944, @w.poisson_origin_pmf(1, 1), $delta
        assert_in_delta 0.18393972, @w.poisson_origin_pmf(1, 2), $delta
        assert_in_delta 0.06131324, @w.poisson_origin_pmf(1, 3), $delta

        assert_in_delta 0.0, @w.poisson_origin_cdf_complement(0, 0), $delta
        assert_in_delta 0.0, @w.poisson_origin_cdf_complement(0, 1), $delta

        assert_in_delta 1-0.36787944,
          @w.poisson_origin_cdf_complement(1, 0), $delta
        assert_in_delta 1-0.36787944-0.36787944,
          @w.poisson_origin_cdf_complement(1, 1), $delta
      end
    end

    context "3x3 matrix" do
      setup do
        @w = SiTaxi::ODMatrixWrapper.new [[0,1,2],[3,0,4],[5,6,0]]
      end
      should "give the matrix back" do
        assert_equal [[0,1,2],[3,0,4],[5,6,0]], @w.od_matrix
      end
      should "have right expected interarrival time" do
        assert_in_delta 1.0/(1+2+3+4+5+6), @w.expected_interarrival_time, $delta
      end
      should "have right rates from" do
        assert_in_delta 1+2, @w.rate_from(0), $delta
        assert_in_delta 3+4, @w.rate_from(1), $delta
        assert_in_delta 5+6, @w.rate_from(2), $delta
      end
      should "have right rates to" do
        assert_in_delta 3+5, @w.rate_to(0), $delta
        assert_in_delta 1+6, @w.rate_to(1), $delta
        assert_in_delta 2+4, @w.rate_to(2), $delta
      end
      should "be able to sample" do
        SiTaxi.seed_rng(456)
        100.times do
          origin, destin, interval = @w.sample
          assert [0, 1, 2].member?(origin) && [0, 1, 2].member?(destin)
          assert origin != destin
          assert interval >= 0
        end
      end
    end

    should "fail to create non-square OD matrix" do
      assert_raise(RuntimeError) do
        SiTaxi::ODMatrixWrapper.new [[0,1,2],[3,0,4],[5,6,0],[1,2,3]]
      end
    end
  end

  context "od histogram" do
    should "handle empty histogram" do
      assert_equal 0, SiTaxi::ODHistogram.new(0).num_stations
    end

    should "handle single-entry histogram" do
      h = SiTaxi::ODHistogram.new(1)
      assert_equal 1, h.num_stations
      assert_equal 0, h.max_weight
      h.increment(0, 0)
      assert_equal [[1]], h.od_matrix
      assert_equal 1, h.max_weight
      h.increment(0, 0)
      assert_equal [[2]], h.od_matrix
      assert_equal 2, h.max_weight
    end

    should "record entries" do
      h = SiTaxi::ODHistogram.new(2)
      assert_equal 2, h.num_stations
      assert_equal 0, h.max_weight

      h.increment(0, 0)
      assert_equal 1, h.max_weight
      h.increment(0, 1)
      h.increment(1, 0)
      h.increment(1, 1)
      assert_equal [[1,1],[1,1]], h.od_matrix

      h.accumulate(0,1,2);
      assert_equal 3, h.max_weight
      assert_equal 3, h.max_weight_in_row(0)
      assert_equal 1, h.max_weight_in_row(1)
      assert_equal [[1,3],[1,1]], h.od_matrix

      h.clear
      assert_equal [[0,0],[0,0]], h.od_matrix
    end
  end

  should "compute cartesian product of arrays" do
    assert_equal nil, cartesian_product() # undefined
    assert_equal [], cartesian_product([])
    assert_equal [[1]], cartesian_product([1])
    assert_equal [[1],[2]], cartesian_product([1,2])

    assert_equal [], cartesian_product([],[])
    assert_equal [], cartesian_product([1],[])
    assert_equal [[1,2]], cartesian_product([1],[2])
    assert_equal [[1,2],[1,3]], cartesian_product([1],[2,3])
  end

  should "compute cartesian product of hashes" do
    # no array-valued values
    args = {:a => 1, :b => "foo"}
    hs = hash_cartesian_product(args)
    assert_equal [{:a => 1, :b => "foo"}], hs

    args[:c] = [1, 2]
    hs = hash_cartesian_product(args)
    assert_equal 2, hs.size
    assert_equal({:a => 1, :b => "foo", :c => 1}, hs[0])
    assert_equal({:a => 1, :b => "foo", :c => 2}, hs[1])

    args[:d] = [4,5,6]
    hs = hash_cartesian_product(args)
    assert_equal({:a => 1, :b => "foo", :c => 1, :d => 4}, hs[0])
    assert_equal({:a => 1, :b => "foo", :c => 1, :d => 5}, hs[1])
    assert_equal({:a => 1, :b => "foo", :c => 1, :d => 6}, hs[2])
    assert_equal({:a => 1, :b => "foo", :c => 2, :d => 4}, hs[3])
    assert_equal({:a => 1, :b => "foo", :c => 2, :d => 5}, hs[4])
    assert_equal({:a => 1, :b => "foo", :c => 2, :d => 6}, hs[5])
  end

  should "have nil if nan" do
    assert_equal 1.0, nil_if_nan(1.0)
    assert_equal 1.0/0.0, nil_if_nan(1.0/0.0) # doesn't remove infs
    assert_equal nil, nil_if_nan(0.0/0.0)
  end

  should "have range function like matlab" do
    # These came from testing things in Matlab.
    assert_equal [], range(1,0,2) 
    assert_equal [], range(2,0,1) 
    assert_equal [], range(2,0.1,1) 
    assert_equal [0.1], range(0.1,0.1,0.1) 
    assert_all_in_delta [0.1, 0.12, 0.14, 0.16, 0.18, 0.2],
      range(0.1,0.02,0.2), $delta 
    assert_all_in_delta [0.1, 0.2], range(0.1,0.1,0.2), $delta
    assert_all_in_delta [0.1, 0.2, 0.3], range(0.1,0.1,0.3), $delta
    assert_equal 201, range(-1, 0.01, 1).size 
    
    # But, integer ranges should stay as integers in Ruby.
    range(0,5,20).each do |x| assert_instance_of(Fixnum, x); end
    range(0,1,2).each do |x| assert_instance_of(Fixnum, x); end
    range(0,1,1).each do |x| assert_instance_of(Fixnum, x); end
      
    # Check that the default delta is 1.
    range(0,2).each do |x| assert_instance_of(Fixnum, x); end
    assert_equal range(0,2), range(0,1,2)
    assert_all_in_delta [0.5,1.5,2.5], range(0.5,2.5), $delta
    
    assert_equal [0,0.5,1], range(0,0.5,1)
  end
end

