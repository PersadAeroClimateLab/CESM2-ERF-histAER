# CESM2-ERF-XAER
Files and instructions necessary for reproducing the f.e21.FHIST_BGC.f09_f09_mg17.RFMIP-ERF-XAER CESM2 runs at TACC or on a local machine.

## TACC Instructions

For now, the CESM Docker container must be built and converted to the apptainer `.sif` equivalent locally (or obtained via download) before uploading to TACC. To do this, you will need to install both [Docker](https://www.docker.com/) and [Apptainer](https://apptainer.org/docs/admin/main/installation.html).

### 0. Build the Container (optional if you have a copy already)

Run the following commands on your local PC to build the container image:

```
git clone https://github.com/PersadAeroClimateLab/CESM2-ERF-XAER.git
cd CESM2-ERF-XAER
docker build -t cesm .
apptainer build cesm2.1.5.sif docker-daemon://cesm:latest
```

### 1. Upload to TACC Filesystem

SSH into your TACC supercomputer of choice and then clone the repository to your scratch directory:

```
cd $SCRATCH
git clone https://github.com/PersadAeroClimateLab/CESM2-ERF-XAER.git
cd CESM2-ERF-XAER
```

Upload the container image `cesm2.1.5.sif` via `scp` or your file transfer tool of choice. Move the image to your work directory, for example:

```
scp cesm2.1.5.sif oxygen@ls6.tacc.utexas.edu:/work/07644/oxygen/
```

### 2. Configure the CESM2 paths

Assumming the container image is available at `$WORK/cesm2.1.5`

```
cd $SCRATCH/CESM2-ERF-XAER
cat cesm_vars.env
```

You should get some output that looks like this:

```
CIME_OUTPUT_ROOT=/scratch/07644/oxygen/cesm_cases/
CASEDIR=/scratch/07644/oxygen/cesm_cases/
DIN_LOC_ROOT=/scratch/07644/oxygen/cesm-input-data/
DOUT_S_ROOT=/scratch/07644/oxygen/cesm_cases/
BASELINE_ROOT=/scratch/07644/oxygen/cesm-input-data/
```

Configure the paths so that they use either your own scratch directory or another designated directory (such as a shared input data directory). It should be noted that `$WORK` is [not suitable for the functions of these directories](https://docs.tacc.utexas.edu/tutorials/managingio/) with the possible exception of `DIN_LOC_ROOT` (however using `$WORK` will result is slow start-up times). Once configured, you can set these variables for use within your shell and then create directories if needed:

```
source cesm_vars.env
mkdir -p $CIME_OUTPUT_ROOT
mkdir -p $CASEDIR
mkdir -p $DIN_LOC_ROOT
```

For optimal performance, it is reccomended to stripe these directories before transferring data to match the expected file size output and number of nodes reading/writing in parallel. For [lonestar6](https://docs.tacc.utexas.edu/hpc/lonestar6/#files), this is modified using `beegfs`. The case directory has a lot of small files that are built/read on a single node, so it should be striped to single disk.

```
beegfs-ctl --setpattern --numtargets=1 $CASEDIR
```

For other directories, the stripe parameter `numtargets` depends on the number of nodes being used.

| Directory      | 6 nodes | 20+ nodes |
| -------------- | ------- | -------- |
| `CASEDIR`      | 1       | 1        |
| `DIN_LOC_ROOT` | 4       | 8        |
| `DOUT_S_ROOT`  | 8       | 16       |

So for the current 6 node layout:

```
beegfs-ctl --setpattern --numtargets=4 $DIN_LOC_ROOT
beegfs-ctl --setpattern --numtargets=8 $DOUT_S_ROOT
```

### 3. Build the CESM2 Case

Building is CPU heavy and requires apptainer, so you must use a compute node. The quickest and simplest way is to use an interactive node in the development queue:

```
idev -A INSER_PROJECT_CODE_HERE -t 00:30:00 -N 1
```

Load apptainer and start a shell from the image with the appropriate environment variables:

```
module load tacc-apptainer
apptainer shell --env-file cesm_vars.env $WORK/cesm2.1.5
```

Call `generate_case.sh` to generate the case directory and apply the required XML changes and namelist modifications:

```
source generate_case.sh
```

Check the run to verify the correct changes were applied:

```
./preview_run
```

If everything looks good, build the case, exit the container (`CTL + D`), and exit the compute node (`CTL + D`) to return to the login node.

```
./case.build
```

From the login node, reload the environment variables and submit the case:

```
source $SCRATCH/CESM2-ERF-XAER/cesm_vars.env
cd $CASEDIR/$CASENAME
./case.submit
```