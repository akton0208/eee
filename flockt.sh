#!/bin/bash

apt update
apt install tmux -y

# Download the Miniconda installer script
wget -O Miniconda3-latest-Linux-x86_64.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

# Add execute permissions to the installer script
chmod +x Miniconda3-latest-Linux-x86_64.sh

# Run the installer script
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda

# Initialize Miniconda
$HOME/miniconda/bin/conda init

# Apply the changes made by conda init
eval "$($HOME/miniconda/bin/conda shell.bash hook)"

# Clone the specified GitHub repository
git clone https://github.com/akton0208/testnet-training-node-quickstart.git

# Create a new Conda environment with Python 3.10
conda create -n training-node python==3.10

# Activate the new Conda environment
conda activate training-node

# Install the required Python packages
pip install -r testnet-training-node-quickstart/requirements.txt

# Navigate to the specified directory
cd testnet-training-node-quickstart

# Run the specified command in the background using tmux
tmux new-session -d -s flock "TASK_ID=13 FLOCK_API_KEY="XZPOOFV8AQ9EIHDH5T2LS4MMJZ03C8NX" HF_TOKEN="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" CUDA_VISIBLE_DEVICES=0 HF_USERNAME="Akchacha" python full_automation.py --auto_clean_cache False &> /root/flock.log"
