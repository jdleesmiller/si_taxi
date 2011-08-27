#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

#include "mdp_policy.h"

// can we use the policy for the reactive handler?
//   probably doesn't matter for the scale we're looking at
// for the proactive handler, the steps are:
//  1) find the current state in the MDP description
//  2) the optimal action specifies how many vehicles to move between each pair
// how to get the data in? probably easiest to just put in a method that
// destructures the state-action pairs.

using namespace std;

namespace si_taxi {

bool operator==(const BWMDPPolicyState &s0, const BWMDPPolicyState &s1) {
  return s0.queue == s1.queue &&
      s0.inbound == s1.inbound &&
      s0.eta == s1.eta;
}

size_t hash_value(const BWMDPPolicyState &s) {
  size_t seed = 0;
  boost::hash_combine(seed, s.queue);
  boost::hash_combine(seed, s.inbound);
  boost::hash_combine(seed, s.eta);
  return seed;
}

BWMDPPolicyHandler::BWMDPPolicyHandler(BWSim &sim) : BWProactiveHandler(sim) {
  // TODO Auto-generated constructor stub
}

void BWMDPPolicyHandler::set_policy(const BWMDPPolicyState &state,
      const boost::numeric::ublas::matrix<int> &action) {
  cout << state.queue << endl;
  cout << state.inbound << endl;
  cout << state.eta << endl;
  cout << action << endl;
  policy[state] = action;
}

};
