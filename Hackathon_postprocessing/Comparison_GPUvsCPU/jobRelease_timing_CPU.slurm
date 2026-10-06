#!/bin/bash -l
#SBATCH --job-name=femuss-cpu-timing
#SBATCH --account=project_465003392
#SBATCH --partition=standard-g
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --output=femuss-cpu-timing-%j.out

# CPU timing runs, no profiler.
# Partition standard-g on purpose: same node type (AMD Trento host) as the
# GPU runs, so CPU and GPU numbers come from the same hardware.
# --exclusive: no other jobs on the node, no timing noise.
#
# Before submitting: Sources/modules/temperGPU/temgpu_solite.f90 must
# contain the CPU version (temgpu_solite_CPU.f90).

NRUNS=3                    # repeat to check run-to-run stability
CASE=hackatonCase
BIN=../../Prog+Libs/Femuss/Executables/Unix/PFemuss.OMPICRAY

# 0. Environment: CPU build, no perftools (no instrumentation)
source ../../femusspaths
mpicray
echo "COMPILER = $COMPILER"
module list

# 1. Build. make clean removes any object compiled with profiling flags.
cd ../../Prog+Libs/Femuss/Executables/Unix/
make clean; make release NPROCS=16
cd - > /dev/null

# 2. Runs, one log per run
for i in $(seq 1 $NRUNS); do
    echo "=== CPU run $i ==="
    srun -u -n 1 $BIN $CASE -postprocessfolder post -restartfolder rst > run_cpu_${i}.log 2>&1
done

# 3. Summary: iterations, final residual and timings of every run
echo "=== summary ==="
grep -h "CG finished" run_cpu_*.log
grep -h "TIMING"      run_cpu_*.log
