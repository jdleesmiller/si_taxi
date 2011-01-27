%module si_taxi_ext

%{
#include <si_taxi/si_taxi.h>
#include <si_taxi/od_matrix_wrapper.h>
#include <si_taxi/bell_wong/bell_wong.h>
#include <si_taxi/bell_wong/bell_wong_andreasson.h>

using namespace si_taxi;
%}

%include exception.i

%exceptionclass si_taxi::Exception;
%exception {
  try {
    $action
  } catch (const std::exception& e) {
    SWIG_exception(SWIG_RuntimeError, e.what());
  }
}

%include std_vector.i

%template(SizeTVector) std::vector<size_t>;
%template(DoubleVector) std::vector<double>;
%template(NaturalHistogramVector) std::vector<si_taxi::NaturalHistogram>;

%template(BWVehicleVector) std::vector<si_taxi::BWVehicle>;

%include "boost_numeric_ublas_matrix.i"

BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(double, NUM2DBL)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(double, rb_float_new)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(int, NUM2INT)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(int, INT2NUM)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(size_t, NUM2ULONG)
BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(size_t, ULONG2NUM)

%include "si_taxi/si_taxi.h"
%include "si_taxi/od_matrix_wrapper.h"

%include "si_taxi/bell_wong/bell_wong.h"
%include "si_taxi/bell_wong/bell_wong_andreasson.h"

