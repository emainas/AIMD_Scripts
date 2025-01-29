#!/bin/bash
#
# Use this script to pluck frames from an MD trajectory with PBC and carve a sphere
# around the desired ambermask. TeraChem uses spherical boundary conditions so the carving
# is neccessary. This script builds one dir for each frame and creates all the inputs
# needed to run QM/MM calculations on that frame. The QM region file "region.qm" and 
# some detail like ion stripping cannot be automated and need case-by-case work. 
#
# (s.e.=self-explanatory)
#
# This script DOES NOT include: 1) autoimaging 2) Definition of the QM region
# These two things need to be done separately and carefully
#                                                                                           
#                                                                                          
#############################################################################################


# Prompt the user to input the number of frames

# Check to see if user provided correct number of flags (4)
if [ "$#" -ne 4 ]; then
   echo "Usage: $0 -parm parm_file -traj traj_file"
   exit 1
fi

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
      case $1 in
           -parm) parm_file="$2"; shift ;;
           -traj) traj_file="$2"; shift ;;
           *) echo "Unknown parameter passed: $1"; exit 1 ;;
      esac
      shift
done

# Check if input file exists
if [ ! -f "$parm_file" ]; then
   echo "Input file '$parm_file' not found!"
   exit 1
fi

# Check if input file exists
if [ ! -f "$traj_file" ]; then
   echo "Input file '$traj_file' not found!"
   exit 1
fi

read -p "Enter charge of qm region: " c
read -p "How long should each frame run (in hours - int number): " h
read -p "Enter number of frames: " N
read -p "Enter the total number of frames of the trajectory: " T
read -p "Enter ambermask to carve around: " ambermask
read -p "Enter number of atoms around carve mask: " n

# Pluck a frame every T/N step 
step = $((T / N)) 

# Load amber and make the cpptraj file based on the inputs

module load amber/22-CUDA_11.8-GCC11.2.0

for ((i=1; i<=$N; i++)); do
    cat <<EOF > cpptraj${i}.frame.in
parm $parm_file
trajin $traj_file
trajout frame${i}.rst7 onlyframes $((i * step)) notemperature notime restart multi nobox
go
EOF

    cat <<EOF > cpptraj${i}.carve.in
parm $parm_file
trajin frame${i}.rst7
strip @Cl-
closest ${n} :${ambermask} outprefix carved_${i}  center
trajout carved_frame${i}.rst7
go
EOF

    cat << EOF > tc.${i}.in 
prmtop nobox_${i}.parm7
coordinates carved_frame${i}.rst7
qmindices region.qm
basis 6-31gs
method b3lyp
precision mixed
charge ${c}
spinmult 1
gpumem 256
run md
nstep 2000 
timestep 0.5
mdbc spherical
EOF

    cat << EOF > tc.test.${i}.in
prmtop nobox_${i}.parm7
coordinates carved_frame${i}.rst7
qmindices region.qm
basis 6-31gs
method b3lyp
precision mixed
charge ${c}
spinmult 1
gpumem 256
run energy
EOF

    cat << EOF > run.${i}.sh
#!/bin/bash

#SBATCH -p l40-gpu
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J ${i}.${parm_file}
#SBATCH --mem=50G
#SBATCH -t ${h}:00:00
#SBATCH --qos gpu_access
#SBATCH --gres=gpu:1

ml tc/24.04

terachem tc.${i}.in > tc.${i}.out
EOF

    cat << EOF > run.test.${i}.sh
#!/bin/bash

#SBATCH -p elipierilab
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J ${i}.${parm_file}
#SBATCH --mem=50G
#SBATCH -t 1:00:00
#SBATCH --qos gpu_access
#SBATCH --gres=gpu:1
#SBATCH --nodelist=g1803pier01

ml tc/24.04

terachem tc.test.${i}.in > tc.test.${i}.out
EOF

    cat << EOF > parmed${i}.in
parm carved_${i}.${parm_file}
strip :Cl- nobox
outparm nobox_${i}.parm7
EOF

# Run cpptraj and parmed to frame-carve-remove box
cpptraj -i cpptraj${i}.frame.in
cpptraj -i cpptraj${i}.carve.in
parmed -i parmed${i}.in

# Make the slurm scripts executable
chmod +x run.${i}.sh
chmod +x run.test.${i}.sh
# Setup the folders and move everything in there
mkdir frame${i}
mv frame${i}.rst7 carved_${i}.${parm_file} nobox_${i}.parm7 carved_frame${i}.rst7 run.${i}.sh tc.${i}.in run.test.${i}.sh tc.test.${i}.in frame${i}
cp region.qm frame${i}
rm cpptraj${i}.frame.in cpptraj${i}.carve.in parmed${i}.in
echo "Pay attention to region.qm and charge!"

done

