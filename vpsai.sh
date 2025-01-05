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
    fi  # end root check

    # 检查系统架构
    ARCH=$(uname -m)
    IS_ARM=false
    if [[ $ARCH == *"arm"* || $ARCH == *"aarch"* ]]; then
        IS_ARM=true
    fi  # end arch check
}  # end check_requirements

# 检查软件包是否已安装
check_package() {
    if command -v apt-get &>/dev/null; then
        dpkg -l "$1" &>/dev/null
    elif command -v yum &>/dev/null; then
        rpm -q "$1" &>/dev/null
    fi
}

# 安装基础软件包
install_base_packages() {
    # 需要安装的包列表
    local packages=(curl wget git docker.io docker-compose nginx)  # 移除 mysql-server
    local need_install=false
    
    echo "检查依赖..."
    for pkg in "${packages[@]}"; do
        if ! check_package "$pkg"; then
            echo "  - $pkg 未安装"
            need_install=true
        else
            echo "  - $pkg 已安装"
        fi
    done
    
    if [ "$need_install" = true ]; then
        echo "开始安装缺失的依赖..."
        if command -v apt-get &>/dev/null; then
            apt-get update
            apt-get install -y "${packages[@]}"
        elif command -v yum &>/dev/null; then
            yum install -y "${packages[@]}"
        fi
    fi
    
    # 检查服务状态
    for service in docker nginx; do  # 移除 mysql
        if ! systemctl is-active --quiet $service; then
            echo "启动 $service 服务..."
            systemctl start $service
            systemctl enable $service
        fi
    done
}

# 检查并配置端口
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${RED}端口 $port 已被占用${NC}"
        read -p "请输入新的端口号: " new_port
        echo $new_port
    else
        echo $port
    fi
}

# 配置域名和SSL
configure_domain() {
    local service=$1
    local port=$2
    local domain_configured=false
    local configured_domain=""
    
    read -p "是否需要配置域名？(y/n): " need_domain
    if [ "$need_domain" = "y" ]; then
        read -p "请输入域名: " domain
        configured_domain=$domain
        domain_configured=true
        
        # 先配置HTTP
        echo "配置HTTP域名..."
        sed "s/\${DOMAIN}/$domain/g; s/\${PORT}/$port/g" \
            /etc/vpsai/nginx/template.conf > /etc/nginx/conf.d/$domain.conf
        
        # 重载Nginx
        if ! systemctl reload nginx; then
            systemctl restart nginx
        fi
        
        read -p "使用哪种证书？(1: Let's Encrypt 2: Cloudflare): " cert_type
        if [ "$cert_type" = "1" ]; then
            echo "申请Let's Encrypt证书..."
            apt-get install -y certbot python3-certbot-nginx
            
            # 使用certbot配置HTTPS
            if certbot --nginx -d $domain; then
                echo "SSL证书配置成功！"
            else
                echo -e "${RED}SSL证书配置失败，保持HTTP配置${NC}"
            fi
        else
            # 创建SSL证书目录
            mkdir -p /etc/nginx/ssl/$domain
            echo "请将Cloudflare证书放置在 /etc/nginx/ssl/$domain/ 目录下"
            echo "fullchain.pem - 证书文件"
            echo "privkey.pem   - 私钥文件"
            read -p "确认完成后按回车继续"
            
            # 添加HTTPS配置
            cat >> /etc/nginx/conf.d/$domain.conf << EOF

server {
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate /etc/nginx/ssl/${domain}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/${domain}/privkey.pem;
    
    location / {
        proxy_pass http://localhost:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        fi
        
        # 重载配置
        systemctl reload nginx
    fi
    
    # 返回域名配置信息
    echo "$domain_configured:$configured_domain"
}

# 配置自动更新
configure_updates() {
    echo "1. 配置自动更新"
    echo "2. 手动更新"
    read -p "请选择 [1-2]: " update_choice
    
    case $update_choice in
        1)
            # 创建定时任务
            echo "0 4 * * * /etc/vpsai/cron/update.sh" > /tmp/vpsai_cron
            crontab /tmp/vpsai_cron
            rm /tmp/vpsai_cron
            echo -e "${GREEN}已配置每天凌晨4点自动更新${NC}"
            ;;
        2)
            /etc/vpsai/cron/update.sh
            ;;
    esac
}

