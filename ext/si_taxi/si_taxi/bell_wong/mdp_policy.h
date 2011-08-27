#ifndef SI_TAXI_BELL_WONG_MDP_POLICY_H_
#define SI_TAXI_BELL_WONG_MDP_POLICY_H_

#include "bell_wong.h"

namespace si_taxi {

class BWMDPPolicyHandler : public BWProactiveHandler {
public:
  BWMDPPolicyHandler(BWSim &sim);

  /**
   * Set a single (state, action) policy pair.
   */
  void set_policy(const std::vector<int> &queue,
      const std::vector<int> &inbound, const std::vector<int> &eta,
      const boost::numeric::ublas::matrix<int> &action);
};

}

#endif /* guard */
