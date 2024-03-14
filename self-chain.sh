#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/self-chain.sh"

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="sel"
    local shell_rc="$HOME/.bashrc"

    # 对于Zsh用户，使用.zshrc
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "设置快捷键 '$alias_name' 到 $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        # 添加提醒用户激活快捷键的信息
        echo "快捷键 '$alias_name' 已设置。请运行 'source $shell_rc' 来激活快捷键，或重新打开终端。"
    else
        # 如果快捷键已经设置，提供一个提示信息
        echo "快捷键 '$alias_name' 已经设置在 $shell_rc。"
        echo "如果快捷键不起作用，请尝试运行 'source $shell_rc' 或重新打开终端。"
    fi
}

# 节点安装功能
function install_node() {

# 检查命令是否存在
exists() {
  command -v "$1" >/dev/null 2>&1
}


# 设置变量
read -r -p "请输入节点名称: " NODE_MONIKER
export NODE_MONIKER=$NODE_MONIKER

# 更新和安装必要的软件
sudo apt update -y
sudo apt install git curl build-essential make jq gcc snapd chrony lz4 tmux unzip bc bison binutils bsdmainutils -y



# 检查是否已安装gvm
if [ -s "/root/.gvm/scripts/gvm" ]; then
    echo "GVM已安装. 设置GO 1.20.5..."
    # 如果已经安装了gvm，执行以下命令
    source /root/.gvm/scripts/gvm
    gvm install go1.20.5
    gvm use go1.20.5
else
    echo "GVM未安装，安装GVM并设置GO 1.20.5..."
    # 如果未安装gvm，执行安装步骤
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source /root/.gvm/scripts/gvm

    # 安装go1.4作为构建其他Go版本的基础
    gvm install go1.4 -B
    gvm use go1.4
    export GOROOT_BOOTSTRAP=$GOROOT

    # 安装go1.17.13作为过渡版本
    gvm install go1.17.13
    gvm use go1.17.13
    export GOROOT_BOOTSTRAP=$GOROOT

    # 安装并使用go1.20.5
    gvm install go1.20.5
    gvm use go1.20.5
fi

# 安装所有二进制文件
cd $HOME
wget https://ss-t.selfchain.nodestake.org/selfchaind
chmod +x selfchaind
mv selfchaind /usr/local/bin
selfchaind version

# 配置selfchaind
selfchaind config chain-id self-dev-1
selfchaind init "$NODE_MONIKER" --chain-id=self-dev-1

# 获取初始文件和地址簿
curl -Ls https://ss-t.selfchain.nodestake.org/genesis.json > $HOME/.selfchain/config/genesis.json
curl -Ls https://ss-t.selfchain.nodestake.org/addrbook.json > $HOME/.selfchain/config/addrbook.json


# 配置节点
SEEDS="94a7baabb2bcc00c7b47cbaa58adf4f433df9599@157.230.119.165:26656,d3b5b6ca39c8c62152abbeac4669816166d96831@165.22.24.236:26656,35f478c534e2d58dc2c4acdf3eb22eeb6f23357f@165.232.125.66:26656"
PEERS="94a7baabb2bcc00c7b47cbaa58adf4f433df9599@157.230.119.165:26656,d3b5b6ca39c8c62152abbeac4669816166d96831@165.22.24.236:26656,35f478c534e2d58dc2c4acdf3eb22eeb6f23357f@165.232.125.66:26656"
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.selfchain/config/genesis.json

# 配置和快照
SNAP_NAME=$(curl -s https://ss-t.selfchain.nodestake.org/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://ss-t.selfchain.nodestake.org/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.selfchain


# 创建服务文件
sudo tee /etc/systemd/system/selfchaind.service > /dev/null <<EOF
[Unit]
Description=selfchaind Daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which selfchaind) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable selfchaind


# 重新加载和启动服务
sudo systemctl restart selfchaind


# 完成设置

echo '====================== 安装完成 ==========================='

}

# 创建钱包
function add_wallet() {
    read -p "请输入钱包名称: " wallet_name
    selfchaind keys add "$wallet_name"
}

# 导入钱包
function import_wallet() {
    read -p "请输入钱包名称: " wallet_name
    selfchaind keys add "$wallet_name" --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    selfchaind query bank balances "$wallet_address" 
}

# 查看节点同步状态
function check_sync_status() {
    selfchaind status 2>&1 | jq .SyncInfo
}

# 查看selfchain服务状态
function check_service_status() {
    systemctl status selfchaind
}

# 节点日志查询
function view_logs() {
    sudo journalctl -f -u selfchaind.service 
}

# 卸载节点功能
function uninstall_node() {
    sudo systemctl stop selfchaind && sudo systemctl disable selfchaind && sudo rm /etc/systemd/system/selfchaind.service && sudo systemctl daemon-reload && rm -rf $HOME/.selfchain && rm -rf selfchain && sudo rm -rf $(which selfchaind)



# 主菜单
function main_menu() {
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 创建钱包"
    echo "3. 导入钱包"
    echo "4. 查看钱包地址余额"
    echo "5. 查看节点同步状态"
    echo "6. 查看当前服务状态"
    echo "7. 运行日志查询"
    echo "8. 卸载节点"
    echo "9. 设置快捷键"  
    read -p "请输入选项（1-9）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) add_wallet ;;
    3) import_wallet ;;
    4) check_balances ;;
    5) check_sync_status ;;
    6) check_service_status ;;
    7) view_logs ;;
    8) uninstall_node ;;
    9) check_and_set_alias ;;  
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