# 修改Docker配置
modify_docker_config() {
    echo "1. 修改存储目录"
    echo "2. 修改网络设置"
    echo "3. 修改资源限制"
    read -p "请选择 [1-3]: " docker_choice
    
    case $docker_choice in
        1)
            read -p "输入新的存储目录路径: " new_path
            sed -i "s|~/ai/data|$new_path|g" /etc/vpsai/docker-compose/*.yml
            ;;
        2)
            read -p "输入新的网络模式 (bridge/host): " network_mode
            for file in /etc/vpsai/docker-compose/*.yml; do
                sed -i "/services:/a\    network_mode: $network_mode" "$file"
            done
            ;;
        3)
            read -p "输入CPU限制 (例如:1.0): " cpu_limit
            read -p "输入内存限制 (例如:1g): " mem_limit
            for file in /etc/vpsai/docker-compose/*.yml; do
                sed -i "/services:/a\    deploy:\n      resources:\n        limits:\n          cpus: '$cpu_limit'\n          memory: $mem_limit" "$file"
            done
            ;;
    esac
    echo -e "${GREEN}Docker配置已修改${NC}"
}

# 修改Nginx配置
modify_nginx_config() {
    echo "1. 修改SSL证书"
    echo "2. 修改反向代理设置"
    echo "3. 添加新域名"
    read -p "请选择 [1-3]: " nginx_choice
    
    case $nginx_choice in
        1)
            read -p "输入域名: " domain
            read -p "输入证书路径: " cert_path
            sed -i "s|ssl_certificate .*|ssl_certificate $cert_path/fullchain.pem;|" /etc/nginx/conf.d/$domain.conf
            sed -i "s|ssl_certificate_key .*|ssl_certificate_key $cert_path/privkey.pem;|" /etc/nginx/conf.d/$domain.conf
            ;;
        2)
            read -p "输入域名: " domain
            read -p "输入新的代理地址: " proxy_pass
            sed -i "s|proxy_pass .*|proxy_pass $proxy_pass;|" /etc/nginx/conf.d/$domain.conf
            ;;
        3)
            read -p "输入新域名: " domain
            read -p "输入代理端口: " port
            configure_domain "custom" $port
            ;;
    esac
    
    systemctl reload nginx
    echo -e "${GREEN}Nginx配置已修改${NC}"
}

# 删除服务
remove_services() {
    echo "1. 删除API服务"
    echo "2. 删除Chat服务"
    echo "3. 删除所有服务"
    read -p "请选择 [1-3]: " remove_choice
    
    case $remove_choice in
        1)
            echo "1. OneAPI"
            echo "2. NewAPI"
            echo "3. VoAPI"
            read -p "选择要删除的API服务 [1-3]: " api_choice
            case $api_choice in
                1) service="oneapi" ;;
                2) service="newapi" ;;
                3) service="voapi" ;;
            esac
            ;;
        2)
            echo "1. Open-WebUI"
            echo "2. NextChat"
            echo "3. LibreChat"
            echo "4. LobeChat"
            read -p "选择要删除的Chat服务 [1-4]: " chat_choice
            case $chat_choice in
                1) service="open-webui" ;;
                2) service="nextchat" ;;
                3) service="librechat" ;;
                4) service="lobechat" ;;
            esac
            ;;
        3)
            read -p "确定要删除所有服务吗？(y/n): " confirm
            if [ "$confirm" = "y" ]; then
                cd ~/ai/data
                for dir in */; do
                    if [ -f "$dir"/*.yml ]; then
                        cd "$dir" && docker-compose -f *.yml down -v
                        cd ..
                        rm -rf "$dir"
                    fi
                done
                echo -e "${GREEN}所有服务已删除${NC}"
                return
            fi
            ;;
    esac
    
    if [ -n "$service" ]; then
        cd ~/ai/data/$service
        docker-compose -f *.yml down -v
        cd ..
        rm -rf $service
        echo -e "${GREEN}服务 $service 已删除${NC}"
    fi
}

# 彻底还原系统
restore_system() {
    echo -e "${RED}警告：此操作将删除所有服务和配置！${NC}"
    echo "此操作将："
    echo "1. 停止并删除所有Docker容器和网络"
    echo "2. 删除所有服务数据"
    echo "3. 删除所有配置文件"
    echo "4. 删除vpsai命令"
    echo "5. 移除自动更新任务"
    
    read -p "输入 'RESTORE' 确认操作: " confirm
    if [ "$confirm" != "RESTORE" ]; then
        echo "操作已取消"
        return
    fi
    
    echo "开始还原系统..."
    
    # 1. 停止所有服务
    echo "停止所有服务..."
    cd ~/ai/data
    for dir in */; do
        if [ -f "$dir/docker-compose.yml" ]; then
            (cd "$dir" && docker-compose down -v)
        fi
    done
    
    # 2. 删除Docker网络
    echo "删除Docker网络..."
    docker network rm vpsai-net 2>/dev/null
    
    # 3. 删除数据目录
    echo "删除数据目录..."
    rm -rf ~/ai
    
    # 4. 删除配置文件
    echo "删除配置文件..."
    rm -rf /etc/vpsai
    rm -f /etc/nginx/conf.d/vpsai_*.conf
    
    # 5. 删除vpsai命令
    echo "删除vpsai命令..."
    rm -f /usr/local/bin/vpsai
    
    # 6. 移除自动更新
    echo "移除自动更新任务..."
    crontab -l | grep -v "/etc/vpsai/cron/update.sh" | crontab -
    
    echo -e "${GREEN}系统已还原！${NC}"
    echo "如果您想完全移除Docker和Nginx，请手动执行："
    echo "apt-get remove docker.io docker-compose nginx"
    
    exit 0
}

