#ifndef LIBSI_TAXI_STDAFX_H
#define LIBSI_TAXI_STDAFX_H

// NB: it looks like some of these cause rbgccxml to fail
// NB: rbplusplus doesn't look at these; each header has to include the
// files it needs to compile cleanly. Hopefully that doesn't make this
// file irrelevant (it should not).

#include <cmath>
#include <cstdlib>
#include <deque>
#include <exception>
#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <queue>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include <boost/config.hpp>
#include <boost/circular_buffer.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/numeric/ublas/banded.hpp>
#include <boost/numeric/ublas/matrix.hpp>
#include <boost/numeric/ublas/matrix_proxy.hpp>
#include <boost/numeric/ublas/io.hpp>
#include <boost/random.hpp>

#endif /* guard */
