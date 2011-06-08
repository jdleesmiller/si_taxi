%module siTaxi

%{
#include <si_taxi/si_taxi.h>
#include <si_taxi/empirical_sampler.h>
#include <si_taxi/natural_histogram.h>
#include <si_taxi/od_histogram.h>
#include <si_taxi/od_matrix_wrapper.h>
#include <si_taxi/bell_wong/bell_wong.h>
#include <si_taxi/bell_wong/call_times.h>
#include <si_taxi/bell_wong/andreasson.h>
#include <si_taxi/bell_wong/dynamic_tp.h>
#include <si_taxi/bell_wong/sampling_voting.h>

using namespace si_taxi;
%}

%include typemaps.i
%include exception.i
%include std_vector.i
%include std_queue.i

%exceptionclass si_taxi::Exception;
%exception {
  try {
    $action
  } catch (const std::exception& e) {
    SWIG_exception(SWIG_RuntimeError, e.what());
  }
}

%apply unsigned long long { uint64_t }

%template(SizeTVector) std::vector<size_t>;
%template(DoubleVector) std::vector<double>;
%template(IntVector) std::vector<int>;
%template(NaturalHistogramVector) std::vector<si_taxi::NaturalHistogram>;

%template(BWVehicleVector) std::vector<si_taxi::BWVehicle>;
%template(BWPaxQueue) std::queue<si_taxi::BWPax>;
%template(BWSimStatsPaxRecordVector) std::vector<si_taxi::BWSimStatsPaxRecord>;

%template(IntQueue) std::queue<int>;

%include "boost_numeric_ublas_matrix.i"

BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(double, NUM2DBL)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(double, rb_float_new)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(int, NUM2INT)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(int, INT2NUM)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(size_t, NUM2ULONG)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(size_t, ULONG2NUM)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(bool, (bool))
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(bool, SWIG_From_bool)

%inline %{
/**
 * Easy way to seed the generator from Ruby, because it's not worth wrapping
 * the whole Boost.Random library just to do this.
 */
void seed_rng(unsigned int seed) {
  si_taxi::rng.seed(seed);
}
%}

%include "si_taxi/si_taxi.h"
%include "si_taxi/empirical_sampler.h"
%include "si_taxi/natural_histogram.h"
%include "si_taxi/od_histogram.h"

/* Enable multiple return values for od.sample(). */
%apply size_t *OUTPUT { size_t &origin, size_t &destin }
%apply double *OUTPUT { double &interval }

%include "si_taxi/od_matrix_wrapper.h"

/* Clean up for od.sample(). */
%clear size_t &origin;
%clear size_t &destin;
%clear double &interval;

%include "si_taxi/bell_wong/bell_wong.h"
%include "si_taxi/bell_wong/call_times.h"
%include "si_taxi/bell_wong/andreasson.h"
%include "si_taxi/bell_wong/dynamic_tp.h"
%include "si_taxi/bell_wong/sampling_voting.h"

