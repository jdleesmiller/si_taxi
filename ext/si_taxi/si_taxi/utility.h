/**
 * Private utility header; not to be included in public header files.
 */
#ifndef SI_TAXI_UTILITY_H_
#define SI_TAXI_UTILITY_H_

#include "si_taxi.h"

/**
 * Marker for arguments passed by reference (evaluates to nothing; it's just
 * a marker).
 */
#define BYREF

/**
 * Throws an exception. Allows stream-like formatting in the message.
 * @param message stream operator message (e.g. "x=" << x << "y=" << y)
 */
#define FAIL(message) do {                                                    \
  std::stringstream ss;                                                       \
  ss << message;                                                              \
  throw si_taxi::Error(ss.str().c_str(),__LINE__,__FILE__,__PRETTY_FUNCTION__);\
} while(0)

/**
 * Print message to stderr with file and line information.
 * @param message stream operator message (e.g. "x=" << x << "y=" << y)
 */
#define TRACE(message) do {                                                   \
  std::cerr << __FILE__ << ":" << __LINE__ << ": " << message << std::endl;   \
} while(0)

/**
 * An assertion that is always checked (even if NDEBUG is defined).
 * @param condition boolean condition to check.
 * @param message stream operator message (e.g. "x=" << x << "y=" << y)
 */
#define CHECK_MSG(condition, message) do {                                    \
  if (!(condition)) FAIL("Check failed: " << message);                        \
} while(0)

/**
 * An assertion that is always checked (even if NDEBUG is defined). If the
 * asserted condition is false, the program terminates. Use this sparingly!
 */
#define CHECK(condition)                CHECK_MSG(condition, #condition)

/**
 * An assertion that is always checked (even if NDEBUG is defined). If the
 * given expression does not throw the given exception, FAIL is called.
 * Put a trailing semicolon on the expression.
 */
#define CHECK_THROW(expression) do {                                        \
  try {                                                                     \
    expression;                                                             \
    FAIL("Expected exception from " #expression);                           \
  } catch (...) { /* expected */ }                                          \
} while(0)

/**
 * Check that each element of a container satisfies the given condition. You
 * can use this with Boost.Lambda, as in CHECK_ALL(p, 0 <= _1 && _1 <= 1); for
 * a list of probabilities.
 */
#define CHECK_ALL(v, cond) do { \
  bool all_true = true; \
  for_each(v.begin(), v.end(), var(all_true) = all_true && cond); \
  CHECK_MSG(all_true, "for all " << #v << ": " << #cond); \
  } while(0)

#define CHECK_CLOSE(x0, x1, tol) CHECK(abs((x0) - (x1)) < tol)

/**
 * Trace value (to stderr).
 */
#define TV(var) TRACE(#var << "=" << (var));

#ifdef NDEBUG
#define ASSERT(x) do { } while (0)
#else
#define ASSERT(x) CHECK(x)
#endif

// not strictly legal
namespace std {
template<typename S, typename T>
std::ostream& operator<<(std::ostream &os, const std::pair<S, T> &p) {
  return os << "(" << p.first << "," << p.second << ")";
}
template<typename T>
std::ostream& operator<<(std::ostream &os, const std::vector<T> &v) {
  std::copy(v.begin(), v.end(), std::ostream_iterator<T> (os, " "));
  return os;
}
} // namespace std

namespace si_taxi {
/**
 * Print something to a string. This isn't overwhelmingly efficient.
 */
template<typename T> std::string to_s(const T& t) {
  std::ostringstream os;
  os << t;
  return os.str();
}

/**
 * Read something from a string using a string stream.
 */
template<typename T> bool from_s(T & t, const char * s) {
  std::istringstream is(s);
  return (bool)(is >> t);
}

/**
 * Read something from a string using a string stream.
 */
template<typename T> bool from_s(T & t, const std::string &s) {
  std::istringstream is(s);
  return (bool)(is >> t);
}

/*
 * Functor for comparing with a permutation on a vector.
 * For example, to build perm pi s.t. R[pi[.]] is sorted:
 * vector<size_t> pi(N);
 * for (size_t i = 0; i < N; ++i) pi[i] = i;
 * sort(pi.begin(), pi.end(), F_compare_perm<double>(R));
 */
template<typename T> struct F_compare_perm {
  const T &data;
  F_compare_perm(const T &data) :
    data(data) {
  }

  bool operator()(size_t pi0, size_t pi1) const {
    return data[pi0] < data[pi1];
  }
};

/**
 * Wrapper for F_compare_perm.
 */
template <typename T> F_compare_perm<T> compare_perm(const T& data) {
  return F_compare_perm<T>(data);
}

/**
 * Minimum of elements in a (non-empty) vector is at least x.
 * The intention is that this be used with boost::numeric::ublas::vector<int>,
 * which apparently doesn't have a 'min' or logical 'all' operation built-in,
 * and is apparently quite hard to use.
 */
template <typename T> bool vector_all_at_least(const T &v, int x) {
  CHECK(v.size() > 0);
  int min_val = v(0);
  for (size_t i = 1; i < v.size(); ++i) {
    if (v(i) < min_val) {
      min_val = v(i);
    }
  }
  return min_val >= x;
}

/**
 * Go through all possible action matrices recursively, and call the given
 * functor when a complete sequence has been obtained.
 */
template <typename MatData, typename RowSums, typename F>
void each_square_matrix_with_row_sums_lte(MatData &mat,
    size_t start, size_t offset, size_t used, const RowSums &row_sums, F &f)
{
  if (start + offset >= mat.size()) {
    // base case: whole mat now intialised
    f(mat);
  } else {
    size_t n = row_sums.size();
    size_t origin = offset / n;
    size_t destin = offset % n;
    if (origin == destin) {
      // skip the diagonal
      each_square_matrix_with_row_sums_lte(
          mat, start, offset + 1, used, row_sums, f);
    } else {
      CHECK(row_sums[origin] >= (int)used);
      bool new_row = destin == n - 1;
      for (size_t i = 0; i <= row_sums[origin] - used; ++i) {
        mat[start + offset] = i;
        each_square_matrix_with_row_sums_lte(
            mat, start, offset + 1, new_row ? 0 : used + i, row_sums, f);
      }
    }
  }
}

/**
 * Go through all possible vehicle movement matrices recursively, and call the
 * given functor when a complete sequence has been obtained.
 */
template <typename MatData, typename RowSums, typename F>
void each_square_matrix_with_row_sums(MatData &mat,
    size_t start, size_t offset, size_t used, const RowSums &row_sums, F &f)
{
  CHECK(row_sums.size() >= 2);
  if (start + offset >= mat.size()) {
    // base case: whole mat now intialised
    f(mat);
  } else {
    size_t n = row_sums.size();
    size_t origin = offset / n;
    size_t destin = offset % n;
    if ((origin  < n - 1 && destin == n - 1) ||
        (origin == n - 1 && destin == n - 2)) {
      // end of a row; the value of the last entry is fixed
      mat[start + offset] = row_sums[origin] - used;
      each_square_matrix_with_row_sums(
          mat, start, offset + 1, 0, row_sums, f);
    } else if (origin == destin) {
      // skip the diagonal
      each_square_matrix_with_row_sums(
          mat, start, offset + 1, used, row_sums, f);
    } else {
      CHECK(row_sums[origin] >= (int)used);
      for (size_t i = 0; i <= row_sums[origin] - used; ++i) {
        mat[start + offset] = i;
        each_square_matrix_with_row_sums(
            mat, start, offset + 1, used + i, row_sums, f);
      }
    }
  }
}

}

#endif /* guard */
