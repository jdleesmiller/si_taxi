#ifndef MDP_PAX_H_
#define MDP_PAX_H_

namespace si_taxi {

/**
 * A 32-bit time index is typically adequate.
 *
 * Differences of times are often computed, so a signed type is needed.
 *
 * This is here so SWIG can see it before it loads mdp_sim.h.
 */
typedef long MDPTime;

/**
 * Passenger. The MDP model uses discrete time, but it is useful to keep track
 * of exactly when passengers arrived within the (fairly large) MDP time steps.
 */
struct MDPPax {
  size_t origin;
  size_t destin;
  double arrive;

  MDPPax() { }
  MDPPax(size_t origin, size_t destin, double arrive) :
    origin(origin), destin(destin), arrive(arrive) { }
};

}

#endif /* MDP_PAX_H_ */
