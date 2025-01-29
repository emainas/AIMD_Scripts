#!/bin/bash

#SBATCH -p elipierilab
#SBATCH --nodelist=g1803pier03
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J pp.RESP
#SBATCH --mem=50G
#SBATCH -t 20:00:00
#SBATCH --qos gpu_access
#SBATCH --gres=gpu:1

ml tc/24.04

terachem resp.in > resp.out
