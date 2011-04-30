require 'test/si_taxi_helper'

class FluidLimitTest < Test::Unit::TestCase
  include SiTaxi

  def test_sample_cdf
    assert_equal 0, sample_cdf([].cumsum)

    assert_equal 0, sample_cdf([1].cumsum, 0.01)
    assert_equal 0, sample_cdf([1].cumsum, 1)

    assert_equal 0, sample_cdf([1,0].cumsum, 0.01)
    assert_equal 0, sample_cdf([1,0].cumsum, 1)

    assert_equal 1, sample_cdf([0,1].cumsum, 0.01)
    assert_equal 1, sample_cdf([0,1].cumsum, 1)

    assert_equal 1, sample_cdf([0,1,0].cumsum, 0.01)
    assert_equal 1, sample_cdf([0,1,0].cumsum, 1)

    assert_equal 1, sample_cdf([0.0,0.5,0.0,0.5].cumsum, 0.01)
    assert_equal 1, sample_cdf([0.0,0.5,0.0,0.5].cumsum, 0.5)
    assert_equal 3, sample_cdf([0.0,0.5,0.0,0.5].cumsum, 0.51)
    assert_equal 3, sample_cdf([0.0,0.5,0.0,0.5].cumsum, 1)

    assert_equal 0, sample_cdf([0.5,0.0,0.5,0.0].cumsum, 0.01)
    assert_equal 0, sample_cdf([0.5,0.0,0.5,0.0].cumsum, 0.5)
    assert_equal 2, sample_cdf([0.5,0.0,0.5,0.0].cumsum, 0.51)
    assert_equal 2, sample_cdf([0.5,0.0,0.5,0.0].cumsum, 1)

    # due to rounding, we don't always get a 1 at the end; this routine will
    # just return one past the end
    cdf = ([0.1]*10).cumsum
    assert cdf[9] < 1
    (0..9).each do |i|
      assert_equal i, sample_cdf(cdf, i/10.0 + 0.01)
    end
    assert_equal 10, sample_cdf(cdf, 1)
  end

  def test_sampler
    s = EmpiricalSampler.new([])
    s = EmpiricalSampler.from_pmf([0.5,0.0,0.5,0.0])
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
    p s.sample
  end
end

