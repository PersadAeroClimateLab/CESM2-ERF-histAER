#!/usr/bin/env bash

ulimit -s unlimited
export USER=$(whoami)
cd /scratch
rm -rf *
cd /root/cases
/opt/cesm-2.1.5/cime/scripts/create_newcase --case "test_X_infrastructure" --machine container_intel --compset X --res f19_g17 --run-unsupported
cd test_X_infrastructure
./xmlchange NTASKS=4
./case.setup
./case.build --clean-all
./case.build
./case.submit