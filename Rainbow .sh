#!/bin/bash

# -----------------------------
# 自定义样式变量
# -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # 无颜色

INFO_ICON="ℹ️"
SUCCESS_ICON="✅"
WARNING_ICON="⚠️"
ERROR_ICON="❌"

LOG_FILE="/var/log/rainbow_script.log"
KEY_FILE="/root/bitcoin_wallet_keys.txt"

# -----------------------------
# 信息显示函数
# -----------------------------
log_info() {
    echo -e "${BLUE}${INFO_ICON} [INFO] $1${NC}"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}${SUCCESS_ICON} [SUCCESS] $1${NC}"
    echo "[SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}${WARNING_ICON} [WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}${ERROR_ICON} [ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

# -----------------------------
# 自定义变量
# -----------------------------
RPC_USER="demo"
RPC_PASSWORD="demo"
RPC_PORT=5000
START_HEIGHT=42000
DOCKER_IMAGE="mocacinno/btc_testnet4:bci_node"
BTC_PROJECT_PATH="/root/project/run_btc_testnet4"
RBO_PROJECT_PATH="/root/rbo_indexer_testnet"

# -----------------------------
# 安装并启动节点
# -----------------------------
install_and_start_node() {
    log_info "创建 Bitcoin Testnet 项目目录..."
    mkdir -p "$BTC_PROJECT_PATH/data" || { log_error "目录创建失败！"; exit 1; }

    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        log_info "Docker 未安装，正在安装 Docker..."
        apt-get update -y
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
        systemctl enable docker
    fi

    # 安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "正在安装 Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

    # 克隆仓库并启动容器
    log_info "克隆 GitHub 仓库..."
    git clone https://github.com/rainbowprotocol-xyz/btc_testnet4 "$BTC_PROJECT_PATH"
    cd "$BTC_PROJECT_PATH"
    docker-compose up -d || { log_error "启动 Docker 容器失败！"; exit 1; }

    # 创建钱包并获取新地址和私钥
    log_info "创建钱包并获取地址和私钥..."
    WALLET_ADDRESS=$(docker exec -it $(docker ps -q -f "name=bitcoind") bitcoin-cli -testnet4 -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD -rpcport=$RPC_PORT getnewaddress)
    WALLET_PRIVATE_KEY=$(docker exec -it $(docker ps -q -f "name=bitcoind") bitcoin-cli -testnet4 -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD -rpcport=$RPC_PORT dumpprivkey "$WALLET_ADDRESS")

    echo "地址: $WALLET_ADDRESS" > "$KEY_FILE"
    echo "私钥: $WALLET_PRIVATE_KEY" >> "$KEY_FILE"
    log_success "地址和私钥已保存到 $KEY_FILE"
}

# -----------------------------
# 更新 rbo_worker
# -----------------------------
update_script() {
    log_info "更新 rbo_worker..."
    rm -rf "$RBO_PROJECT_PATH"
    git clone https://github.com/rainbowprotocol-xyz/rbo_indexer_testnet "$RBO_PROJECT_PATH"
    cd "$RBO_PROJECT_PATH"
    wget https://github.com/rainbowprotocol-xyz/rbo_indexer_testnet/releases/download/v0.0.1-alpha/rbo_worker
    chmod +x rbo_worker
    screen -S Rainbow -dm ./rbo_worker worker --rpc http://127.0.0.1:$RPC_PORT --password $RPC_PASSWORD --username $RPC_USER --start_height $START_HEIGHT
    log_success "rbo_worker 已更新并启动。"
}

# -----------------------------
# 查看日志
# -----------------------------
view_logs() {
    log_info "查看 rbo_worker 日志..."
    tail -f "$RBO_PROJECT_PATH/worker.log"
}

# -----------------------------
# 清理脚本
# -----------------------------
cleanup_and_remove_script() {
    log_warning "停止并删除 Docker 容器和文件..."
    cd "$BTC_PROJECT_PATH" && docker-compose down
    pkill -f rbo_worker
    rm -rf "$BTC_PROJECT_PATH" "$RBO_PROJECT_PATH"
    log_success "清理完成。"
}

# -----------------------------
# 编辑 Principal ID
# -----------------------------
edit_principal() {
    PRINCIPAL_FILE="$RBO_PROJECT_PATH/identity/identity.json"
    if [ ! -f "$PRINCIPAL_FILE" ]; then
        log_error "未找到 Principal 文件。"
        return
    fi
    principal=$(grep '"principal"' "$PRINCIPAL_FILE" | awk -F: '{gsub(/"|,/, "", $2); print $2}')
    echo "$principal"
}

# -----------------------------
# 主菜单
# -----------------------------
main_menu() {
    while true; do
        clear
        echo "======================== Rainbow 管理脚本 ========================"
        echo "1. 安装并启动节点"
        echo "2. 更新 rbo_worker"
        echo "3. 查看 Principal ID"
        echo "4. 停止并删除节点"
        echo "5. 查看 rbo_worker 日志"
        echo "=================================================================="
        read -p "请选择操作 [1-5]: " option
        case $option in
            1) install_and_start_node ;;
            2) update_script ;;
            3) edit_principal ;;
            4) cleanup_and_remove_script ;;
            5) view_logs ;;
            *) echo "无效选项，请重试。" ;;
        esac
    done
}

# -----------------------------
# 运行主菜单
# -----------------------------
main_menu

