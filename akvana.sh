#!/bin/bash

# 設置絕對路徑
VANA_CLI_PATH="/root/vana-dlp-chatgpt/vanacli"
VANA_DLP_CHATGPT_PATH="/root/vana-dlp-chatgpt"
LOG_DIR="/root/vanalog"

# 創建日誌資料夾
mkdir -p "$LOG_DIR"

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
    echo "9. 退出"
}

# 檢查命令是否存在的函數
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安裝需要文件的函數
install_files() {
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl wget jq make gcc nano git software-properties-common

    # 安装 nvm
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    fi

    # 加载 nvm
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # 安装 Node.js 和 npm
    nvm install 18
    nvm use 18

    node -v
    npm -v

    # 安装 Python
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip

    curl -sSL https://install.python-poetry.org | python3 -
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bashrc
    source $HOME/.bashrc
    python3.11 --version

    # 安装 Yarn
    npm install -g yarn

    # Clone GPT 代码
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    cd $HOME/vana-dlp-chatgpt/

    # 配置环境
    python3.11 -m venv vana_gpt_env
    source vana_gpt_env/bin/activate
    pip install --upgrade pip
    pip install poetry
    pip install python-dotenv
    poetry install
    pip install vana

    echo "部署完成..."
}

# 創建錢包的函數
create_wallet() {
    echo "創建錢包..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet create --wallet.name default --wallet.hotkey default 2>&1 | tee "$LOG_DIR/wallet.log" || { echo "創建錢包失敗"; exit 1; }
    echo "錢包創建完成，詳情請查看 $LOG_DIR/wallet.log"
}

# 導出冷錢包私鑰的函數，並將輸出重定向到coldkey.log
export_coldkey() {
    echo "導出冷錢包私鑰..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet export_private_key 2>&1 | tee "$LOG_DIR/coldkey.log" || { echo "導出冷錢包私鑰失敗"; exit 1; }
    echo "冷錢包私鑰已導出到 $LOG_DIR/coldkey.log"
}

# 導出熱錢包私鑰的函數，並將輸出重定向到hotkey.log
export_hotkey() {
    echo "導出熱錢包私鑰..."
    cd $HOME/vana-dlp-chatgpt/
    vanacli wallet export_private_key 2>&1 | tee "$LOG_DIR/hotkey.log" || { echo "導出熱錢包私鑰失敗"; exit 1; }
    echo "熱錢包私鑰已導出到 $LOG_DIR/hotkey.log"
}

