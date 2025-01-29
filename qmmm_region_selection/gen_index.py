import os
import pytraj as pt
import numpy as np

N = 20  # Set the number of frames

residue_list = np.loadtxt('list_residues.txt', usecols=0).astype(int)
residue_masks = ",".join([f":{residue}" for residue in residue_list])
backbone_masks = " & !@CA,HA,H,N,O,C,H1,H2,H3,HA2,HA3,Na"
selection_string = f"({residue_masks}){backbone_masks}"

for j in range(1, N + 1):  # Looping up to N
    base_path = f'./frame{j}ns/scr.carved_frame{j}ns/spectra{j}ns' # Control the path
    topfile = f'{base_path}/nobox_{j}ns.parm7' # Parameters file
    infile = f'{base_path}/coors.rst7' # Coordinates file
    outfile = f'{base_path}/qm.region' # Where to write the file with all the indexes for the QM region 

    traj = pt.load(infile, top=topfile)
    traj.top.set_reference(traj[0])

    protein = traj.top.select(selection_string) # Select protein indexes
    water = traj.top.select('(:339 <:5.0) & :WAT') # Select water indexes

    with open(outfile, "w") as file:
        for item in protein:
            file.write(f'{item}\n')
        for item in water:
            file.write(f'{item}\n')

