#!/bin/bash

apt update
apt install tmux -y

wget https://github.com/6block/zkwork_moz_prover/releases/download/v1.0.0/moz_prover_cuda.tar.gz

tar -zvxf moz_prover_cuda.tar.gz && cd moz_prover

# Run the specified command in the background using tmux
tmux new-session -d -s moz "./moz_prover --lumozpool moz.asia.zk.work:10010 --mozaddress 0x4890d518Fea7BD57F0Cca70b9c381b1ef733189c &> /root/moz.log"
