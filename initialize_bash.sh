#!/bin/bash

HOME01="/home/martin.johansson"
HOME02="/network/iss/home/martin.johansson"

# CLUSTER
# Enter login node
ssh -X martin.johansson@sphpc-login02 
# Allocate resources
salloc -p medium -n 1 -c 4 --mem=30G -t 04:00:00 --exclude=sphpc-cpu20 -J "InteractiveSession"
# Check which hostname resources were allocated to (same as NODELIST)
squeue -u martin.johansson
# Enter compute node
ssh -X sphpc-cpu22
ssh -4 -L 8888:localhost:8888 sphpc-cpu05
# From here, load modules of interest
# When you're done, close the whole thing by typing exit three times

# Set up python environments
# Can be tricky due to anaconda migration
# -k avoids certificate errors
# python=3 will not work due to permissions
module load miniforge
conda create --name test_env python=3.12 -k


# BIDSCOIN
module load miniforge
# Set up python env
# python -m venv bidscoin # creates python environment (/network/iss/home/martin.johansson/bidscoin)
# Load binaries
source /network/iss/home/martin.johansson/bidscoin/bin/activate
# Install
# pip install bidscoin



