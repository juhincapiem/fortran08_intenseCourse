#!/bin/bash -l
#SBATCH --job-name=femuss
#SBATCH --nodes=1
##SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:30:00
#SBATCH --partition=standard
#SBATCH --hint=nomultithread
#SBATCH --account=project_465003392
#SBATCH --exclusive

source ../../femusspaths
mpicray
module load perftools
module list
export current=$PWD
export PAT_RT_TRACE_API=1

# 1. clean old results first
rm -rf results trace_profiling_CG_CPU PFemuss.OMPICRAY+pat+*/ PFemuss.OMPICRAY+pat
mkdir -p results

# 2. build and instrument
cd ../../Prog+Libs/Femuss/Executables/Unix/
make clean; make release
pat_build -w -u PFemuss.OMPICRAY
cd $current
mv ../../Prog+Libs/Femuss/Executables/Unix/PFemuss.OMPICRAY+pat .

# 3. run and report
srun -u -n 1 ./PFemuss.OMPICRAY+pat hackatonCase -postprocessfolder post -restartfolder rst
pat_report -T -o trace_profiling_CG_CPU PFemuss.OMPICRAY+pat+*/
rm ./PFemuss.OMPICRAY+pat