# 显示帮助信息
show_help() {
    cat << EOF
VPSAI 使用帮助：

1. API服务安装：
   - OneAPI：默认端口3000
   - NewAPI：默认端口4000
   - VoAPI：默认端口5000（不支持ARM架构）

2. Chat服务安装：
   - Open-WebUI：默认端口6000（建议配置≥1C1G）
   - NextChat：默认端口7000
   - LibreChat：默认端口8000
   - LobeChat：默认端口9000

3. 域名配置支持：
   - Let's Encrypt 证书自动申请
   - Cloudflare 证书手动配置

4. 数据存储：
   所有服务数据默认存储在 ~/ai/data 目录

5. 更新维护：
   - 支持自动更新（每天凌晨4点）
   - 支持手动更新检查

6. 常用命令：
   vpsai                  启动主面板
   docker ps             查看运行状态
   docker-compose logs    查看服务日志

详细文档请访问：https://github.com/Protomyst/vpsai
EOF
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
    echo "9. 还原系统"
    echo "0. 退出脚本"
    
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        1) install_api_services ;;
        2) install_chat_services ;;
        3) check_services_status ;;
        4) configure_updates ;;
        5) modify_docker_config ;;
        6) modify_nginx_config ;;
        7) remove_services ;;
        8) show_help ;;
        9) restore_system ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
}

# 获取服务器IP地址
get_server_ip() {
    # 尝试获取IPv4地址
    IPV4=$(curl -s4 ifconfig.me 2>/dev/null || wget -qO- ipv4.icanhazip.com 2>/dev/null || dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
    
    # 尝试获取IPv6地址
    IPV6=$(curl -s6 ifconfig.me 2>/dev/null || wget -qO- ipv6.icanhazipip.com 2>/dev/null)
    
    # 构建访问地址
    if [ -n "$IPV4" ]; then
        echo "http://$IPV4:$1"
    fi
    if [ -n "$IPV6" ]; then
        echo "http://[$IPV6]:$1"
    fi
}

# 添加创建 Docker 网络的函数
create_docker_network() {
    if ! docker network ls | grep -q vpsai-net; then
        echo "创建 Docker 网络..."
        docker network create vpsai-net
    fi
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
    local default_port=""
    
    case $api_choice in
        1) 
            service_name="oneapi"
            default_port=3000
            ;;
        2) 
            service_name="newapi"
            default_port=4000
            ;;
        3) 
            service_name="voapi"
            default_port=5000
            ;;
    esac
    
    # 确保网络存在
    create_docker_network
    
    mkdir -p ~/ai/data/$service_name
    cd ~/ai/data/$service_name
    cp /etc/vpsai/docker-compose/${service_name}.yml docker-compose.yml
    
    # 检查文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}错误：配置文件复制失败${NC}"
        return 1
    fi
    
    port=$(check_port $default_port)
    sed -i "s/$default_port:/$port:/" docker-compose.yml
    
    # 启动服务
    docker-compose up -d
    
    # 配置域名并获取返回值
    domain_info=$(configure_domain $service_name $port)
    domain_configured=$(echo $domain_info | cut -d':' -f1)
    configured_domain=$(echo $domain_info | cut -d':' -f2)
    
    echo -e "${GREEN}服务安装完成！${NC}"
    echo -e "访问地址:"
    get_server_ip $port | while read url; do
        echo $url
    done
    
    if [ "$domain_configured" = "true" ] && [ -n "$configured_domain" ]; then
        echo "域名访问: https://$configured_domain"
    fi
}

