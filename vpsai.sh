#!/bin/bash

VERSION="v0.0.1"
AUTHOR="Protomyst"
ROOT_DIR="/root/ai"
DATA_DIR="${ROOT_DIR}/data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入其他脚本
source "${SCRIPT_DIR}/services.sh"
source "${SCRIPT_DIR}/update.sh"
source "${SCRIPT_DIR}/nginx.sh"

# 显示logo
show_logo() {
    echo '       __     ______  ____    _    ___ '
    echo '       \ \   / /  _ \/ ___|  / \  |_ _|'
    echo '        \ \ / /| |_) \___ \ / _ \  | | '
    echo '         \ V / |  __/ ___) / ___ \ | | '
    echo '          \_/  |_|   |____/_/   \_\___|'
    echo
    echo "   Version: ${VERSION}	Author: ${AUTHOR}"
    echo
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误：必须以root用户运行此脚本"
        exit 1
    fi
}

# 检查系统架构
check_arch() {
    arch=$(uname -m)
    is_arm=0
    if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
        is_arm=1
    fi
}

# 检查并安装依赖
install_dependencies() {
    echo "正在检查依赖..."
    
    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update"
        PKG_INSTALL="yum install -y"
    else
        echo "不支持的包管理器"
        exit 1
    fi

    # 更新包列表
    $PKG_UPDATE

    # 安装基础依赖
    for pkg in git docker.io docker-compose nginx; do
        if ! command -v $pkg &> /dev/null; then
            echo "正在安装 $pkg..."
            $PKG_INSTALL $pkg
        fi
    done
}

# 启动必要服务
start_services() {
    systemctl start docker
    systemctl enable docker
    systemctl start nginx
    systemctl enable nginx
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        return 1
    fi
    return 0
}

# 开放防火墙端口
open_firewall_port() {
    local port=$1
    if command -v ufw &> /dev/null; then
        ufw allow $port
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$port/tcp
        firewall-cmd --reload
    fi
}

# 创建数据目录
create_data_dir() {
    local service=$1
    local dir="${DATA_DIR}/${service}"
    mkdir -p "$dir"
    echo "$dir"
}

# 显示帮助信息
show_help() {
    if [ -f "${ROOT_DIR}/help.md" ]; then
        less "${ROOT_DIR}/help.md"
    else
        echo "帮助文件不存在"
    fi
}

# 错误处理
handle_error() {
    local error_msg="$1"
    echo "错误: ${error_msg}" >&2
    logger -t vpsai "错误: ${error_msg}"
}

# 显示进度
show_progress() {
    local current="$1"
    local total="$2"
    local msg="$3"
    printf "\r[%-50s] %d%% %s" \
        "$(printf '#%.0s' $(seq 1 $(($current*50/$total))))" \
        $(($current*100/$total)) \
        "${msg}"
}

# 主菜单
show_menu() {
    clear
    show_logo
    echo "请选择操作："
    echo "1. 安装API服务 (OneAPI / NewAPI / VoAPI)"
    echo "2. 安装Chat服务 (Open-WebUI / NextChat / LibreChat / LobeChat)"
    echo "3. 检查服务状态"
    echo "4. 配置自动更新或手动更新"
    echo "5. 配置自定义域名"
    echo "6. 删除Chat / API服务"
    echo "7. 查看帮助"
    echo "8. 退出脚本"
    echo
    read -p "请输入选项 [1-8]: " choice
    
    case $choice in
        1) install_api_service ;;
        2) install_chat_service ;;
        3) check_service_status ;;
        4) configure_updates ;;
        5) configure_domain ;;
        6) remove_service ;;
        7) show_help ;;
        8) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

# 设置全局变量导出
export VERSION AUTHOR ROOT_DIR DATA_DIR is_arm

# 导出公共函数
export -f check_port
export -f open_firewall_port
export -f create_data_dir
export -f handle_error
export -f show_progress

# 主程序入口
main() {
    trap 'handle_error "脚本执行中断"' INT TERM

    check_root || exit 1
    check_arch
    
    # 创建日志目录
    mkdir -p "${ROOT_DIR}/logs"
    
    # 初始化日志
    exec 1> >(tee -a "${ROOT_DIR}/logs/vpsai.log")
    exec 2> >(tee -a "${ROOT_DIR}/logs/vpsai.error.log")
    
    install_dependencies
    start_services

    chmod +x /root/vpsai/*.sh
    
    while true; do
        show_menu
    done
}

main
