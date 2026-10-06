#!/bin/bash -l
#SBATCH --job-name=femuss-rocprof
#SBATCH --account=project_465003392
#SBATCH --partition=standard-g
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --output=femuss-rocprof-%j.out

# GPU timeline with rocprofv3, viewable in Perfetto (https://ui.perfetto.dev).
# Records: HIP API calls (host side), kernel executions and memory copies
# host <-> device, plus per-kernel statistics in CSV.
#
# Use this run to SEE what happens and when. Do not use its times for the
# CPU/GPU comparison: the profiler adds overhead. Timings come from
# jobRelease_timing_GPU.slurm.
#
# The binary must be the GPU version WITHOUT CrayPat instrumentation
# (plain `make release`, perftools not loaded).

CASE=hackatonCase
BIN=/project/project_465003392/cimne_femuss-team/Prog+Libs/Femuss/Executables/Unix/PFemuss.OMPICRAYGPU
OUTDIR=rocprof_${SLURM_JOB_ID}

# 0. Environment
source ../../femusspaths
mpicrayGPU                 # loads partition/G, which brings its own ROCm
echo "COMPILER = $COMPILER"
module list

# rocprofv3 should already be in the PATH with the ROCm of partition/G.
# Only load the rocm module if it is missing, to avoid mixing ROCm versions
# between the build and the profiler.
if ! command -v rocprofv3 > /dev/null; then
    module load rocm
fi
which rocprofv3
rocprofv3 --version

export OMP_TARGET_OFFLOAD=MANDATORY   # abort instead of silently running on the CPU

# 1. Clean output folder
rm -rf $OUTDIR
mkdir -p $OUTDIR

# 2. Run under rocprofv3
#   --hip-trace           host-side HIP API calls (launches, waits, copies)
#   --kernel-trace        every kernel execution on the GPU
#   --memory-copy-trace   every host <-> device copy, with its size
#   --stats               per-kernel totals (calls, total and mean time)
#   --output-format       pftrace for Perfetto, csv for the statistics
srun -u -n 1 rocprofv3 \
    --hip-trace --kernel-trace --memory-copy-trace \
    --stats \
    --output-format pftrace csv \
    -d $OUTDIR -o femuss \
    -- $BIN $CASE -postprocessfolder post -restartfolder rst

# 3. Summary and generated files
echo "=== solver summary ==="
grep "CG finished" run_rocprof_${SLURM_JOB_ID}.log
grep "TIMING"      run_rocprof_${SLURM_JOB_ID}.log

echo "=== generated files ==="
find $OUTDIR -type f \( -name "*.pftrace" -o -name "*stats*.csv" \) | sort
