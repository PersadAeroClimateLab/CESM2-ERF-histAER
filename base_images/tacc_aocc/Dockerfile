FROM rockylinux:8

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo https://linux.mellanox.com/public/repo/mlnx_ofed/5.6-2.0.9.0/rhel8.6/x86_64/ && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/linux.mellanox.com_public_repo_mlnx_ofed_5.6-2.0.9.0_rhel8.6_x86_64_.repo

RUN yum install -y \
    libibverbs libibverbs-devel libibverbs-utils \
    librdmacm librdmacm-devel librdmacm-utils \
    libibumad libibumad-devel \
    rdma-core rdma-core-devel \
    ucx ucx-ib ucx-rdmacm ucx-cma ucx-devel \
    numactl numactl-libs numactl-devel \
    libxml2 libxml2-devel \
    libstdc++ libstdc++-devel \
    ncurses-libs ncurses-devel \
    zlib zlib-devel \
    libquadmath libquadmath-devel \
    python39 git cmake \
    byacc make findutils file which wget ca-certificates xz \
    && yum clean all

ARG AOCC_VERSION=5.1.0
COPY aocc-compiler-${AOCC_VERSION}.tar /tmp/
RUN tar -xvf /tmp/aocc-compiler-${AOCC_VERSION}.tar -C /opt && \
    rm /tmp/aocc-compiler-${AOCC_VERSION}.tar && \
    cd /opt/aocc-compiler-${AOCC_VERSION}/ && \
    ./install.sh

ENV AOCC_PATH=/opt/aocc-compiler-5.1.0
ENV PATH=/usr/lib64:$AOCC_PATH/bin:$AOCC_PATH/share/opt-viewer:$PATH \
    LIBRARY_PATH=/usr/lib64:/usr/lib:$AOCC_PATH/lib:$LIBRARY_PATH \
    LD_LIBRARY_PATH=/usr/lib64:/usr/lib:$AOCC_PATH/ompd:$AOCC_PATH/lib:$LD_LIBRARY_PATH \
    C_INCLUDE_PATH=$AOCC_PATH/include \
    CPLUS_INCLUDE_PATH=$AOCC_PATH/include \
    CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$AOCC_PATH/include

RUN ln -s /usr/lib64/libstdc++.so.6 /usr/lib64/libstdc++.so

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
        CC=clang CXX=clang++ FC=flang F77=flang \
        CFLAGS="-O2 -march=znver3 -fPIC" \
        CXXFLAGS="-O2 -march=znver3 -fPIC" \
        FFLAGS="-O2 -march=znver3 -fPIC" \
        FCFLAGS="-O2 -march=znver3 -fPIC" \
        && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -r /tmp/mvapich2-2.3.7

ENV CC=mpicc CXX=mpicxx FC=mpifort F77=mpifort \
    MPICH_CC=clang MPICH_CXX=clang++ MPICH_FC=flang MPICH_F77=flang \
    CFLAGS="-O2 -march=znver3 -fPIC" \
    CXXFLAGS="-O2 -march=znver3 -fPIC" \
    FFLAGS="-O2 -march=znver3 -fPIC" \
    PATH=/opt/mvapich2/bin:$PATH \
    LD_LIBRARY_PATH=/opt/mvapich2/lib:$LD_LIBRARY_PATH 

RUN cd /tmp && \
    git clone https://github.com/amd/aocl.git --branch AOCL-5.2 && \
    cd aocl && \
    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DENABLE_ILP64=OFF \
        -DENABLE_AOCL_BLAS=ON \
        -DENABLE_AOCL_UTILS=ON \
        -DENABLE_AOCL_LAPACK=ON \
        -DENABLE_AOCL_SCALAPACK=ON \
        -DENABLE_AOCL_FFTW=ON \
        -DENABLE_AOCL_LIBM=ON \
        -DENABLE_MULTITHREADING=OFF \
        -DCMAKE_INSTALL_PREFIX=/opt/aocl-5.2 && \
    cmake --build build --config Release --target install && \
    cd / && rm -rf /tmp/aocl
