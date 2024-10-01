#!/bin/bash

# 激活虛擬環境
source $HOME/vana-dlp-chatgpt/myenv/bin/activate
source $HOME/.bash_profile

# 設置絕對路徑
VANA_CLI_PATH="/root/vana-dlp-chatgpt/vanacli"
VANA_DLP_CHATGPT_PATH="/root/vana-dlp-chatgpt"
LOG_DIR="/root/vanalog"
CONFIG_FILE="/root/vanalog/config.txt"

# 創建日誌資料夾
mkdir -p "$LOG_DIR"
# 檢查 config.txt 是否存在，如果不存在則創建並寫入內容
if [ ! -f "$LOG_DIR/config.txt" ]; then
    cat <<EOL > "$LOG_DIR/config.txt"
DEPLOYER_PRIVATE_KEY=$A
COLDADDRESS=$B
HOTADDRESS=$C
OPENAI_API_KEY=$D
DLP_MOKSHA_CONTRACT=$E
DLP_TOKEN_MOKSHA_CONTRACT=$F
PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$G
EOL
else
    echo "config.txt 已存在，跳過創建。"
fi

# 選單函數
show_menu() {
    echo "1. 安裝需要文件"
    echo "2. 創建錢包"
    echo "3. 導出冷錢包私鑰(這步驟會導出到/root/vanalog/coldkey.log方便查看)"
    echo "4. 導出熱錢包私鑰(這步驟會導出到/root/vanalog/hotkey.log方便查看)"
    echo "5. 設置智能合約環境(這步驟會導出到/root/vanalog/contract.log方便查看)"
    echo "6. 設置驗證器,如運行成功就CTRL+C關掉用步驟7後台運行"
    echo "7. 設置驗證器服務"
    echo "8. 查看驗證器日誌"
    echo "9. 停上第7步的運行狀態"
    echo "10. 刪除所有文件(只保留vanalog)"
    echo "11. 退出"
}

# 檢查命令是否存在的函數
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_files() {
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl wget jq make gcc nano git software-properties-common

    # 安裝 Node.js 和 npm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.bash_profile
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> $HOME/.bash_profile
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    nvm install --lts
    node -v
    npm -v

    # 安裝 Yarn
    npm install -g yarn

    # 安裝 Python
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip
    curl -sSL https://install.python-poetry.org | python3 -
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    python3.11 --version

    # Clone GPT
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    cd $HOME/vana-dlp-chatgpt/

    # 配置環境
    python3.11 -m venv myenv
    source myenv/bin/activate
    pip install --upgrade pip
    pip install poetry
    pip install python-dotenv
    poetry install
    pip install vana

    # 在虛擬環境中安裝 nvm, Node.js, npm 和 Yarn
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 18
    nvm use 18
    npm install -g yarn

    # 將虛擬環境激活命令添加到 .bashrc
    echo 'source $HOME/vana-dlp-chatgpt/myenv/bin/activate' >> $HOME/.bashrc
    echo "部署完成..."
}


# 創建錢包的函數
create_wallet() {
    echo "創建錢包..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet create --wallet.name default --wallet.hotkey default 2>&1 | tee "$LOG_DIR/wallet.log" || { echo "創建錢包失敗"; exit 1; }
    echo "錢包創建完成，詳情請查看 $LOG_DIR/wallet.log"
}

# 導出冷錢包私鑰的函數
export_coldkey() {
    echo "導出冷錢包私鑰..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet export_private_key 2>&1 | tee "$LOG_DIR/coldkey.log"
    read -p "請輸入冷錢包私鑰: " A
    echo "私鑰已成功輸入並賦值給變數 \$A: $A"
    read -p "請輸入冷錢包地址: " B
    echo "DEPLOYER_PRIVATE_KEY=$A" > "$LOG_DIR/config.txt"
    echo "COLDADDRESS=$B" >> "$LOG_DIR/config.txt"
    echo "更新後的 config.txt 文件內容:"
    cat "$LOG_DIR/config.txt"
}

