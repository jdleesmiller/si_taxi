/*
 * Typemaps for boost::numeric::ublas::matrix.
 *
 * Example:
 *  BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(double, NUM2DBL)
 *  BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(double, rb_float_new)
 */
%define BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_IN(entrytype, entryfromruby)
%typemap(in) /* for references */
  boost::numeric::ublas::matrix<entrytype> &,
  const boost::numeric::ublas::matrix<entrytype> & {
  int i, j, rows, cols;
  VALUE row;

  if (!rb_obj_is_kind_of($input, rb_cArray)) {
    SWIG_exception_fail(SWIG_ERROR, "not an array");
  }

  rows = RARRAY_LEN($input);
  if (rows > 0) {
    cols = RARRAY_LEN(rb_ary_entry($input, 0));
  } else {
    cols = 0;
  }

  $1 = new boost::numeric::ublas::matrix<entrytype>(rows, cols);
  for (i = 0; i < rows; ++i) {
    row = rb_ary_entry($input, i);
    if (RARRAY_LEN(row) != cols) {
      SWIG_exception_fail(SWIG_ERROR, "ragged array not allowed");
    }
    for (j = 0; j < cols; ++j) {
      (*$1)(i, j) = entryfromruby(rb_ary_entry(row, j));
    }
  }
}

%typemap(freearg) /* for references */
  boost::numeric::ublas::matrix<entrytype> &,
  const boost::numeric::ublas::matrix<entrytype> & {
  delete $1;
}

%typemap(in) /* for copies */
  boost::numeric::ublas::matrix<entrytype>,
  const boost::numeric::ublas::matrix<entrytype> {
  int i, j, rows, cols;
  VALUE row;

  if (!rb_obj_is_kind_of($input, rb_cArray)) {
    SWIG_exception_fail(SWIG_ERROR, "not an array");
  }

  rows = RARRAY_LEN($input);
  if (rows > 0) {
    cols = RARRAY_LEN(rb_ary_entry($input, 0));
  } else {
    cols = 0;
  }

  $1 = boost::numeric::ublas::matrix<entrytype>(rows, cols);
  for (i = 0; i < rows; ++i) {
    row = rb_ary_entry($input, i);
    if (RARRAY_LEN(row) != cols) {
      SWIG_exception_fail(SWIG_ERROR, "ragged array not allowed");
    }
    for (j = 0; j < cols; ++j) {
      $1(i, j) = entryfromruby(rb_ary_entry(row, j));
    }
  }
}

%enddef

%define BOOST_NUMERIC_UBLAS_MATRIX_TYPEMAP_OUT(entrytype, entrytoruby)
%typemap(out) /* for references */
  boost::numeric::ublas::matrix<entrytype> &,
  const boost::numeric::ublas::matrix<entrytype> & {
  int i, j, rows, cols;
  VALUE row;

  rows = (int) $1->size1();
  cols = (int) $1->size2();
  $result = rb_ary_new2(rows);
  for (i = 0; i < rows; ++i) {
    row = rb_ary_new2(cols);
    rb_ary_push($result, row);
    for (j = 0; j < cols; ++j) {
      rb_ary_push(row, entrytoruby((*$1)(i, j)));
    }
  }
}

%typemap(out) /* for copies */
  boost::numeric::ublas::matrix<entrytype>,
  const boost::numeric::ublas::matrix<entrytype> {
  int i, j, rows, cols;
  VALUE row;

  rows = (int) $1.size1();
  cols = (int) $1.size2();
  $result = rb_ary_new2(rows);
  for (i = 0; i < rows; ++i) {
    row = rb_ary_new2(cols);
    rb_ary_push($result, row);
    for (j = 0; j < cols; ++j) {
      rb_ary_push(row, entrytoruby($1(i, j)));
    }
  }
}
%enddef

