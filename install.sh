
#!/bin/bash

# 版本信息
VERSION="v0.0.1"
AUTHOR="Protomyst"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 显示Logo
show_logo() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    __     ______  ____    _    ___ 
    \ \   / /  _ \/ ___|  / \  |_ _|
     \ \ / /| |_) \___ \ / _ \  | | 
      \ V / |  __/ ___) / ___ \ | | 
       \_/  |_|   |____/_/   \_\___|
EOF
    echo -e "${NC}"
    echo "Version: $VERSION"
    echo "Author: $AUTHOR"
    echo "----------------------------------------"
}

# 检查系统要求
check_requirements() {
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}请使用root用户运行此脚本${NC}"
        exit 1
    }

    # 检查系统架构
    ARCH=$(uname -m)
    IS_ARM=false
    if [[ $ARCH == *"arm"* || $ARCH == *"aarch"* ]]; then
        IS_ARM=true
    fi
}

# 安装基础软件包
install_base_packages() {
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y curl wget git docker.io docker-compose nginx
    elif command -v yum &>/dev/null; then
        yum install -y curl wget git docker docker-compose nginx
    fi
    
    systemctl start docker
    systemctl enable docker
}

# 主菜单
show_menu() {
    echo -e "\n请选择操作："
    echo "1. 安装 OneAPI / NewAPI / VoAPI"
    echo "2. 安装 Open-WebUI / NextChat / LibreChat / LobeChat"
    echo "3. 检查 API & Chat 服务启动状态"
    echo "4. 配置自动更新 / 手动更新服务"
    echo "5. 修改 Docker 配置"
    echo "6. 修改 Nginx 配置"
    echo "7. 删除服务"
    echo "8. 帮助"
    echo "9. 退出脚本"
    
    read -p "请输入选项 [1-9]: " choice
    case $choice in
        1) install_api_services ;;
        2) install_chat_services ;;
        3) check_services_status ;;
        4) configure_updates ;;
        5) modify_docker_config ;;
        6) modify_nginx_config ;;
        7) remove_services ;;
        8) show_help ;;
        9) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
}

# 安装API服务
install_api_services() {
    echo "1. OneAPI"
    echo "2. NewAPI"
    echo "3. VoAPI"
    read -p "请选择要安装的服务 [1-3]: " api_choice
    
    # VoAPI在ARM架构上的处理
    if [ "$api_choice" = "3" ] && [ "$IS_ARM" = true ]; then
        echo -e "${RED}VoAPI不支持ARM架构${NC}"
        return
    fi

    # 创建数据目录
    local service_name=""
    case $api_choice in
        1) service_name="oneapi" ;;
        2) service_name="newapi" ;;
        3) service_name="voapi" ;;
    esac
    
    mkdir -p ~/ai/data/$service_name
}

# 创建系统级命令
install_command() {
    cp vpsai.sh /usr/local/bin/vpsai
    chmod +x /usr/local/bin/vpsai
    
    mkdir -p /etc/vpsai
    cp -r docker-compose /etc/vpsai/
    cp -r nginx /etc/vpsai/
    
    echo "VPSAI 安装完成！使用 'vpsai' 命令启动程序。"
}

# 主程序入口
main() {
    show_logo
    check_requirements
    install_base_packages
    while true; do
        show_menu
    done
}

# 运行安装
install_command

# 运行主程序
main