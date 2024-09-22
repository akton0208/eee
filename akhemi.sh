#!/bin/bash

# 設定 heminetwork 資料夾的絕對路徑
HEMINETWORK_DIR="/root/heminetwork"

# 檢查並安裝 jq
function check_and_install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "jq 未安裝，正在安裝..."
        sudo apt-get update
        sudo apt-get install -y jq
        if [ $? -ne 0 ]; then
            echo "安裝 jq 失敗，請檢查你的包管理器。"
            exit 1
        fi
    else
        echo "jq 已安裝。"
    fi
}

# 檢查並切換到 heminetwork 目錄
function check_and_cd_heminetwork() {
    if [ ! -d "$HEMINETWORK_DIR" ]; then
        echo "解壓目錄不存在，請確認目錄名稱。"
        return 1
    fi

    cd "$HEMINETWORK_DIR" || { echo "切換目錄失敗。"; return 1; }
    return 0
}

# 安裝 HEMI MINER
function install_hemi_miner() {
    check_and_install_jq

    # 獲取最新版本號
    LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ]; then
        echo "無法獲取最新版本號，請檢查你的網絡連接或 GitHub API 限制。"
        exit 1
    fi

    echo "最新版本為: $LATEST_VERSION"

    # 下載並解壓最新版本
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        wget -q --show-progress -O heminetwork.tar.gz "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
        tar -xzf heminetwork.tar.gz
        mv heminetwork_${LATEST_VERSION}_linux_amd64 "$HEMINETWORK_DIR"
    elif [ "$ARCH" == "arm64" ]; then
        wget -q --show-progress -O heminetwork.tar.gz "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
        tar -xzf heminetwork.tar.gz
        mv heminetwork_${LATEST_VERSION}_linux_arm64 "$HEMINETWORK_DIR"
    else
        echo "不支持的架構: $ARCH"
        exit 1
    fi

    echo "HEMI MINER 安裝完成。"
    pause
    main_menu
}

# 生成 Public Key
function generate_public_key() {
    check_and_cd_heminetwork || exit 1

    if [ -f ~/popm-address.json ]; then
        echo "popm-address.json 已存在，跳過生成 Public Key 步驟。"
    else
        ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
        echo "Public Key 已生成，保存在 ~/popm-address.json"
    fi
    pause
    main_menu
}

# 顯示 Public Key
function show_public_key() {
    if [ -f ~/popm-address.json ]; then
        cat ~/popm-address.json
    else
        echo "Public Key 文件不存在，請先生成 Public Key。"
    fi
    pause
    main_menu
}

# 運行挖礦
function start_mining() {
    check_and_cd_heminetwork || exit 1

    if [ -f ~/popm-address.json ]; then
        POPM_BTC_PRIVKEY=$(jq -r '.private_key' ~/popm-address.json)
        export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY

        read -p "請設置 GAS 費用: " POPM_STATIC_FEE
        export POPM_STATIC_FEE=$POPM_STATIC_FEE

        export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public

        echo "最終運行命令:"
        echo "export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY"
        echo "export POPM_STATIC_FEE=$POPM_STATIC_FEE"
        echo "export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
        echo "nohup ./popmd &> popmd.log &"

        nohup ./popmd &> popmd.log &
        echo "挖礦程序已在後台運行，輸出記錄在 /root/heminetwork/popmd.log 文件中。"
    else
        echo "Public Key 文件不存在，請先生成 Public Key。"
    fi
    pause
    main_menu
}

# 查看日誌
function view_logs() {
    if [ -f "/root/heminetwork/popmd.log" ]; then
        tail -f "/root/heminetwork/popmd.log"
    else
        echo "日誌文件不存在。"
    fi
    pause
    main_menu
}

# 停止挖礦
function stop_mining() {
    pkill -f popmd
    echo "挖礦程序已停止。"
    pause
    main_menu
}

# 刪除所有有關文件
function delete_files() {
    rm -r "$HEMINETWORK_DIR"
    rm "heminetwork.tar.gz"
    echo "資料夾 heminetwork 和 heminetwork.tar.gz 已刪除，保留 /root/popm-address.json。"
    pause
    main_menu
}

# 暫停並等待按鍵
function pause() {
    read -n 1 -s -r -p "按任意鍵返回主選單"
}

# 主菜單
function main_menu() {
    clear
    echo "請選擇一個選項："
    echo "1. 安裝 HEMI MINER"
    echo "2. 生成 Public Key (注意!! 如已有popm-address.json就不需要運行, 不然會被覆蓋)"
    echo "3. 顯示 Public Key"
    echo "4. 運行挖礦 (先往第3步顯示的\"pubkey_hash\"，在錢包轉帳最少0.002tBTC)"
    echo "5. 查看日誌"
    echo "6. 停止挖礦"
    echo "7. 刪除所有有關文件 (保留 /root/popm-address.json)"
    echo "8. 退出"
    read -p "輸入選項 (1-8): " OPTION

    case $OPTION in
    1) install_hemi_miner ;;
    2) generate_public_key ;;
    3) show_public_key ;;
    4) start_mining ;;
    5) view_logs ;;
    6) stop_mining ;;
    7) delete_files ;;
    8) exit 0 ;;
    *) echo "無效選項。" ;;
    esac
}

# 顯示主菜單
main_menu
