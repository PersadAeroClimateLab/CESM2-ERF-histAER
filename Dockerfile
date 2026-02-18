FROM rockylinux:9

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo \
      https://linux.mellanox.com/public/repo/mlnx_ofed/5.6-2.0.9.0/rhel8.6/mellanox_mlnx_ofed.repo && \
    yum-config-manager --setopt="mlnx_ofed*".priority=10 --save && \
    yum install -y --exclude=libfabric* \
      rdma-core \
      rdma-core-devel \
      libibverbs-utils \
      libibverbs-devel \
      librdmacm \
      librdmacm-utils \
      numactl-libs numactl \
      ucx \
      ucx-cma \
      ucx-ib \
      ucx-rdmacm \
      ucx-devel \
      gcc-toolset-15-libstdc++-devel g++ \
      libxml2 libxml2-devel \
      libgfortran \
      libibmad-devel libibumad \
    #   gcc gfortran \
      libquadmath libquadmath-devel \
      make findutils emacs byacc ca-certificates \
      ncurses-devel file zlib python3 xz which wget \
    && yum clean all

# Verify RDMA install
RUN ibv_devices 2>&1 || true && \
    ls -la /usr/lib64/libibverbs* && \
    ls -la /usr/lib64/libmlx5*

SHELL ["/bin/bash", "-c"]

WORKDIR /opt
COPY aocc-compiler-5.1.0.tar .

RUN cd /opt && \
    tar -xvf aocc-compiler-5.1.0.tar && \
    cd aocc-compiler-5.1.0/ && \
    ./install.sh && \
    cd /opt && \
    rm aocc-compiler-5.1.0.tar

ENV AOCC_PATH=/opt/aocc-compiler-5.1.0
ENV PATH=/usr/lib64:$AOCC_PATH/bin:$AOCC_PATH/share/opt-viewer:$PATH \
    LIBRARY_PATH=/usr/lib64:/usr/lib:$AOCC_PATH/lib:$LIBRARY_PATH \
    LD_LIBRARY_PATH=/usr/lib64:/usr/lib:$AOCC_PATH/ompd:$AOCC_PATH/lib:$LD_LIBRARY_PATH \
    C_INCLUDE_PATH=$AOCC_PATH/include \
    CPLUS_INCLUDE_PATH=$AOCC_PATH/include \
    CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$AOCC_PATH/include

WORKDIR /opt/cesm-deps

