FROM rockylinux:8

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo \
      https://linux.mellanox.com/public/repo/mlnx_ofed/5.6-2.0.9.0/rhel8.6/mellanox_mlnx_ofed.repo && \
    yum-config-manager --setopt="mlnx_ofed*".priority=10 --save && \
    yum install -y --exclude=libfabric* \
      rdma-core \
      rdma-core-devel \
      libibverbs-utils \
      librdmacm-utils \
      numactl-libs numactl \
      ucx \
      ucx-cma \
      ucx-ib \
      ucx-rdmacm \
      ucx-devel \
    && yum clean all

# Verify RDMA install
RUN ibv_devices 2>&1 || true && \
    ls -la /usr/lib64/libibverbs* && \
    ls -la /usr/lib64/libmlx5*

COPY oneAPI.repo /etc/yum.repos.d/

# Ideally, compilers should be same as TACC, at least Intel
RUN yum update -y && yum install --nogpgcheck -y \
    intel-oneapi-compiler-dpcpp-cpp-2024.1 \
    intel-oneapi-compiler-fortran-2024.1 \
    intel-oneapi-mkl-devel-2024.1 \
    intel-oneapi-mpi-devel-2021.12.0-534 \
    && yum clean all && rm -rf /var/cache/yum

SHELL ["/bin/bash", "-c"]

# Now set the ENV directives with the known 2024.1 installation paths.
ENV I_MPI_ROOT=/opt/intel/oneapi/mpi/2021.12
ENV MKLROOT=/opt/intel/oneapi/mkl/2024.1
ENV I_COMPILER_ROOT=/opt/intel/oneapi/compiler/2024.1/
ENV PATH=${I_MPI_ROOT}/bin:${MKLROOT}/bin:${I_COMPILER_ROOT}bin:$PATH
ENV LD_LIBRARY_PATH=${I_MPI_ROOT}/opt/mpi/libfabric/lib:${I_MPI_ROOT}/lib:${MKLROOT}/lib/intel64:${I_COMPILER_ROOT}lib:${I_COMPILER_ROOT}opt/compiler/lib:$LD_LIBRARY_PATH
ENV LIBRARY_PATH=${I_MPI_ROOT}/lib:${MKLROOT}/lib/intel64:${I_COMPILER_ROOT}lib:${I_COMPILER_ROOT}opt/compiler/lib:$LIBRARY_PATH
ENV CPATH=${I_MPI_ROOT}/include:${MKLROOT}/include:${I_COMPILER_ROOT}include:$CPATH
ENV FI_PROVIDER_PATH=${I_MPI_ROOT}/opt/mpi/libfabric/lib/prov
ENV PKG_CONFIG_PATH=${I_MPI_ROOT}/lib/pkgconfig:${MKLROOT}/lib/pkgconfig:${I_COMPILER_ROOT}lib/pkgconfig:$PKG_CONFIG_PATH
ENV CMAKE_PREFIX_PATH=${MKLROOT}/lib/cmake:${I_COMPILER_ROOT}lib/cmake:$CMAKE_PREFIX_PATH
ENV MANPATH=${I_MPI_ROOT}/share/man:${MKLROOT}/share/man:${I_COMPILER_ROOT}share/man:$MANPATH

# Force Intel compilers for ALL build systems.
ENV CC=icx
ENV CXX=icpx
ENV FC=ifx
ENV F77=ifx
ENV F90=ifx

# MPI compiler wrappers: tell them to use Intel compilers underneath
ENV I_MPI_CC=icx
ENV I_MPI_CXX=icpx
ENV I_MPI_F77=ifx
ENV I_MPI_FC=ifx
ENV I_MPI_F90=ifx

ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1

# Install autoconf dependencies
RUN yum update -y && yum install --nogpgcheck -y \
    procps \
    which \
    m4 \
    perl \
    git \
    libcurl-devel \
    && yum clean all && rm -rf /var/cache/yum

RUN cd /tmp && \
    curl -L https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.gz -o autoconf.tar.gz && \
    tar -zxf autoconf.tar.gz && \
    cd autoconf-2.72 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/autoconf*

RUN cd /tmp && \
    curl -L https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz -o automake.tar.gz && \
    tar -zxf automake.tar.gz && \
    cd automake-1.16.5 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/automake*

# libtool MUST be built with Intel compilers active so its configuration probes learn icx/icpx/ifx rather than gcc/g++.
RUN cd /tmp && \
    curl -L https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.gz -o libtool.tar.gz && \
    tar -zxf libtool.tar.gz && \
    cd libtool-2.4.7 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/libtool*

