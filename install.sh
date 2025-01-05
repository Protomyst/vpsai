#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 必须使用root权限运行此脚本${NC}"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    echo -e "${YELLOW}正在检查系统环境...${NC}"
    
    # 检查Linux发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            debian|ubuntu|centos|rocky|rhel)
                echo -e "${GREEN}系统检查通过: $PRETTY_NAME${NC}"
                ;;
            *)
                echo -e "${RED}不支持的系统: $PRETTY_NAME${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}无法确定系统类型${NC}"
        exit 1
    fi
    
    # 检查内存
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ $total_mem -lt 2048 ]; then
        echo -e "${YELLOW}警告: 内存小于2GB,部分服务可能无法正常运行${NC}"
    fi
}

# 安装基础依赖
install_base() {
    echo -e "${YELLOW}安装基础依赖...${NC}"
    
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
        echo -e "${RED}不支持的包管理器${NC}"
        exit 1
    fi

    # 更新包列表
    $PKG_UPDATE

    # 安装必要工具
    for pkg in curl wget git sudo; do
        if ! command -v $pkg &> /dev/null; then
            echo "安装 $pkg..."
            $PKG_INSTALL $pkg
        fi
    done
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}安装Docker环境...${NC}"
    
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        $PKG_INSTALL docker-compose
    fi
}

# 下载VPSAI
install_vpsai() {
    echo -e "${YELLOW}安装VPSAI...${NC}"
    
    # 创建安装目录
    install_dir="/root/vpsai"
    mkdir -p "$install_dir"
    
    # 下载代码
    git clone https://github.com/Protomyst/vpsai.git "$install_dir"
    
    # 设置权限
    chmod +x "$install_dir/vpsai.sh"
    
    # 创建快捷方式
    ln -sf "$install_dir/vpsai.sh" /usr/local/bin/vpsai
    
    echo -e "${GREEN}VPSAI安装完成!${NC}"
    echo -e "使用方法:"
    echo -e "  1. 输入 ${YELLOW}vpsai${NC} 启动管理面板"
    echo -e "  2. 或进入 ${YELLOW}$install_dir${NC} 目录"
    echo -e "     执行 ${YELLOW}./vpsai.sh${NC}"
}

# 主函数
main() {
    clear
    echo "================================================"
    echo "              VPSAI 一键安装脚本                 "
    echo "================================================"
    echo
    
    check_root
    check_system
    install_base
    install_docker
    install_vpsai
    
    echo
    echo "================================================"
    echo -e "${GREEN}安装已完成!${NC}"
    echo "现在可以使用 'vpsai' 命令启动管理面板"
    echo "================================================"
}

main
