#ifndef SI_TAXI_RANDOM_H_
#define SI_TAXI_RANDOM_H_

/**
 * Helpful methods for generating random numbers.
 *
 * The template parameter RNG should be something like the boost::mt19937
 * random number generator.
 */

namespace si_taxi {

/**
 * Helper for use with random_shuffle and similar.
 * Based on http://stackoverflow.com/questions/147391
 */
template<typename RNG>
struct rng_rand: std::unary_function<unsigned, unsigned> {
  RNG &_state;
  /**
   * Returns random number in [0, i), as per spec.
   */
  unsigned operator()(unsigned i) {
    // This generates in [0, i-1] = [0, i).
    boost::uniform_int<> rng(0, i - 1);
    return rng(_state);
  }
  rng_rand(RNG &state) :
    _state(state) {
  }
};

/**
 * Boost's uniform_01 seems to have some issues (at least in 1.34). This is
 * a simple way of getting a [0,1)-uniform sample. We only use 32 bits rather
 * than the full 53.
 */
template<typename T, typename RNG> T genrand_c01o(RNG &rng) {
  return rng() * ((T) (1.0 / 4294967296.0));
  /* divided by 2^32 -- taken from SFMT.h */
}

/**
 * A (0,1)-uniform sample. We only use 32 bits rather than the full 53.
 */
template<typename T, typename RNG> T genrand_o01o(RNG &rng) {
  return (((T) rng()) + ((T) 0.5)) * ((T) (1.0 / 4294967296.0));
  /* divided by 2^32 -- taken from SFMT.h */
}

}

#endif // guard
