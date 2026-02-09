#!/usr/bin/env bash
set -e
FAIL=0

echo "=== 1. Tool Versions ==="
echo "m4:       $(m4 --version | head -1)"
echo "autoconf: $(autoconf --version | head -1)"
echo "automake: $(automake --version | head -1)"
echo "libtool:  $(libtool --version | head -1)"
echo "perl:     $(perl -v | grep version)"
echo ""

echo "=== 2. Intel Compiler Detection ==="
echo "CC=$CC  CXX=$CXX  FC=$FC  F77=$F77"
which icx  || { echo "FAIL: icx not on PATH";  FAIL=1; }
which icpx || { echo "FAIL: icpx not on PATH"; FAIL=1; }
which ifx  || { echo "FAIL: ifx not on PATH";  FAIL=1; }
icx  --version | head -1
icpx --version | head -1
ifx  --version | head -1
echo ""

echo "=== 3. MPI Wrapper Verification ==="
echo "I_MPI_CC=$I_MPI_CC  I_MPI_CXX=$I_MPI_CXX  I_MPI_FC=$I_MPI_FC"
which mpicc  || { echo "FAIL: mpicc not on PATH";  FAIL=1; }
which mpicxx || { echo "FAIL: mpicxx not on PATH"; FAIL=1; }
which mpifc  || { echo "FAIL: mpifc not on PATH";  FAIL=1; }
echo "--- mpicc -show ---";   mpicc  -show
echo "--- mpicxx -show ---";  mpicxx -show
echo "--- mpifc -show ---";   mpifc  -show
mpicc  -show 2>&1 | grep -q "icx"  || { echo "FAIL: mpicc not using icx";   FAIL=1; }
mpicxx -show 2>&1 | grep -q "icpx" || { echo "FAIL: mpicxx not using icpx"; FAIL=1; }
mpifc  -show 2>&1 | grep -q "ifx"  || { echo "FAIL: mpifc not using ifx";   FAIL=1; }
echo ""

echo "=== 4. Compile and Link Test (C) ==="
cd /tmp
echo "int main(void) { return 0; }" > test_c.c
icx -o test_c test_c.c || { echo "FAIL: icx compile"; FAIL=1; }
./test_c                || { echo "FAIL: icx binary";  FAIL=1; }
echo "C compile+link: OK"
echo ""

echo "=== 5. Compile and Link Test (C++) ==="
echo "int main() { return 0; }" > test_cpp.cpp
icpx -o test_cpp test_cpp.cpp || { echo "FAIL: icpx compile"; FAIL=1; }
./test_cpp                    || { echo "FAIL: icpx binary";  FAIL=1; }
echo "C++ compile+link: OK"
echo ""

echo "=== 6. Compile and Link Test (Fortran) ==="
echo "program test; print *, \"OK\"; end program" > test_f.f90
ifx -o test_f test_f.f90 || { echo "FAIL: ifx compile"; FAIL=1; }
./test_f                 || { echo "FAIL: ifx binary";  FAIL=1; }
echo "Fortran compile+link: OK"
echo ""

echo "=== 7. MPI Compile Test ==="
echo "#include <mpi.h>"                             >  test_mpi.c
echo "int main(int argc, char **argv) {"            >> test_mpi.c
echo "  MPI_Init(&argc, &argv); MPI_Finalize();"   >> test_mpi.c
echo "  return 0; }"                                >> test_mpi.c
mpicc -o test_mpi test_mpi.c || { echo "FAIL: mpicc compile"; FAIL=1; }
echo "MPI C compile+link: OK"
echo ""

echo "=== 8. Libtool Intel Compiler Recognition ==="
echo "int foo(void) { return 42; }" > test_lt.c
libtool --mode=compile icx -c test_lt.c -o test_lt.lo || 
    { echo "FAIL: libtool compile with icx"; FAIL=1; }
libtool --mode=link icx -o libtest_lt.la test_lt.lo -rpath /usr/local/lib || 
    { echo "FAIL: libtool link with icx"; FAIL=1; }
echo "Libtool + icx: OK"
echo ""

echo "=== 9. Autoreconf Dry Run ==="
mkdir -p /tmp/test_reconf && cd /tmp/test_reconf
echo "AC_INIT([test],[1.0])"          >  configure.ac
echo "AC_PROG_CC"                     >> configure.ac
echo "AM_INIT_AUTOMAKE([foreign])"    >> configure.ac
echo "LT_INIT"                        >> configure.ac
echo "AC_CONFIG_FILES([Makefile])"    >> configure.ac
echo "AC_OUTPUT"                      >> configure.ac
echo "AUTOMAKE_OPTIONS = foreign"      > Makefile.am
echo "lib_LTLIBRARIES = libdummy.la"  >> Makefile.am
echo "libdummy_la_SOURCES = dummy.c"  >> Makefile.am
echo "int dummy(void){return 0;}"      > dummy.c
autoreconf -fi || { echo "FAIL: autoreconf -fi"; FAIL=1; }
./configure    || { echo "FAIL: generated configure"; FAIL=1; }
grep -q "icx" config.log || { echo "FAIL: configure did not detect icx"; FAIL=1; }
make           || { echo "FAIL: libtool+automake build"; FAIL=1; }
echo "Full autoreconf pipeline: OK"
echo ""

echo "=== 10. MKL Detection ==="
test -n "$MKLROOT" || { echo "FAIL: MKLROOT not set"; FAIL=1; }
test -d "$MKLROOT" || { echo "FAIL: MKLROOT dir missing"; FAIL=1; }
echo "MKLROOT=$MKLROOT: OK"
echo ""

echo "========================================="
if [ $FAIL -ne 0 ]; then
    echo "*** VERIFICATION FAILED ***"; exit 1
else
    echo "ALL CHECKS PASSED"
fi

rm -rf /tmp/test_* /tmp/test_reconf