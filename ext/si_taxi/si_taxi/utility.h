/**
 * Private utility header; not to be included in public header files.
 */
#ifndef SI_TAXI_COMMON_H_
#define SI_TAXI_COMMON_H_

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

#endif /* guard */
