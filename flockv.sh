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
git clone https://github.com/FLock-io/llm-loss-validator.git

# Create a new Conda environment with Python 3.10
conda create -n llm-loss-validator python==3.10 -y

# Activate the new Conda environment
conda activate llm-loss-validator

# Install the required Python packages
pip install -r llm-loss-validator/requirements.txt

# Navigate to the specified directory
cd llm-loss-validator/src

# Run the specified command in the background using tmux
tmux new-session -d -s flock "CUDA_VISIBLE_DEVICES=0 TIME_SLEEP=180 bash start.sh --hf_token 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 --flock_api_key HH76CARFCS7INRBCIKOKBPSGR42DZ2HM --task_id 15 --validation_args_file validation_config.json.example --auto_clean_cache False --lora_only False &> /root/flock.log"
