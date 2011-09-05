#include "mdp_sim.h"
#include <si_taxi/stdafx.h>
#include <si_taxi/utility.h>

using namespace std;

namespace si_taxi {

void MDPSim::tick() {
  // advance now; note that now is initialized to -1 before the first tick
  ++now;

  // check for new passengers; put them in queues

  // look for stations with both idle vehicles and queues; make occupied trips

  // the model may be somewhat misleading...
  // we take an action at time t (move a vehicle from A to B)
  // the successor state at time t+1 should have ETA = t_AB - 1, but I think it
  // currently sets ETA = t_AB, then we decide on the action, and then we
  // move the vehicle one step forward at the start of the next time step.
  // That's probably not too bad, but it's a bit strange.
}

}
