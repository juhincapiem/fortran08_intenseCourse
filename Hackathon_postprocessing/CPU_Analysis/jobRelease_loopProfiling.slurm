#!/bin/bash -l
#SBATCH --job-name=femuss
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:30:00
#SBATCH --partition=standard-g
#SBATCH --hint=nomultithread
#SBATCH --account=project_465003392
#SBATCH --exclusive

# 0. Environment: CPU build + CrayPat
source ../../femusspaths
mpicray
module load perftools
echo $COMPILER
module list
export current=$PWD

# 1. Clean old results and old CrayPat experiments FIRST
rm -rf results loop_profiling_CG_CPU PFemuss.OMPICRAY+pat+*/ PFemuss.OMPICRAY+pat
mkdir -p results

# 2. Build and instrument
cd ../../Prog+Libs/Femuss/Executables/Unix/
make clean; make release NPROCS=16
pat_build -w -u -g mpi,petsc PFemuss.OMPICRAY
cd $current
mv ../../Prog+Libs/Femuss/Executables/Unix/PFemuss.OMPICRAY+pat .

# 3. Run the instrumented binary
srun -u -n 1 ./PFemuss.OMPICRAY+pat hackatonCase -postprocessfolder post -restartfolder rst

# 4. Report, then remove the instrumented binary
pat_report -o loop_profiling_CG_CPU PFemuss.OMPICRAY+pat+*/
rm ./PFemuss.OMPICRAY+pat