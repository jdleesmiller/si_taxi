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
    end
  end
end

