#!/bin/bash
export USER=$(whoami)

mkdir -p ~/.cime/
cp -nv /opt/cesm/docker_config_machines.xml ~/.cime/config_machines.xml
cp -nv /opt/cesm/docker_config_compilers.xml ~/.cime/config_compilers.xml

mkdir ~/cesm && cp -rv /opt/cesm ~/cesm

cd ${CASEDIR}
~/cesm/cime/scripts/create_newcase --case ${CASENAME} --compset ${COMPSET} --res ${RES} --walltime ${WALLTIME} -q ${QUEUE}
cd ${CASENAME}

NTASKS_ATM=640
NTHRDS_ATM=1
ROOTPE_ATM=0

NTASKS_CPL=640
NTHRDS_CPL=1
ROOTPE_CPL=0

NTASKS_LND=128
NTHRDS_LND=1
ROOTPE_LND=640

NTASKS_OCN=8
NTHRDS_OCN=1
ROOTPE_OCN=640

NTASKS_ICE=8
NTHRDS_ICE=1
ROOTPE_ICE=640

NTASKS_ROF=8
NTHRDS_ROF=1
ROOTPE_ROF=640

NTASKS_GLC=8
NTHRDS_GLC=1
ROOTPE_GLC=640

NTASKS_WAV=8
NTHRDS_WAV=1
ROOTPE_WAV=640

./xmlchange DOUT_S=TRUE
./xmlchange STOP_N=1
./xmlchange RESUBMIT=0
./xmlchange CAM_CONFIG_OPTS="-phys cam6 -cosp"
./xmlchange RUN_REFCASE=b.e21.B1850.f09_g17.CMIP6-piControl.001
./xmlchange RUN_REFDATE=${RUN_REFDATE}
./xmlchange RUN_TYPE=hybrid
./xmlchange GET_REFCASE=TRUE
./xmlchange RUN_STARTDATE=1850-01-01
./xmlchange STOP_OPTION=nyears
./xmlchange GMAKE_J=${GMAKE_J}
./xmlchange SSTICE_YEAR_ALIGN=1
./xmlchange SSTICE_YEAR_START=0
./xmlchange SSTICE_YEAR_END=0
./xmlchange SSTICE_DATA_FILENAME=${DIN_LOC_ROOT}/SSTICE/sstice_cmip6_pi-Control_clim_40101_200012_diddled.nc
./xmlchange NTASKS_ATM=$NTASKS_ATM,NTHRDS_ATM=$NTHRDS_ATM,ROOTPE_ATM=$ROOTPE_ATM
./xmlchange NTASKS_LND=$NTASKS_LND,NTHRDS_LND=$NTHRDS_LND,ROOTPE_LND=$ROOTPE_LND
./xmlchange NTASKS_OCN=$NTASKS_OCN,NTHRDS_OCN=$NTHRDS_OCN,ROOTPE_OCN=$ROOTPE_OCN
./xmlchange NTASKS_ICE=$NTASKS_ICE,NTHRDS_ICE=$NTHRDS_ICE,ROOTPE_ICE=$ROOTPE_ICE
./xmlchange NTASKS_CPL=$NTASKS_CPL,NTHRDS_CPL=$NTHRDS_CPL,ROOTPE_CPL=$ROOTPE_CPL
./xmlchange NTASKS_ROF=$NTASKS_ROF,NTHRDS_ROF=$NTHRDS_ROF,ROOTPE_ROF=$ROOTPE_ROF
./xmlchange NTASKS_GLC=$NTASKS_GLC,NTHRDS_GLC=$NTHRDS_GLC,ROOTPE_GLC=$ROOTPE_GLC
./xmlchange NTASKS_WAV=$NTASKS_WAV,NTHRDS_WAV=$NTHRDS_WAV,ROOTPE_WAV=$ROOTPE_WAV
./xmlchange PIO_VERSION=1

./case.setup
cp ~/cesm/case_config/* .