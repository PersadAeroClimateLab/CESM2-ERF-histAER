#!/bin/bash
set -e

exe="$1"
shift

module load tacc-apptainer

exec apptainer exec \
  --bind /dev/shm \
  --bind /scratch \
  --bind /work \
  --bind /tmp \
  --env-file /work/07644/oxygen/ls6/cesm_vars.env \
  /work/07644/oxygen/ls6/cesm2.1.5.sif \
  /tmp/cesm.exe "$@"