# 導出熱錢包私鑰的函數
export_hotkey() {
    echo "導出熱錢包私鑰..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet export_private_key 2>&1 | tee "$LOG_DIR/hotkey.log" || { echo "導出熱錢包私鑰失敗"; exit 1; }
    echo "熱錢包私鑰已導出到 $LOG_DIR/hotkey.log"
    read -p "請輸入熱錢包地址: " C
    echo "HOLDADDRESS=$C" >> "$LOG_DIR/config.txt"
    echo "更新後的 config.txt 文件內容:"
    cat "$LOG_DIR/config.txt"
}

# 部署智能合約的函數
deploy_smart_contracts() {
    cd $HOME/vana-dlp-chatgpt/
    ./keygen.sh

    # 返回 $HOME 目錄
    cd $HOME

# 確保 public_key_base64.asc 文件存在並且可以讀取
if [ -f "$HOME/vana-dlp-chatgpt/public_key_base64.asc" ]; then
    G=$(cat $HOME/vana-dlp-chatgpt/public_key_base64.asc)
    echo "讀取到的內容: $G"

    # 更新 config.txt 中的 PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64
    if grep -q "^PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=" "$CONFIG_FILE"; then
        # 如果條目已存在，則更新它
        awk -v new_value="$G" '/^PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=/ {$0="PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64="new_value} 1' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        # 如果條目不存在，則添加它
        echo "PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$G" >> "$CONFIG_FILE"
    fi

    echo "更新成功: PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$G"
else
    echo "public_key_base64.asc 文件不存在或無法讀取"
    exit 1
fi

    # 从 config.txt 文件中提取 DEPLOYER_PRIVATE_KEY 和 OWNER_ADDRESS
    A=$(grep 'DEPLOYER_PRIVATE_KEY=' $LOG_DIR/config.txt | cut -d '=' -f2)
    B=$(grep 'COLDADDRESS=' $LOG_DIR/config.txt | cut -d '=' -f2)
    # 克隆 vana-dlp-smart-contracts 仓库
    git clone https://github.com/Josephtran102/vana-dlp-smart-contracts
    # 进入 vana-dlp-smart-contracts 目录
    cd $HOME/vana-dlp-smart-contracts
    npm install -g yarn
    yarn --version
    yarn install
    # 创建 .env 文件并写入内容
    cat <<EOL > .env
# Update with your own private key / address
DEPLOYER_PRIVATE_KEY=$A
OWNER_ADDRESS=$B
SATORI_RPC_URL=http://rpc.satori.vana.org
SATORI_API_URL=https://api.satori.vanascan.io/api
SATORI_BROWSER_URL=https://satori.vanascan.io
MOKSHA_RPC_URL=https://rpc.moksha.vana.org
MOKSHA_API_URL=https://rpc.moksha.vana.org/api
MOKSHA_BROWSER_URL=https://moksha.vanascan.io
# used for creating the contracts
DLP_NAME=TEST
DLP_TOKEN_NAME=TEST
DLP_TOKEN_SYMBOL=TEST
# used for upgrading the DLP contract
DLP_CONTRACT_ADDRESS=0x00etc
EOL
    echo "運行智能合約部署..."
    npx hardhat deploy --network moksha --tags DLPDeploy 2>&1 | tee "$LOG_DIR/contract.log" || { echo "智能合約部署失敗"; exit 1; }
    # 手動輸入合約地址
    read -p "請輸入 DataLiquidityPoolToken 部署地址: " E
    read -p "請輸入 DataLiquidityPool 'TEST' 部署地址: " F
    # 更新 config.txt 文件
    echo "DLP_MOKSHA_CONTRACT=$E" >> "$LOG_DIR/config.txt"
    echo "DLP_TOKEN_MOKSHA_CONTRACT=$F" >> "$LOG_DIR/config.txt"
    # 顯示更新後的 config.txt 文件內容
    echo "更新後的 config.txt 文件內容:"
    cat "$LOG_DIR/config.txt"
    cd $HOME/vana-dlp-chatgpt
    # 创建 .env 文件并写入内容
    cat <<EOL > .env
# The network to use, currently Vana Moksha testnet
OD_CHAIN_NETWORK=moksha
OD_CHAIN_NETWORK_ENDPOINT=https://rpc.moksha.vana.org

# Optional: OpenAI API key for additional data quality check
OPENAI_API_KEY=$(read -p "請輸入 OpenAI API key: " OPENAI_API_KEY && echo $OPENAI_API_KEY)

# Optional: Your own DLP smart contract address once deployed to the network, useful for local testing
DLP_MOKSHA_CONTRACT=$(grep 'DLP_TOKEN_MOKSHA_CONTRACT=' $LOG_DIR/config.txt | cut -d '=' -f2)

# Optional: Your own DLP token contract address once deployed to the network, useful for local testing
DLP_TOKEN_MOKSHA_CONTRACT=$(grep 'DLP_MOKSHA_CONTRACT=' $LOG_DIR/config.txt | cut -d '=' -f2)

# The private key for the DLP, follow "Generate validator encryption keys" section in the README
PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$(grep 'G=' $LOG_DIR/config.txt | cut -d '=' -f2)
EOL
}

