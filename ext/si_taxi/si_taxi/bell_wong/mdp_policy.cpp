#include "mdp_policy.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

// can we use the policy for the reactive handler?
//   probably doesn't matter for the scale we're looking at
// for the proactive handler, the steps are:
//  1) find the current state in the MDP description
//  2) the optimal action specifies how many vehicles to move between each pair
// how to get the data in? probably easiest to just put in a method that
// destructures the state-action pairs.

using namespace std;

namespace si_taxi {

BWMDPPolicyHandler::BWMDPPolicyHandler(BWSim &sim) : BWProactiveHandler(sim) {
  // TODO Auto-generated constructor stub
}

void BWMDPPolicyHandler::set_policy(const std::vector<int> &queue,
      const std::vector<int> &inbound, const std::vector<int> &eta,
      const boost::numeric::ublas::matrix<int> &action) {
  cout << queue << endl;
  cout << eta << endl;
  cout << action << endl;
  // TODO
}

};