ENV CESM_DEP_PREFIX=/opt/cesm-deps
ENV PATH=${CESM_DEP_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LD_LIBRARY_PATH}
ENV LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LIBRARY_PATH}
ENV CPATH=${CESM_DEP_PREFIX}/include:${CPATH}
ENV PKG_CONFIG_PATH=${CESM_DEP_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
ENV CMAKE_PREFIX_PATH=${CESM_DEP_PREFIX}:${CMAKE_PREFIX_PATH}

COPY simple_compiler_tests/* /tmp/

RUN cd /tmp && \
    clang hello.c -o hello_c && \
    ./hello_c && \
    clang++ hello.cpp -o hello_cpp && \
    ./hello_cpp && \
    flang hello.f90 -o hello_f90 && \
    ./hello_f90 && \
    flang hello.f -o hello_f && \
    ./hello_f

RUN cd /tmp && \
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-2.3.7.tar.gz && \
    gzip -dc mvapich2-2.3.7.tar.gz | tar -x && \
    cd mvapich2-2.3.7 && \
    CC=clang CXX=clang++ FC=flang F77=flang ./configure \
        --prefix=/usr/local \
        --with-ch3-rank-bits=32 \
        --enable-fortran=yes \
        --enable-cxx=yes \
        --enable-romio \
        --disable-static \
        --enable-shared \
        --enable-hybrid \
        --enable-g=dbg \
        --enable-threads=multiple \
        CFLAGS="-pipe -g -O2 -fno-strict-aliasing" \
        CXXFLAGS="-pipe -g -O2 -fno-strict-aliasing" \
        FCFLAGS="-g -O2" \
        FFLAGS="-pipe -w -g -O2" \
        && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -r /tmp/mvapich2-2.3.7

ENV CC=mpicc \
    CXX=mpicxx \
    FC=mpifort \
    F77=mpifort \
    MPICH_CC=clang \
    MPICH_CXX=clang++ \
    MPICH_FC=flang \
    MPICH_F77=flang \
    CFLAGS="-O2 -march=znver3 -fPIC" \
    CXXFLAGS="-O2 -march=znver3 -fPIC" \
    FFLAGS="-O2 -march=znver3 -fPIC" \
    LDFLAGS=""

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

RUN cd /tmp && \
    curl -L https://ftpmirror.gnu.org/libtool/libtool-2.5.4.tar.gz -o libtool.tar.gz && \
    tar -zxf libtool.tar.gz && \
    cd libtool-2.5.4 && \
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

# ---------------------------------------------------------------------------
# zlib 1.3.1
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz \
        -o zlib.tar.gz && \
    tar -zxf zlib.tar.gz && \
    cd zlib-1.3.1 && \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --static && \
    make -j$(nproc) && \
    make install

# ---------------------------------------------------------------------------
# libaec 1.1.5
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/MathisRosenhauer/libaec/releases/download/v1.1.5/libaec-1.1.5.tar.gz \
        -o libaec.tar.gz && \
    tar -zxf libaec.tar.gz && \
    cd libaec-1.1.5 && \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --enable-static && \
    make -j$(nproc) && \
    make install

# ---------------------------------------------------------------------------
# AOCL 5.2 - BLAS, LAPCK, M
# ---------------------------------------------------------------------------  
RUN cd /tmp && \
    git clone https://github.com/amd/aocl.git --branch AOCL-5.2 && \
    cd aocl && \
     cmake \ 
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_ILP64=OFF \
        -DENABLE_AOCL_BLAS=ON \
        -DENABLE_AOCL_UTILS=ON \
        -DENABLE_AOCL_LAPACK=ON \
        -DENABLE_AOCL_LIBM=ON \
        -DENABLE_MULTITHREADING=OFF \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} && \
    cmake --build build --config release --target install && \
    cd / && rm -rf /tmp/aocl

# ---------------------------------------------------------------------------
# HDF5 1.14.6
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_6/downloads/hdf5-1.14.6.tar.gz \
        -o hdf5.tar.gz && \
    tar -zxf hdf5.tar.gz && \
    cd hdf5-1.14.6 && \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --with-zlib=${CESM_DEP_PREFIX} \
        --enable-parallel \
        --enable-fortran \
        --enable-hl \
        --enable-static \
        --enable-build-mode=production \
        --disable-cxx \
        --disable-threadsafe \
        --disable-doxygen-doc \
        --enable-file-locking=no \
        --enable-direct-vfd \
        --disable-nonstandard-feature-float16 && \
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
# PnetCDF 1.14.1
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://parallel-netcdf.github.io/Release/pnetcdf-1.14.1.tar.gz \
        -o pnetcdf.tar.gz && \
    tar -zxf pnetcdf.tar.gz && \
    cd pnetcdf-1.14.1 && \ 
    # # Update tool chain to work with new intel compilers
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --enable-fortran \
        --enable-large-file-test \
        --enable-static \
        --disable-cxx \
        --disable-debug \
        --disable-profiling \
        --enable-burst-buffering  \
        --enable-thread-safe && \
    make -j$(nproc) && \
    make install && \
    # Verify critical outputs
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --version && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --cflags && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --libs && \
    ${CESM_DEP_PREFIX}/bin/pnetcdf-config --has-fortran | grep -i yes && \
    ls -la ${CESM_DEP_PREFIX}/lib/libpnetcdf.a && \
    cd / && rm -rf /tmp/pnetcdf*

# # Export PnetCDF location for downstream NetCDF-C
ENV PNETCDF=${CESM_DEP_PREFIX}
ENV PNETCDF_DIR=${CESM_DEP_PREFIX}

# ---------------------------------------------------------------------------
# NetCDF-C 4.9.3
# ---------------------------------------------------------------------------
RUN cd /tmp && \
    curl -L https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.3.tar.gz \
        -o netcdf-c.tar.gz && \
    tar -zxf netcdf-c.tar.gz && \
    cd netcdf-c-4.9.3 && \
    cmake \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_PREFIX=${CESM_DEP_PREFIX} \
        -DCMAKE_PREFIX_PATH=${CESM_DEP_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DHDF5_ROOT=${CESM_DEP_PREFIX} \
        -DZLIB_LIBRARY=${CESM_DEP_PREFIX}/lib/libz.a \
        -DZLIB_INCLUDE_DIR=${CESM_DEP_PREFIX}/include \
        -DNETCDF_ENABLE_HDF5=ON \
        -DNETCDF_ENABLE_PNETCDF=ON \
        -DNETCDF_ENABLE_PARALLEL4=ON \
        -DNETCDF_ENABLE_DAP=OFF \
        -DNETCDF_ENABLE_TESTS=OFF \
        -DNETCDF_ENABLE_EXAMPLES=OFF \
        -DBUILD_SHARED_LIBS=OFF && \
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
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdf.a
    # && \
    # cd / && rm -rf /tmp/netcdf-c*

# Export NetCDF-C location for NetCDF-Fortran and CESM
ENV NETCDF=${CESM_DEP_PREFIX}
ENV NETCDF_DIR=${CESM_DEP_PREFIX}
ENV NETCDF_C_ROOT=${CESM_DEP_PREFIX}
ENV LIBS="-L/opt/cesm-deps/lib -lnetcdf -lhdf5_hl -lhdf5 -lpnetcdf -lxml2 -lz -lm -ldl"

RUN cd /tmp && \
    curl -L https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.2.tar.gz \
        -o netcdf-fortran.tar.gz && \
    tar -zxf netcdf-fortran.tar.gz && \
    cd netcdf-fortran-4.6.2 && \
    ./configure \
        --prefix=${CESM_DEP_PREFIX} \
        --disable-shared && \
    make -j$(nproc) && \
    make install  && \
    # Verify critical outputs
    ${CESM_DEP_PREFIX}/bin/nf-config --fc | grep -i "mpifort" && \
    ${CESM_DEP_PREFIX}/bin/nf-config --version && \
    ${CESM_DEP_PREFIX}/bin/nf-config --fflags && \
    ${CESM_DEP_PREFIX}/bin/nf-config --flibs && \
    ls -la ${CESM_DEP_PREFIX}/lib/libnetcdff.a && \
    ls -la ${CESM_DEP_PREFIX}/include/netcdf.mod && \
    ls -la ${CESM_DEP_PREFIX}/include/typesizes.mod && \
    rm -r /tmp/*

COPY test_nf.f90 /tmp/
RUN cd /tmp && \
    mpifort -o test_nf test_nf.f90 \
        -I${CESM_DEP_PREFIX}/include \
        -L${CESM_DEP_PREFIX}/lib \
        -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lpnetcdf -lz && \
    ./test_nf && \
    rm -f test_output.nc && \
    cd / && rm -rf /tmp/test_nf*

ENV NETCDF_FORTRAN_ROOT=${CESM_DEP_PREFIX}

# Install other libraries
RUN yum install --nogpgcheck -y \
    python3-devel \
    libxml2-devel \
    subversion \
    wget \
    diffutils \
    bzip2 \
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

COPY cesm-init.sh run_x_test_case.sh /opt/cesm-scripts/
COPY cime-config/* /opt/cime-confg/
RUN chmod +x /opt/cesm-scripts/*

RUN alternatives --install /usr/bin/python python /usr/bin/python3 1

CMD ["/bin/bash"]