# 設置驗證器的函數
setup_validator() {
    echo "設置驗證器..."
    cd ~
    cd vana-dlp-chatgpt
    ./vanacli dlp register_validator --stake_amount 10 || { echo "註冊驗證器失敗"; exit 1; }
    # 從 config.txt 提取驗證器地址
    VALIDATOR_ADDRESS=$(grep 'HOLDADDRESS=' $LOG_DIR/config.txt | cut -d '=' -f2)
    ./vanacli dlp approve_validator --validator_address="$VALIDATOR_ADDRESS" || { echo "批准驗證器失敗"; exit 1; }
    poetry run python -m chatgpt.nodes.validator || { echo "運行驗證器失敗"; exit 1; }
    echo "驗證器設置完成！"
}

# 設置驗證器服務的函數
setup_validator_service() {
    echo "設置驗證器服務..."
sudo tee /etc/systemd/system/vana.service << EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vana-dlp-chatgpt
ExecStart=/bin/bash -c 'source /root/vana-dlp-chatgpt/myenv/bin/activate && /root/.local/bin/poetry run python -m chatgpt.nodes.validator'
Restart=on-failure
RestartSec=10
Environment=PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin:/root/vana-dlp-chatgpt/myenv/bin
Environment=PYTHONPATH=/root/vana-dlp-chatgpt

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable vana.service
    sudo systemctl start vana.service
    sudo systemctl status vana.service
    echo "驗證器服務設置完成！"
}

# 查看驗證器日誌的函數
view_validator_logs() {
    echo "查看驗證器日誌..."
    sudo journalctl -u vana.service -f
}

# 停止VANA及刪除服務的函數
stop_and_remove_service() {
    echo "停止VANA及刪除服務..."
    sudo systemctl stop vana.service
    sudo systemctl disable vana.service
    sudo rm /etc/systemd/system/vana.service
    sudo systemctl daemon-reload
    echo "VANA服務已停止並刪除！"
}

# 刪除所有文件的函數
delete_all_files() {
    echo "刪除所有文件..."
    rm -r ~/.vana
    rm -r ~/vana-dlp-smart-contracts
    rm -r ~/vana-dlp-chatgpt
    echo "所有文件已刪除！"
}

# 主程序
while true; do
    show_menu
    read -p "請選擇一個選項: " choice
    case $choice in
        1)
            install_files
            ;;
        2)
            create_wallet
            ;;
        3)
            export_coldkey
            ;;
        4)
            export_hotkey
            ;;
        5)
            deploy_smart_contracts
            ;;
        6)
            setup_validator
            ;;
        7)
            setup_validator_service
            ;;
        8)
            view_validator_logs
            ;;
        9)
            stop_and_remove_service
            ;;
        10)
            delete_all_files
            ;;
        11)
            echo "退出"
            break
            ;;
        *)
            echo "無效選項，請重試"
            ;;
    esac
done