RUN cd /tmp && \
    curl -L https://github.com/Kitware/CMake/releases/download/v3.27.9/cmake-3.27.9-linux-x86_64.tar.gz \
        -o cmake.tar.gz && \
    tar -zxf cmake.tar.gz && \
    cp -r cmake-3.27.9-linux-x86_64/bin/* /usr/local/bin/ && \
    cp -r cmake-3.27.9-linux-x86_64/share/* /usr/local/share/ && \
    cp -r cmake-3.27.9-linux-x86_64/doc/* /usr/local/doc/ 2>/dev/null || true && \
    # Verify installation
    cmake --version | head -1 && \
    cmake --version | grep -q "3.27.9" && \
    cd / && rm -rf /tmp/cmake*

# Double check that the initial build environment is configured correctly
COPY check_build.sh .
RUN source check_build.sh

# CESM dependencies installed separately
ENV CESM_DEP_PREFIX=/opt/cesm-deps

# Add to paths
ENV PATH=${CESM_DEP_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LD_LIBRARY_PATH}
ENV LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LIBRARY_PATH}
ENV CPATH=${CESM_DEP_PREFIX}/include:${CPATH}
ENV PKG_CONFIG_PATH=${CESM_DEP_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
ENV CMAKE_PREFIX_PATH=${CESM_DEP_PREFIX}:${CMAKE_PREFIX_PATH}


# ---------------------------------------------------------------------------
# zlib 1.3.1
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz \
        -o zlib.tar.gz && \
    tar -zxf zlib.tar.gz && \
    cd zlib-1.3.1 && \
    CC=icx \
    CFLAGS="-O2 -fPIC" \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --static && \
    make -j$(nproc) && \
    make install && \
    # Also build the shared library in a second pass, because zlib's
    # configure does not support building both in a single invocation.
    make clean && \
    CC=icx \
    CFLAGS="-O2 -fPIC" \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} && \
    make -j$(nproc) && \
    make install && \
    # Verify
    ls -la ${CESM_DEP_PREFIX}/lib/libz.a && \
    ls -la ${CESM_DEP_PREFIX}/lib/libz.so && \
    cd / && rm -rf /tmp/zlib*

# ---------------------------------------------------------------------------
# HDF5 1.12.3
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.3/src/hdf5-1.12.3.tar.gz \
        -o hdf5.tar.gz && \
    tar -zxf hdf5.tar.gz && \
    cd hdf5-1.12.3 && \
    CC=mpicc \
    CXX=mpicxx \
    FC=mpifc \
    CFLAGS="-O2 -fPIC" \
    CXXFLAGS="-O2 -fPIC" \
    FCFLAGS="-O2 -fPIC" \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --with-zlib=${CESM_DEP_PREFIX} \
        --enable-parallel \
        --enable-fortran \
        --enable-hl \
        --enable-shared \
        --enable-static \
        --enable-build-mode=production \
        --disable-cxx \
        --disable-threadsafe \
        --disable-doxygen-doc \
    && \
    make -j$(nproc) && \
    make install && \
    # Verify insallation of HDF5
    ${CESM_DEP_PREFIX}/bin/h5pcc -showconfig | head -20 && \
    ${CESM_DEP_PREFIX}/bin/h5pcc -showconfig | grep -i "Parallel HDF5" && \
    ${CESM_DEP_PREFIX}/bin/h5pcc -showconfig | grep -i "Fortran" && \
    ls -la ${CESM_DEP_PREFIX}/lib/libhdf5.a && \
    ls -la ${CESM_DEP_PREFIX}/lib/libhdf5.so && \
    ls -la ${CESM_DEP_PREFIX}/lib/libhdf5_fortran.a && \
    ls -la ${CESM_DEP_PREFIX}/lib/libhdf5_hl.a && \
    cd / && rm -rf /tmp/hdf5*

# Export HDF5 location for downstream dependencies (NetCDF-C, NetCDF-Fortran)
ENV HDF5_DIR=${CESM_DEP_PREFIX}
ENV HDF5_ROOT=${CESM_DEP_PREFIX}

# ---------------------------------------------------------------------------
# PnetCDF 1.12.3
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://parallel-netcdf.github.io/Release/pnetcdf-1.12.3.tar.gz \
        -o pnetcdf.tar.gz && \
    tar -zxf pnetcdf.tar.gz && \
    cd pnetcdf-1.12.3 && \ 
    # Update tool chain to work with new intel compilers
    autoreconf -fi && \
    CC=mpicc \
    CXX=mpicxx \
    FC=mpifc \
    F77=mpifc \
    CFLAGS="-O2 -fPIC" \
    CXXFLAGS="-O2 -fPIC" \
    FCFLAGS="-O2 -fPIC" \
    FFLAGS="-O2 -fPIC" \
    MPICC=mpicc \
    MPICXX=mpicxx \
    MPIF77=mpifc \
    MPIF90=mpifc \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --enable-fortran \
        --enable-large-file-test \
        --enable-shared \
        --enable-static \
        --disable-cxx \
        --disable-debug \
        --disable-profiling \
        --disable-burst-buffering \
    && \
    make -j$(nproc) && \
    make install && \
    # Verify critical outputs
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --version && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --cflags && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --libs && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --has-fortran | grep -i yes && \
    ls -la ${CESM_DEP_PREFIX}/lib/libpnetcdf.a && \
    ls -la ${CESM_DEP_PREFIX}/lib/libpnetcdf.so && \
    cd / && rm -rf /tmp/pnetcdf*

# Export PnetCDF location for downstream NetCDF-C
ENV PNETCDF=${CESM_DEP_PREFIX}
ENV PNETCDF_DIR=${CESM_DEP_PREFIX}

# ---------------------------------------------------------------------------
# NetCDF-C 4.9.2
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz \
        -o netcdf-c.tar.gz && \
    tar -zxf netcdf-c.tar.gz && \
    mkdir netcdf-c-build && \
    cd netcdf-c-build && \
    cmake \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_CXX_COMPILER=mpicxx \
        -DCMAKE_C_FLAGS="-O2 -fPIC" \
        -DCMAKE_CXX_FLAGS="-O2 -fPIC" \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} \
        -DCMAKE_PREFIX_PATH=${CESM_DEP_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DHDF5_ROOT=${CESM_DEP_PREFIX} \
        -DHDF5_C_COMPILER_EXECUTABLE=${CESM_DEP_PREFIX}/bin/h5pcc \
        -DZLIB_LIBRARY=${CESM_DEP_PREFIX}/lib/libz.so \
        -DZLIB_INCLUDE_DIR=${CESM_DEP_PREFIX}/include \
        -DENABLE_NETCDF_4=ON \
        -DENABLE_HDF5=ON \
        -DENABLE_PNETCDF=ON \
        -DPNETCDF_DIR=${CESM_DEP_PREFIX} \
        -DENABLE_PARALLEL4=ON \
        -DENABLE_CDF5=ON \
        -DENABLE_DAP=OFF \
        -DENABLE_BYTERANGE=OFF \
        -DENABLE_NCZARR=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_DOXYGEN=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_UTILITIES=ON \
        ../netcdf-c-4.9.2 \
    && \
    make -j$(nproc) && \
    make install && \
    # Also build and install the static library
    cd /tmp && mkdir netcdf-c-build-static && \
    cd netcdf-c-build-static && \
    cmake \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_CXX_COMPILER=mpicxx \
        -DCMAKE_C_FLAGS="-O2 -fPIC" \
        -DCMAKE_CXX_FLAGS="-O2 -fPIC" \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} \
        -DCMAKE_PREFIX_PATH=${CESM_DEP_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DHDF5_ROOT=${CESM_DEP_PREFIX} \
        -DHDF5_C_COMPILER_EXECUTABLE=${CESM_DEP_PREFIX}/bin/h5pcc \
        -DZLIB_LIBRARY=${CESM_DEP_PREFIX}/lib/libz.a \
        -DZLIB_INCLUDE_DIR=${CESM_DEP_PREFIX}/include \
        -DENABLE_NETCDF_4=ON \
        -DENABLE_HDF5=ON \
        -DENABLE_PNETCDF=ON \
        -DPNETCDF_DIR=${CESM_DEP_PREFIX} \
        -DENABLE_PARALLEL4=ON \
        -DENABLE_CDF5=ON \
        -DENABLE_DAP=OFF \
        -DENABLE_BYTERANGE=OFF \
        -DENABLE_NCZARR=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_DOXYGEN=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_UTILITIES=OFF \
        ../netcdf-c-4.9.2 \
    && \
    make -j$(nproc) && \
    make install && \
    # Verify critical outputs
    ${CESM_DEP_PREFIX}/bin/nc-config --version && \
    ${CESM_DEP_PREFIX}/bin/nc-config --has-nc4    | grep -i yes && \
    ${CESM_DEP_PREFIX}/bin/nc-config --has-hdf5   | grep -i yes && \
    ${CESM_DEP_PREFIX}/bin/nc-config --has-pnetcdf | grep -i yes && \
    ${CESM_DEP_PREFIX}/bin/nc-config --has-parallel4 | grep -i yes && \
    ${CESM_DEP_PREFIX}/bin/nc-config --has-cdf5   | grep -i yes && \
    ${CESM_DEP_PREFIX}/bin/nc-config --cflags && \
    ${CESM_DEP_PREFIX}/bin/nc-config --libs && \
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdf.so && \
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdf.a && \
    cd / && rm -rf /tmp/netcdf-c*

# Export NetCDF-C location for NetCDF-Fortran and CESM
ENV NETCDF=${CESM_DEP_PREFIX}
ENV NETCDF_DIR=${CESM_DEP_PREFIX}
ENV NETCDF_C_ROOT=${CESM_DEP_PREFIX}

RUN cd /tmp && \
    curl -L https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz \
        -o netcdf-fortran.tar.gz && \
    tar -zxf netcdf-fortran.tar.gz && \
    mkdir netcdf-fortran-build && \
    cd netcdf-fortran-build && \
    cmake \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_Fortran_COMPILER=mpifc \
        -DCMAKE_C_FLAGS="-O2 -fPIC" \
        -DCMAKE_Fortran_FLAGS="-O2 -fPIC" \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_PREFIX_PATH=${CESM_DEP_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DNETCDF_C_LIBRARY=${CESM_DEP_PREFIX}/lib/libnetcdf.so \
        -DNETCDF_C_INCLUDE_DIR=${CESM_DEP_PREFIX}/include \
        -DHDF5_ROOT=${CESM_DEP_PREFIX} \
        -DENABLE_TESTS=OFF \
        -DENABLE_DOXYGEN=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_EXAMPLES=OFF \
        ../netcdf-fortran-4.6.1 \
    && \
    make -j$(nproc) && \
    make install && \
    # Second pass: static library
    cd /tmp && mkdir netcdf-fortran-build-static && \
    cd netcdf-fortran-build-static && \
    cmake \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_Fortran_COMPILER=mpifc \
        -DCMAKE_C_FLAGS="-O2 -fPIC" \
        -DCMAKE_Fortran_FLAGS="-O2 -fPIC" \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_PREFIX_PATH=${CESM_DEP_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DNETCDF_C_LIBRARY=${CESM_DEP_PREFIX}/lib/libnetcdf.a \
        -DNETCDF_C_INCLUDE_DIR=${CESM_DEP_PREFIX}/include \
        -DHDF5_ROOT=${CESM_DEP_PREFIX} \
        -DENABLE_TESTS=OFF \
        -DENABLE_DOXYGEN=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_EXAMPLES=OFF \
        ../netcdf-fortran-4.6.1 \
    && \
    make -j$(nproc) && \
    make install && \
    # Verify critical outputs
    ${CESM_DEP_PREFIX}/bin/nf-config --version && \
    ${CESM_DEP_PREFIX}/bin/nf-config --fc | grep -i "mpifc\|ifx" && \
    ${CESM_DEP_PREFIX}/bin/nf-config --fflags && \
    ${CESM_DEP_PREFIX}/bin/nf-config --flibs && \
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdff.so && \
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdff.a && \
    ls -la ${CESM_DEP_PREFIX}/include/netcdf.mod && \
    ls -la ${CESM_DEP_PREFIX}/include/typesizes.mod

COPY test_nf.f90 /tmp/
RUN cd /tmp && \
    mpifc -o test_nf test_nf.f90 \
        -I${CESM_DEP_PREFIX}/include \
        -L${CESM_DEP_PREFIX}/lib \
        -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lpnetcdf -lz && \
    ./test_nf && \
    rm -f test_output.nc && \
    cd / && rm -rf /tmp/netcdf-fortran* /tmp/test_nf*

ENV NETCDF_FORTRAN_ROOT=${CESM_DEP_PREFIX}

# Install other libraries
RUN yum install --nogpgcheck -y \
    python3 \
    python3-devel \
    libxml2-devel \
    git \
    subversion \
    make \
    which \
    wget \
    diffutils \
    file \
    bzip2 \
    bzip2-devel \
    xz \
    xz-devel \
    perl-XML-LibXML \
    openssh-clients \
    csh \
    hostname \
    environment-modules \
    && yum clean all && rm -rf /var/cache/yum

RUN cd /opt && \
    git clone -b release-cesm2.1.5 \
        https://github.com/ESCOMP/CESM.git cesm-2.1.5 && \
    cd cesm-2.1.5 && \
    ./manage_externals/checkout_externals

ENV CESM_SRCROOT=/opt/cesm-2.1.5
ENV NETCDF_PATH=${CESM_DEP_PREFIX}
ENV PNETCDF_PATH=${CESM_DEP_PREFIX}
ENV HDF5_PATH=${CESM_DEP_PREFIX}
ENV FCLIBS="-L/opt/intel/oneapi/compiler/2024.1/lib -L/opt/intel/oneapi/compiler/2024.1/opt/compiler/lib -lifcoremt -lifport -limf -lsvml -lirc -lirc_s -ldl -lm -lpthread"

COPY cesm-init.sh run_x_test_case.sh /opt/cesm-scripts/
COPY cime-config/* /opt/cime-confg/
RUN chmod +x /opt/cesm-scripts/*

RUN alternatives --set python /usr/bin/python3

CMD ["/bin/bash"]