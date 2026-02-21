FROM rockylinux:8

# system packages 
RUN yum install -y yum-utils && \
    yum-config-manager --add-repo https://linux.mellanox.com/public/repo/mlnx_ofed/5.6-2.0.9.0/rhel8.6/x86_64/ && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/linux.mellanox.com_public_repo_mlnx_ofed_5.6-2.0.9.0_rhel8.6_x86_64_.repo

RUN yum install -y \
    # GNU compiler toolchain (GCC 12 for -march=znver3 support)
    gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-gcc-gfortran \
    gcc-toolset-12-libstdc++-devel gcc-toolset-12-binutils \
    # RDMA / InfiniBand
    libibverbs libibverbs-devel libibverbs-utils \
    librdmacm librdmacm-devel librdmacm-utils \
    libibumad libibumad-devel \
    rdma-core rdma-core-devel \
    ucx ucx-ib ucx-rdmacm ucx-cma ucx-devel \
    # general deps
    numactl numactl-libs numactl-devel \
    libxml2 libxml2-devel \
    libstdc++ libstdc++-devel \
    ncurses-libs ncurses-devel \
    zlib zlib-devel \
    libquadmath libquadmath-devel \
    python39 git cmake \
    byacc make findutils file which wget ca-certificates xz \
    && yum clean all \
    && source /opt/rh/gcc-toolset-12/enable \
    && echo "gcc: $(gcc --version | head -1)" \
    && echo "g++: $(g++ --version | head -1)" \
    && echo "gfortran: $(gfortran --version | head -1)"

ENV PATH=/opt/rh/gcc-toolset-12/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/gcc-toolset-12/root/usr/lib64:${LD_LIBRARY_PATH}

# MVAPICH2 (built with GCC)
RUN cd /tmp && \
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-2.3.7.tar.gz && \
    gzip -dc mvapich2-2.3.7.tar.gz | tar -x && \
    cd mvapich2-2.3.7 && \
    ./configure \
        --prefix=/opt/mvapich2 \
        --with-device=ch3:mrail \
        --with-rdma=gen2 \
        --with-ch3-rank-bits=32 \
        --enable-fortran=yes \
        --enable-cxx=yes \
        --enable-romio \
        --enable-shared \
        --enable-fast=O3 \
        --enable-hybrid \
        --enable-rdma-cm \
        CC=gcc CXX=g++ FC=gfortran F77=gfortran \
        CFLAGS="-O2 -march=znver3 -fPIC" \
        CXXFLAGS="-O2 -march=znver3 -fPIC" \
        FFLAGS="-O2 -march=znver3 -fPIC -fallow-argument-mismatch" \
        FCFLAGS="-O2 -march=znver3 -fPIC -fallow-argument-mismatch" && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -r /tmp/mvapich2-2.3.7

ENV CC=mpicc CXX=mpicxx FC=mpifort F77=mpifort \
    MPICH_CC=gcc MPICH_CXX=g++ MPICH_FC=gfortran MPICH_F77=gfortran \
    CFLAGS="-O2 -march=znver3 -fPIC" \
    CXXFLAGS="-O2 -march=znver3 -fPIC" \
    FFLAGS="-O2 -march=znver3 -fPIC -fallow-argument-mismatch" \
    PATH=/opt/mvapich2/bin:$PATH \
    LD_LIBRARY_PATH=/opt/mvapich2/lib:$LD_LIBRARY_PATH

# ── OpenBLAS (replaces AOCL BLAS + LAPACK) ──────────────────────────────────
ARG OPENBLAS_VERSION=0.3.28
RUN cd /tmp && \
    wget https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}.tar.gz && \
    tar xf OpenBLAS-${OPENBLAS_VERSION}.tar.gz && \
    cd OpenBLAS-${OPENBLAS_VERSION} && \
    make -j$(nproc) \
        TARGET=ZEN \
        USE_OPENMP=0 \
        NO_LAPACKE=0 \
        DYNAMIC_ARCH=0 \
        CC=gcc FC=gfortran && \
    make PREFIX=/opt/openblas install && \
    cd / && rm -rf /tmp/OpenBLAS-${OPENBLAS_VERSION}*

# ── FFTW (replaces AOCL FFTW) ───────────────────────────────────────────────
ARG FFTW_VERSION=3.3.10
RUN cd /tmp && \
    wget https://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz && \
    tar xf fftw-${FFTW_VERSION}.tar.gz && \
    cd fftw-${FFTW_VERSION} && \
    ./configure \
        --prefix=/opt/fftw \
        --enable-shared \
        --enable-avx2 \
        --enable-sse2 \
        CC=gcc F77=gfortran \
        CFLAGS="-O2 -march=znver3 -fPIC" \
        FFLAGS="-O2 -march=znver3 -fPIC" && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/fftw-${FFTW_VERSION}*

# ── ScaLAPACK (replaces AOCL ScaLAPACK) ─────────────────────────────────────
ARG SCALAPACK_VERSION=2.2.0
RUN cd /tmp && \
    wget https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v${SCALAPACK_VERSION}.tar.gz && \
    tar xf v${SCALAPACK_VERSION}.tar.gz && \
    cd scalapack-${SCALAPACK_VERSION} && \
    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/opt/scalapack \
        -DLAPACK_LIBRARIES=/opt/openblas/lib/libopenblas.so \
        -DBLAS_LIBRARIES=/opt/openblas/lib/libopenblas.so && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    cd / && rm -rf /tmp/scalapack-${SCALAPACK_VERSION}* /tmp/v${SCALAPACK_VERSION}.tar.gz

# ── library paths ────────────────────────────────────────────────────────────
ENV LD_LIBRARY_PATH=/opt/openblas/lib:/opt/fftw/lib:/opt/scalapack/lib:$LD_LIBRARY_PATH \
    LIBRARY_PATH=/opt/openblas/lib:/opt/fftw/lib:/opt/scalapack/lib:$LIBRARY_PATH \
    C_INCLUDE_PATH=/opt/openblas/include:/opt/fftw/include:/opt/scalapack/include \
    CPLUS_INCLUDE_PATH=/opt/openblas/include:/opt/fftw/include:/opt/scalapack/include \
    PKG_CONFIG_PATH=/opt/openblas/lib/pkgconfig:/opt/fftw/lib/pkgconfig:$PKG_CONFIG_PATH