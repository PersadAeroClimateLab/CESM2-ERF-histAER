FROM tacc/tacc-ubuntu18-mvapich2.3-ib:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    gpg \
    build-essential \
    libblas-dev \
    liblapack-dev \
    gfortran \
    openssl \
    libssl-dev \
    perl \
    ca-certificates \
    subversion \
    libxml-libxml-perl \
    libxml2-utils \
    libsdl2-dev \
    emacs \
    ninja-build \
    default-jdk \
    m4 \
    python \
    libxml2-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /scratch
RUN wget https://github.com/Kitware/CMake/releases/download/v3.24.0/cmake-3.24.0.tar.gz && \
    tar -xzvf cmake-3.24.0.tar.gz && \
    wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.6/hdf5-1.14.6.tar.gz && \
    tar -xzvf hdf5-1.14.6.tar.gz && \
    wget https://parallel-netcdf.github.io/Release/pnetcdf-1.14.1.tar.gz && \
    tar -xzvf pnetcdf-1.14.1.tar.gz && \
    wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz && \
    tar -xzvf netcdf-c-4.9.2.tar.gz && \
    wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz && \
    tar -xzvf netcdf-fortran-4.6.1.tar.gz

WORKDIR /scratch/cmake-3.24.0
RUN ./bootstrap && make -j$(nproc) && make install

WORKDIR /scratch/hdf5-1.14.6
RUN CC=mpicc ./configure --enable-parallel --prefix=/usr && \
    make -j$(nproc) && make install

WORKDIR /scratch/pnetcdf-1.14.1
RUN CC=mpicc CPPFLAGS="-I/usr/include" LDFLAGS="-L/usr/lib" \
    ./configure --enable-pnetcdf --enable-parallel-tests --prefix=/usr && \
    make -j$(nproc) && make install

WORKDIR /scratch/netcdf-c-4.9.2
RUN CC=mpicc CPPFLAGS="-I/usr/include" LDFLAGS="-L/usr/lib" \
    ./configure --enable-pnetcdf --disable-shared --enable-parallel-tests --prefix=/usr && \
    make -j$(nproc) && make install

WORKDIR /scratch/netcdf-fortran-4.6.1
RUN CC=mpicc FC=mpif90 F77=mpif77 FC=mpif90 CPPFLAGS=-I/usr/include LDFLAGS="-L/usr/lib" \
    LD_LIBRARY_PATH=/usr/lib:${LD_LIBRARY_PATH} \
    LIBS="-L/usr/lib -lnetcdf -lpnetcdf -lhdf5_hl -lhdf5 -lm -lz -lxml2 -lcurl" \
    ./configure --disable-shared --enable-pnetcdf --disable-byterange --prefix=/usr && \
    make -j$(nproc) && make install

RUN rm -r /scratch

WORKDIR /opt
RUN git clone https://github.com/escomp/cesm.git cesm
WORKDIR /opt/cesm

RUN git checkout release-cesm2.1.5 && \
    ./manage_externals/checkout_externals && \
    ./manage_externals/checkout_externals -S 

COPY docker_config_machines.xml docker_config_compilers.xml docker_config_batch.xml generate_case.sh /opt/cesm/
RUN chmod +x /opt/cesm/generate_case.sh

COPY case_config/ /opt/cesm/case_config

RUN ln -s /opt/cesm/cime/scripts/create_newcase /usr/local/bin/create_newcase && \
    ln -s /opt/cesm/cime/scripts/create_clone /usr/local/bin/create_clone && \
    ln -s /opt/cesm/cime/scripts/create_test /usr/local/bin/create_test && \
    ln -s /opt/cesm/cime/scripts/query_config /usr/local/bin/query_config && \
    ln -s /opt/cesm/cime/scripts/create_test /usr/local/bin/query_testlists && \
    ln -s /usr/bin/make /usr/local/bin/gmake

ENV OMP_NUM_THREADS=1
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

CMD ["source", "/opt/cesm/generate_case.sh"]