# 安装Chat服务
install_chat_services() {
    echo "1. Open-WebUI"
    echo "2. NextChat"
    echo "3. LibreChat"
    echo "4. LobeChat"
    read -p "请选择要安装的服务 [1-4]: " chat_choice
    
    # 创建数据目录
    local service_name=""
    local default_port=""
    
    case $chat_choice in
        1) 
            # 检查系统配置
            mem=$(free -m | awk '/Mem:/ {print $2}')
            cpu=$(nproc)
            if [ $mem -lt 1024 ] || [ $cpu -lt 1 ]; then
                echo -e "${RED}警告: 系统配置过低，不建议安装 Open-WebUI${NC}"
                read -p "是否继续？(y/n): " continue_install
                [ "$continue_install" != "y" ] && return
            fi
            service_name="open-webui"
            default_port=6000
            ;;
        2) 
            service_name="nextchat"
            default_port=7000
            ;;
        3) 
            service_name="librechat"
            default_port=8000
            ;;
        4) 
            service_name="lobechat"
            default_port=9000
            ;;
    esac
    
    # 确保网络存在
    create_docker_network
    
    mkdir -p ~/ai/data/$service_name
    cd ~/ai/data/$service_name
    cp /etc/vpsai/docker-compose/${service_name}.yml docker-compose.yml
    
    # 检查文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}错误：配置文件复制失败${NC}"
        return 1
    fi
    
    port=$(check_port $default_port)
    sed -i "s/$default_port:/$port:/" docker-compose.yml
    
    # 启动服务
    docker-compose up -d
    
    # 配置域名并获取返回值
    domain_info=$(configure_domain $service_name $port)
    domain_configured=$(echo $domain_info | cut -d':' -f1)
    configured_domain=$(echo $domain_info | cut -d':' -f2)
    
    echo -e "${GREEN}服务安装完成！${NC}"
    echo -e "访问地址:"
    get_server_ip $port | while read url; do
        echo $url
    done
    
    if [ "$domain_configured" = "true" ] && [ -n "$configured_domain" ]; then
        echo "域名访问: https://$configured_domain"
    fi
}

# 检查服务状态
check_services_status() {
    echo -e "\n服务状态："
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 主程序入口
main() {
    show_logo
    check_requirements
    
    # 检查基础目录和文件
    if [ ! -d "/etc/vpsai" ]; then
        echo "正在初始化系统..."
        # 创建系统目录和复制文件
        mkdir -p /etc/vpsai
        cp -r "$(dirname "$0")/docker-compose" /etc/vpsai/
        cp -r "$(dirname "$0")/nginx" /etc/vpsai/
        cp -r "$(dirname "$0")/cron" /etc/vpsai/
    fi
    
    # 检查命令安装
    if [ ! -f "/usr/local/bin/vpsai" ]; then
        echo "正在安装vpsai命令..."
        cp "$0" /usr/local/bin/vpsai
        chmod +x /usr/local/bin/vpsai
        echo -e "${GREEN}VPSAI 安装完成！${NC}"
        echo "后续可直接使用 'vpsai' 命令启动程序"
        echo "----------------------------------------"
    fi
    
    install_base_packages
    create_docker_network  # 添加这一行
    # 移除 init_mysql_service 调用
    while true; do
        show_menu
    done
}

# 运行主程序
main
