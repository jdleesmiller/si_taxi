require "test/unit"
require "shoulda"
require "si_taxi"

class TestSiTaxi < Test::Unit::TestCase
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
    end

    context "after increment(0)" do
      setup do
        @h.increment(0)
      end

      should "contain one zero" do
        assert_equal [1], @h.to_a
      end
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
      should "have right rates" do
        assert_in_delta 1, @w.rate_from(0), $delta
        assert_in_delta 2, @w.rate_from(1), $delta
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
      should "have right rates" do
        assert_in_delta 1+2, @w.rate_from(0), $delta
        assert_in_delta 3+4, @w.rate_from(1), $delta
        assert_in_delta 5+6, @w.rate_from(2), $delta
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
end

