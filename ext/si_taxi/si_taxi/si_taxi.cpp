#include "stdafx.h"
#include "utility.h"
#include "si_taxi.h"

#ifdef __GNUC__
#define __GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <cxxabi.h>
#include <signal.h>
#endif

using namespace std;

extern "C" {
/**
 * Used to make extconf.rb's find_library call work.
 */
void si_taxi_hello_world() {
  // Do nothing.
}
}

namespace si_taxi {

// storage; declared in si_taxi.h
boost::mt19937 rng;

//
// Stack trace code based on http://www.mr-edd.co.uk/blog/stack_trace_x86
// Modified to handle a null name.
//
#ifdef __GNUC__
std::string demangle(const char *name)
{
  std::string ret;
  try {
    int status = 0;
    char *d = 0;
    if ((d = abi::__cxa_demangle(name, 0, 0, &status))) {
      ret = d;
      std::free(d);
    } else if (name) {
      ret = name;
    } else {
      ret = "(sname is null)";
    }
  }
  catch(...) { ret = "(demangle failed)"; }
  return ret;
}

void trace(std::ostream &os)
{
  Dl_info info;
  void **frame = static_cast<void **>(__builtin_frame_address(0));
  void **bp = static_cast<void **>(*frame);
  void *ip = frame[1];

  while(bp && ip && dladdr(ip, &info))
  {
    os << ip << ": " << demangle(info.dli_sname) << " in " <<
        info.dli_fname << '\n';
    if(info.dli_sname && !strcmp(info.dli_sname, "main")) break;
    ip = bp[1];
    bp = static_cast<void**>(bp[0]);
  }
}

static struct sigaction old_segv_action;

static void segv_handler(int signum) {
  cerr << "si_taxi handled segmentation fault from" << endl;
  trace(cerr);

  // Restore previous signal handler and reissue the signal.
  if (sigaction(SIGSEGV, &old_segv_action, NULL) == 0) {
    cerr << "(original segv handler output follows)" << endl;
    kill(getpid(), SIGSEGV);
  } else {
    cerr << "(failed to restore previous segv signal handler)" << endl;
  }
}

void register_sigsegv_handler() {
  // Save the old segv handler.
  struct sigaction new_segv_action;
  new_segv_action.sa_handler = segv_handler;
  sigemptyset(&new_segv_action.sa_mask);
  new_segv_action.sa_flags = 0;
  CHECK(0 == sigaction(SIGSEGV, &new_segv_action, &old_segv_action));
}

#else

void register_sigsegv_handler() {
  // Do nothing if not on g++.
}

#endif

si_taxi::Error::Error(const char* message, int line, const char* file,
    const char* function) throw () :
    si_taxi::Exception(message), _line(line), _file(file), _function(function) {
  try {
#ifdef __GNUC__
    ostringstream ss;
    trace(ss);
    _stackTrace = ss.str();
#else
    _stackTrace = "";
#endif
  } catch (...) {
    cerr << "FAILED" << endl;
    _stackTrace = "";
  }

  ostringstream os;
  os << endl << "at " << _file << ":" << _line;
  os << endl << "in " << _function;
  os << endl << _stackTrace;
  _what += os.str();
}

// helper for all_square_matrices_with_row_sums_lte
struct F_get_matrix_data {
  std::vector<std::vector<int> > results;
  void operator()(vector<int> &data) {
    results.push_back(std::vector<int>(data.begin(), data.end()));
  }
};

std::vector<std::vector<int> > all_square_matrices_with_row_sums_lte(
    const std::vector<int> &row_sums)
{
  size_t n = row_sums.size();
  std::vector<int> data(n*n);
  F_get_matrix_data f;
  each_square_matrix_with_row_sums_lte(data, 0, 0, 0, row_sums, f);
  return f.results;
}

std::vector<std::vector<int> > all_square_matrices_with_row_sums(
    const std::vector<int> &row_sums)
{
  size_t n = row_sums.size();
  std::vector<int> data(n*n);
  F_get_matrix_data f;
  each_square_matrix_with_row_sums(data, 0, 0, 0, row_sums, f);
  return f.results;
}

}
