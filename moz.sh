#!/bin/bash

# 默認地址
DEFAULT_ADDRESS="0x4890d518Fea7BD57F0Cca70b9c381b1ef733189c"

# 使用提供的地址參數，否則使用默認地址
ADDRESS=${1:-$DEFAULT_ADDRESS}

# Function to display the menu
show_menu() {
    echo "選擇一個選項:"
    echo "1) 下載"
    echo "2) 執行"
    echo "3) 顯示 moz.log 的內容"
    echo "4) 停止 tmux 的 moz 會話 及刪除檔案"
    echo "5) 退出"
}

# Function to update and install tmux, download and extract moz_prover
run_download() {
    echo "1) 更新並安裝 tmux"
    apt update
    apt install tmux curl wget -y

    echo "1) 下載並解壓縮 moz_prover"
    cd ~
    wget -O moz_prover_cuda.tar.gz https://github.com/6block/zkwork_moz_prover/releases/download/v1.0.0/moz_prover_cuda.tar.gz
    tar -zvxf moz_prover_cuda.tar.gz
}

# Function to run miner
run_miner() {
    tmux new-session -d -s moz "/root/moz_prover/moz_prover --lumozpool moz.asia.zk.work:10010 --mozaddress $ADDRESS &> /root/moz.log"
}

# Function to display the contents of moz.log
show_moz_log() {
    tail -f /root/moz.log
}

# Function to stop the tmux session running moz_prover
stop_moz_tmux() {
    tmux kill-session -t moz
    echo "tmux 的 moz 會話已停止"
    cd ~
    rm moz_prover_cuda.tar.*
    rm -r moz_prover
}

# Main script logic
while true; do
    show_menu
    read -p "輸入選項 [1-4]: " choice
    case $choice in
        1) run_download ;;
        2) run_miner ;;
        3) show_moz_log ;;
        4) stop_moz_tmux ;;
        5) echo "退出"; exit 0 ;;
        *) echo "無效選項，請重新輸入";;
    esac
done
