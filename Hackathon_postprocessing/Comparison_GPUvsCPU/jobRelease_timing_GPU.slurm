#!/bin/bash -l
#SBATCH --job-name=femuss-gpu-timing
#SBATCH --account=project_465003392
#SBATCH --partition=standard-g
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --output=femuss-gpu-timing-%j.out

# GPU timing runs, no profiler.
# --exclusive: no other jobs on the node, no timing noise
# (it bills the whole node; for quick functional tests use small-g).
#
# Before submitting: Sources/modules/temperGPU/temgpu_solite.f90 must
# contain the GPU version (temgpu_solite_GPU.f90).

NRUNS=3                    # repeat to check run-to-run stability
CASE=hackatonCase
BIN=../../Prog+Libs/Femuss/Executables/Unix/PFemuss.OMPICRAYGPU

# 0. Environment: GPU build, no perftools (no instrumentation)
source ../../femusspaths
mpicrayGPU
echo "COMPILER = $COMPILER"
module list
ftn --version | tail -1    # must end in amdgcn-gfx90a

export OMP_TARGET_OFFLOAD=MANDATORY   # abort instead of silently running on the CPU

# 1. Build. make clean removes any object compiled with profiling flags.
cd ../../Prog+Libs/Femuss/Executables/Unix/
make clean; make release NPROCS=16
cd - > /dev/null

# 2. Runs, one log per run
for i in $(seq 1 $NRUNS); do
    echo "=== GPU run $i ==="
    srun -u -n 1 $BIN $CASE -postprocessfolder post -restartfolder rst > run_gpu_${i}.log 2>&1
done

# 3. Summary: iterations, final residual and timings of every run
echo "=== summary ==="
grep -h "CG finished" run_gpu_*.log
grep -h "TIMING"      run_gpu_*.log