# 設置智能合約環境的函數
setup_smart_contracts() {
    echo "設置智能合約環境..."
    cd $HOME/vana-dlp-chatgpt/
    ./keygen.sh 2>&1 | tee "$LOG_DIR/keygen.log" || { echo "設置智能合約環境失敗"; exit 1; }
    cd $HOME
    rm -rf vana-dlp-smart-contracts
    git clone https://github.com/Josephtran102/vana-dlp-smart-contracts 2>&1 | tee "$LOG_DIR/git_clone.log" || { echo "克隆智能合約儲存庫失敗"; exit 1; }
    cd vana-dlp-smart-contracts
    yarn install 2>&1 | tee "$LOG_DIR/yarn_install.log" || { echo "安裝智能合約依賴失敗"; exit 1; }
    cp .env.example .env

    # 要求用戶輸入並寫入 .env 文件
    read -p "請輸入 DEPLOYER_PRIVATE_KEY(在coldkey.log): " DEPLOYER_PRIVATE_KEY
    read -p "請輸入 OWNER_ADDRESS(導入小狐狸coldkey的地址): " OWNER_ADDRESS
    read -p "請輸入 DLP_NAME自定義: " DLP_NAME
    read -p "請輸入 DLP_TOKEN_NAME自定義: " DLP_TOKEN_NAME
    read -p "請輸入 DLP_TOKEN_SYMBOL自定義: " DLP_TOKEN_SYMBOL

    sed -i "s/^DEPLOYER_PRIVATE_KEY=.*/DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY/" .env
    sed -i "s/^OWNER_ADDRESS=.*/OWNER_ADDRESS=$OWNER_ADDRESS/" .env
    sed -i "s/^DLP_NAME=.*/DLP_NAME=$DLP_NAME/" .env
    sed -i "s/^DLP_TOKEN_NAME=.*/DLP_TOKEN_NAME=$DLP_TOKEN_NAME/" .env
    sed -i "s/^DLP_TOKEN_SYMBOL=.*/DLP_TOKEN_SYMBOL=$DLP_TOKEN_SYMBOL/" .env

    echo "運行智能合約部署..."
    npx hardhat deploy --network moksha --tags DLPDeploy 2>&1 | tee "$LOG_DIR/contract.log" || { echo "智能合約部署失敗"; exit 1; }

    # 自建 .env 文件
    cat <<EOL > "$VANA_DLP_CHATGPT_PATH/.env"
# The network to use, currently Vana Moksha testnet
OD_CHAIN_NETWORK=moksha
OD_CHAIN_NETWORK_ENDPOINT=https://rpc.moksha.vana.org

# Optional: OpenAI API key for additional data quality check
OPENAI_API_KEY="要求輸入"

# Optional: Your own DLP smart contract address once deployed to the network, useful for local testing
DLP_MOKSHA_CONTRACT=要求輸入

# Optional: Your own DLP token contract address once deployed to the network, useful for local testing
DLP_TOKEN_MOKSHA_CONTRACT=要求輸入

# The private key for the DLP, follow "Generate validator encryption keys" section in the README
PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64="要求輸入"
EOL

    # 要求用戶輸入並更新 .env 文件
    read -p "請輸入 OPENAI_API_KEY: " OPENAI_API_KEY
    read -p "請輸入 DLP_MOKSHA_CONTRACT: " DLP_MOKSHA_CONTRACT
    read -p "請輸入 DLP_TOKEN_MOKSHA_CONTRACT: " DLP_TOKEN_MOKSHA_CONTRACT
    read -p "請輸入 PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64: " PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64

    sed -i "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=\"$OPENAI_API_KEY\"/" "$VANA_DLP_CHATGPT_PATH/.env"
    sed -i "s/^DLP_MOKSHA_CONTRACT=.*/DLP_MOKSHA_CONTRACT=$DLP_MOKSHA_CONTRACT/" "$VANA_DLP_CHATGPT_PATH/.env"
    sed -i "s/^DLP_TOKEN_MOKSHA_CONTRACT=.*/DLP_TOKEN_MOKSHA_CONTRACT=$DLP_TOKEN_MOKSHA_CONTRACT/" "$VANA_DLP_CHATGPT_PATH/.env"
    sed -i "s/^PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=.*/PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=\"$PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64\"/" "$VANA_DLP_CHATGPT_PATH/.env"

    echo ".env 文件已更新！"
}

# 設置驗證器的函數
setup_validator() {
    echo "設置驗證器..."
    cd ~
    cd vana-dlp-chatgpt
    ./vanacli dlp register_validator --stake_amount 10 || { echo "註冊驗證器失敗"; exit 1; }
    read -p "請輸入驗證器地址: " VALIDATOR_ADDRESS
    ./vanacli dlp approve_validator --validator_address="$VALIDATOR_ADDRESS" || { echo "批准驗證器失敗"; exit 1; }
    poetry run python -m chatgpt.nodes.validator || { echo "運行驗證器失敗"; exit 1; }
    echo "驗證器設置完成！"
}

# 設置驗證器服務的函數
setup_validator_service() {
    echo "設置驗證器服務..."
    sudo tee /etc/systemd/system/vana.service <<EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/vana-dlp-chatgpt
ExecStart=/root/.local/bin/poetry run python -m chatgpt.nodes.validator
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
            setup_smart_contracts
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
            echo "退出"
            break
            ;;
        *)
            echo "無效選項，請重試"
            ;;
    esac
done