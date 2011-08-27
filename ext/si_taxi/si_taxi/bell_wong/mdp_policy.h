#ifndef SI_TAXI_BELL_WONG_MDP_POLICY_H_
#define SI_TAXI_BELL_WONG_MDP_POLICY_H_

#include "bell_wong.h"

namespace si_taxi {

struct BWMDPPolicyState {
  BWMDPPolicyState(const std::vector<int> &queue,
      const std::vector<int> &inbound, const std::vector<int> &eta) :
        queue(queue), inbound(inbound), eta(eta) {}
  std::vector<int> queue;
  std::vector<int> inbound;
  std::vector<int> eta;
};

bool operator==(const BWMDPPolicyState &s0, const BWMDPPolicyState &s1);

size_t hash_value(const BWMDPPolicyState &s);

class BWMDPPolicyHandler : public BWProactiveHandler {
public:
  BWMDPPolicyHandler(BWSim &sim);

  /**
   * Set a single (state, action) policy pair.
   */
  void set_policy(const BWMDPPolicyState &state,
      const boost::numeric::ublas::matrix<int> &action);

  /**
   * Override.
   */
  //virtual void handle_pax_served(size_t empty_origin);

  /**
   * Override.
   */
  //virtual void handle_idle(BWVehicle &veh);

  /**
   * Override.
   */
  //virtual void handle_strobe();

private:

  typedef boost::numeric::ublas::matrix<int> Action;

  boost::unordered_map<BWMDPPolicyState, Action> policy;
};

}

#endif /* guard */
