/**
 * Main header for public interface.
 */
#ifndef SI_TAXI_H_
#define SI_TAXI_H_

#include <string>
#include <vector>

#include <boost/config.hpp>
#include <boost/random.hpp>
#ifdef ALLOC
// This define in ruby.h breaks boost/numeric/ublas/matrix.hpp.
#undef ALLOC
#include <boost/numeric/ublas/matrix.hpp>
#define ALLOC(type) (type*)xmalloc(sizeof(type)) // from ruby.h (1.8.7 & 1.9.2)
#else
#include <boost/numeric/ublas/matrix.hpp>
#endif

namespace si_taxi {

/**
 * Spit out a (C++) stack trace after a segfault. This only works with g++ on
 * Linux; on other platforms it does nothing.
 */
void register_sigsegv_handler();

/**
 * Used for 'no index' values.
 */
const size_t SIZE_T_MAX = std::numeric_limits<size_t>::max();

/**
 * We'll just keep one global rng for now. Storage in si_taxi.cpp.
 */
extern boost::mt19937 rng;

/**
 * Base class for exceptions. This is a light-weight exception. Use the
 * "Error" classes if you want to send debugging information.
 */
class Exception: public std::exception {
public:
  Exception() throw () :
    std::exception() {
  }
  explicit Exception(const char* what) throw () :
    std::exception(), _what(what) {
  }
  virtual const char* what() const throw () {
    return this->_what.c_str();
  }
  virtual ~Exception(void) throw () { }
protected:
  std::string _what;
};

/**
 * A heavy exception class that should be used when it is clear that the
 * source of the problem is the program itself, rather than a problem with
 * the user or the environment. Supports stream formatting.
 */
class Error: public Exception {
public:
  Error(const char* message, int line, const char* file,
          const char* function) throw ();
  virtual ~Error() throw () { }
  int line() const throw () {
    return _line;
  }
  const std::string& file() const throw () {
    return _file;
  }
  const std::string& function() const throw () {
    return _function;
  }
  const std::string& stack_trace() const throw () {
    return _stackTrace;
  }
protected:
  int _line;
  std::string _stackTrace;
  std::string _file;
  std::string _function;
};

typedef boost::mt19937 RNG;

/**
 * Cumulative average, where average is the average over the last count points
 * and x is the point just observed. Note that this method increments count.
 */
template <typename T, typename N>
T cumulative_moving_average(T x, T average, N &count) {
  ++count;
  return average + (x - average) / count;
}

}

#endif
