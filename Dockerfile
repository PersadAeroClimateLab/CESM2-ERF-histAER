FROM tacc_gnu_base:latest

WORKDIR /opt/cesm-deps

ENV CESM_DEP_PREFIX=/opt/cesm-deps
ENV PATH=${CESM_DEP_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LD_LIBRARY_PATH}
ENV LIBRARY_PATH=${CESM_DEP_PREFIX}/lib:${LIBRARY_PATH}
ENV CPATH=${CESM_DEP_PREFIX}/include:${CPATH}
ENV PKG_CONFIG_PATH=${CESM_DEP_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
ENV CMAKE_PREFIX_PATH=${CESM_DEP_PREFIX}:${CMAKE_PREFIX_PATH}

RUN yum update -y && yum install --nogpgcheck -y \
    procps m4 perl \
    libcurl-devel python3-devel libxml2-devel \
    subversion diffutils bzip2 perl-XML-LibXML \
    openssh-clients csh hostname environment-modules \
    && yum clean all && rm -rf /var/cache/yum

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
        -DZLIB_LIBRARY=/usr/lib64/libz.so \
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

ENV NETCDF_FORTRAN_ROOT=${CESM_DEP_PREFIX} \
    NETCDF_FORTRAN_PATH=${CESM_DEP_PREFIX} \
    NETCDF_PATH=${CESM_DEP_PREFIX} \
    NETCDF_C_ROOT=${CESM_DEP_PREFIX} \
    NETCDF_C_PATH=${CESM_DEP_PREFIX}

RUN cd /opt && \
    git clone -b release-cesm2.1.5 \
        https://github.com/ESCOMP/CESM.git cesm-2.1.5 && \
    cd cesm-2.1.5 && \
    ./manage_externals/checkout_externals

ENV CESM_SRCROOT=/opt/cesm-2.1.5

COPY cesm-init.sh run_x_test_case.sh /opt/cesm-scripts/
COPY cime-config/* /opt/cime-confg/
RUN chmod +x /opt/cesm-scripts/*

RUN alternatives --set python /usr/bin/python3.9

CMD ["/bin/bash"]