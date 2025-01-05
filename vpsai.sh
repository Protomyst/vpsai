#!/bin/bash

VERSION="v0.0.1"
AUTHOR="Protomyst"
ROOT_DIR="/root/ai"
DATA_DIR="${ROOT_DIR}/data"

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
    echo "2. 安装Chat服务 (Open-WebUI / NextChat / LibreChat (暂时失效) / LobeChat)"
    echo "3. 检查服务状态"
    echo "4. 配置自动更新或手动更新"
    echo "5. 配置自定义域名"
    echo "6. 删除Chat / API服务"
    echo "7. 查看帮助"
    echo "8. 退出脚本"
    echo
    read -p "请输入选项 [1-8]: " choice
    
    case $choice in
        1) install_api_service && read -p "按回车键继续..." ;;
        2) install_chat_service && read -p "按回车键继续..." ;;
        3) check_service_status ;;
        4) configure_updates && read -p "按回车键继续..." ;;
        5) configure_domain && read -p "按回车键继续..." ;;
        6) remove_service && read -p "按回车键继续..." ;;
        7) show_help ;;
        8) exit 0 ;;
        *) echo "无效选项" && read -p "按回车键继续..." ;;
    esac
}

##################
# 服务安装相关函数 #
##################

install_api_service() {
    echo "请选择要安装的API服务："
    echo "1. OneAPI (默认端口: 3000)"
    echo "2. NewAPI (默认端口: 4000)"
    if [ $is_arm -eq 0 ]; then
        echo "3. VoAPI (默认端口: 5000)"
    fi
    echo "0. 返回"
    
    read -p "请选择: " api_choice
    
    case $api_choice in
        1) install_one_api ;;
        2) install_new_api ;;
        3) 
            if [ $is_arm -eq 0 ]; then
                install_vo_api
            else
                echo "VoAPI 不支持 ARM 架构"
            fi
            ;;
        0) return ;;
        *) echo "无效选项" ;;
    esac
}

# Chat服务安装
install_chat_service() {
    echo "请选择要安装的Chat服务："
    echo "1. Open-WebUI (默认端口: 6000)"
    echo "2. NextChat (默认端口: 7000)"
    echo "3. LibreChat (默认端口: 8000)"
    echo "4. LobeChat (默认端口: 9000)"
    echo "0. 返回"
    
    read -p "请选择: " chat_choice
    
    # 获取系统内存
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    
    case $chat_choice in
        1)
            if [ $total_mem -lt 1024 ]; then
                echo "警告: 系统内存小于1GB，Open-WebUI可能无法正常运行"
                read -p "是否继续安装？(y/n): " confirm
                if [ "$confirm" != "y" ];then
                    return
                fi
            fi
            install_open_webui
            ;;
        2) install_nextchat ;;
        3) install_librechat ;;
        4) install_lobechat ;;
        0) return ;;
        *) echo "无效选项" ;;
    esac
}

# 获取服务器IP
get_server_ip() {
    # 优先获取公网IPv4地址
    public_ip=$(curl -s -4 ip.sb || curl -s -4 ifconfig.me || curl -s -4 icanhazip.com)
    if [ -n "$public_ip" ]; then
        echo "$public_ip"
        return
    fi
    
    # 如果获取公网IP失败，使用本地IP
    local_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    if [ -n "$local_ip" ]; then
        echo "$local_ip"
        return
    fi
    
    echo "无法获取服务器IP"
}

# 显示访问地址
show_access_info() {
    local service_name="$1"
    local port="$2"
    local extra_info="$3"
    
    echo "----------------------------------------"
    echo "🎉 $service_name 安装完成!"
    echo
    local ip=$(get_server_ip)
    echo "访问地址: http://$ip:$port"
    if [ -n "$extra_info" ]; then
        echo "$extra_info"
    fi
    echo "----------------------------------------"
    echo -e "\n按回车键返回主菜单..."
    read
}

# OneAPI安装
install_one_api() {
    local default_port=3000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    local data_dir=$(create_data_dir "one-api")
    
    docker run --name one-api -d \
        --restart always \
        -p ${port}:3000 \
        -e TZ=Asia/Shanghai \
        -v ${data_dir}:/data \
        justsong/one-api
        
    open_firewall_port $port
    show_access_info "OneAPI" "$port" "初始用户名: root\n初始密码: 123456"
}

# NewAPI安装
install_new_api() {
    local default_port=4000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    local data_dir=$(create_data_dir "new-api")
    
    docker run --name new-api -d \
        --restart always \
        -p ${port}:3000 \
        -e TZ=Asia/Shanghai \
        -v ${data_dir}:/data \
        calciumion/new-api:latest
        
    open_firewall_port $port
    show_access_info "NewAPI" "$port"
}

# VoAPI安装
install_vo_api() {
    local default_port=5000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    local data_dir=$(create_data_dir "voapi")
    local compose_file="${data_dir}/docker-compose.yml"
    
    # 生成docker-compose配置
    cat > "$compose_file" <<EOF
version: '3.4'
services:
  voapi:
    image: voapi/voapi:latest
    container_name: voapi
    restart: always
    command: --log-dir /app/logs
    ports:
      - "${port}:3000"
    volumes:
      - ${data_dir}/data:/data
      - ${data_dir}/logs:/app/logs
    environment:
      - SESSION_SECRET=$(openssl rand -hex 32)
      - TZ=Asia/Shanghai
    depends_on:
      - redis
  redis:
    image: redis:latest
    container_name: redis
    restart: always
EOF
    
    cd "$data_dir" && docker-compose up -d
    open_firewall_port $port
    show_access_info "VoAPI" "$port"
}

# Open WebUI安装
install_open_webui() {
    local default_port=6000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    local data_dir=$(create_data_dir "open-webui")
    
    docker run -d \
        -p ${port}:8080 \
        --add-host=host.docker.internal:host-gateway \
        -v ${data_dir}:/app/backend/data \
        --name open-webui \
        --restart always \
        ghcr.io/open-webui/open-webui:main
        
    open_firewall_port $port
    show_access_info "Open-WebUI" "$port"
}

# NextChat安装
install_nextchat() {
    local default_port=7000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    read -p "请输入访问密码: " access_code
    read -p "请输入OpenAI API Key: " api_key
    
    docker run -d \
        -p ${port}:3000 \
        -e OPENAI_API_KEY=${api_key} \
        -e CODE=${access_code} \
        --name nextchat \
        --restart always \
        yidadaa/chatgpt-next-web
        
    open_firewall_port $port
    show_access_info "NextChat" "$port" "访问密码: $access_code"
}

# LibreChat安装
install_librechat() {
    local default_port=8000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    local data_dir=$(create_data_dir "librechat")
    
    git clone https://github.com/danny-avila/LibreChat.git "${data_dir}"
    cd "${data_dir}"
    cp .env.example .env
    
    # 修改docker-compose端口
    sed -i "s/3000:3000/${port}:3000/g" docker-compose.yml
    
    docker-compose up -d
    open_firewall_port $port
    show_access_info "LibreChat" "$port"
}

# LobeChat安装
install_lobechat() {
    local default_port=9000
    read -p "请输入端口号 (默认: $default_port): " port
    port=${port:-$default_port}
    
    if ! check_port $port; then
        echo "端口 $port 已被占用"
        return
    fi
    
    read -p "请输入访问密码: " access_code
    read -p "请输入OpenAI API Key: " api_key
    
    docker run -d \
        -p ${port}:3210 \
        -e OPENAI_API_KEY=${api_key} \
        -e ACCESS_CODE=${access_code} \
        --name lobe-chat \
        --restart always \
        lobehub/lobe-chat
        
    open_firewall_port $port
    show_access_info "LobeChat" "$port" "访问密码: $access_code"
}

# 删除服务
remove_service() {
    echo "请选择要删除的服务："
    echo "1. OneAPI"
    echo "2. NewAPI"
    echo "3. VoAPI"
    echo "4. Open-WebUI"
    echo "5. NextChat"
    echo "6. LibreChat"
    echo "7. LobeChat"
    echo "0. 返回"
    
    read -p "请选择: " choice
    
    local service_name=""
    case $choice in
        1) service_name="one-api" ;;
        2) service_name="new-api" ;;
        3) service_name="voapi" ;;
        4) service_name="open-webui" ;;
        5) service_name="nextchat" ;;
        6) service_name="librechat" ;;
        7) service_name="lobe-chat" ;;
        0) return ;;
        *) echo "无效选项" ; return ;;
    esac
    
    echo "警告：将删除 $service_name 服务及其数据"
    echo "数据目录: ${DATA_DIR}/${service_name}"
    read -p "确认删除？(y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        docker stop $service_name
        docker rm $service_name
        docker rmi $(docker images | grep $service_name | awk '{print $3}')
        echo "服务已删除"
        echo -e "\n按回车键返回主菜单..."
        read
    fi
}

# 服务管理功能
manage_service() {
    local service="$1"
    echo "管理 $service:"
    echo "1. 启动"
    echo "2. 停止"
    echo "3. 重启"
    echo "4. 查看日志"
    echo "0. 返回"
    
    read -p "请选择: " choice
    
    case $choice in
        1) docker start $service ;;
        2) docker stop $service ;;
        3) docker restart $service ;;
        4) docker logs -f $service ;;
        0) return ;;
        *) echo "无效选项" ;;
    esac
}

# 优化状态检查
check_service_status() {
    echo "服务状态检查："
    printf "%-15s %-10s %-20s %-10s\n" "服务名" "状态" "端口" "内存使用"
    echo "------------------------------------------------"
    
    local services=("one-api" "new-api" "voapi" "open-webui" "nextchat" "librechat" "lobe-chat")
    
    for service in "${services[@]}"; do
        if docker ps -q -f name=$service >/dev/null 2>&1; then
            local status="运行中"
            local ports=$(docker port $service 2>/dev/null | awk '{print $3}' | cut -d':' -f2 | tr '\n' ',')
            local mem=$(docker stats $service --no-stream --format "{{.MemUsage}}" 2>/dev/null)
            printf "%-15s %-10s %-20s %-10s\n" "$service" "$status" "${ports%,}" "$mem"
        else
            if docker ps -aq -f name=$service >/dev/null 2>&1; then
                printf "%-15s %-10s %-20s %-10s\n" "$service" "已停止" "-" "-"
            else
                printf "%-15s %-10s %-20s %-10s\n" "$service" "未安装" "-" "-"
            fi
        fi
    done
    
    echo -e "\n输入服务名可以管理该服务，直接回车返回主菜单"
    read -p "请输入: " service_name
    
    if [ -n "$service_name" ]; then
        if [[ " ${services[@]} " =~ " ${service_name} " ]]; then
            manage_service "$service_name"
        else
            echo "无效的服务名"
        fi
    fi
}

##################
# 自定义域名配置  #
##################
# 配置域名
configure_domain() {
    echo "域名配置："
    echo "1. 使用自定义证书"
    echo "2. 自动申请Let's Encrypt证书"
    echo "0. 返回"
    
    read -p "请选择: " choice
    
    case $choice in
        1) configure_custom_cert ;;
        2) configure_letsencrypt ;;
        0) return ;;
        *) echo "无效选项" ;;
    esac
}

# 配置自定义证书
configure_custom_cert() {
    read -p "请输入域名: " domain
    read -p "请输入证书路径: " cert_path
    read -p "请输入私钥路径: " key_path
    
    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        echo "证书文件不存在"
        return
    fi
    
    # 选择要配置的服务
    echo "请选择要配置的服务:"
    echo "1. OneAPI (端口: 3000)"
    echo "2. NewAPI (端口: 4000)"
    echo "3. VoAPI (端口: 5000)"
    echo "4. Open-WebUI (端口: 6000)"
    echo "5. NextChat (端口: 7000)"
    echo "6. LibreChat (端口: 8000)"
    echo "7. LobeChat (端口: 9000)"
    
    read -p "请选择 [1-7]: " service_choice
    
    local port
    case $service_choice in
        1) port=3000 ;;
        2) port=4000 ;;
        3) port=5000 ;;
        4) port=6000 ;;
        5) port=7000 ;;
        6) port=8000 ;;
        7) port=9000 ;;
        *) 
            echo "无效选项"
            return
            ;;
    esac
    
    create_nginx_config "$domain" "$cert_path" "$key_path" "$port"
}

# 配置Let's Encrypt证书
configure_letsencrypt() {
    read -p "请输入域名: " domain
    read -p "请输入邮箱(用于证书通知): " email
    
    # 创建验证目录
    local acme_dir="/var/www/letsencrypt/.well-known/acme-challenge"
    mkdir -p "$acme_dir"
    
    # 创建初始Nginx配置用于验证
    local nginx_temp="/etc/nginx/sites-available/${domain}.temp"
    cat > "$nginx_temp" <<EOF
server {
    listen 80;
    server_name $domain;
    
    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/letsencrypt;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
    
    ln -sf "$nginx_temp" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    # 安装certbot
    if ! command -v certbot &> /dev/null; then
        echo "正在安装certbot..."
        snap install --classic certbot
    fi
    
    # 申请证书
    sudo certbot certonly \
        --webroot \
        --agree-tos \
        --email "$email" \
        --webroot-path /var/www/letsencrypt \
        --domains "$domain"
    
    if [ $? -ne 0 ]; then
        echo "证书申请失败"
        rm -f "$nginx_temp"
        return 1
    fi
    
    # 获取证书路径
    local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    local key_path="/etc/letsencrypt/live/$domain/privkey.pem"
    
    # 配置服务
    echo "请选择要配置的服务:"
    echo "1. OneAPI (端口: 3000)"
    echo "2. NewAPI (端口: 4000)"
    echo "3. VoAPI (端口: 5000)"
    echo "4. Open-WebUI (端口: 6000)"
    echo "5. NextChat (端口: 7000)"
    echo "6. LibreChat (端口: 8000)"
    echo "7. LobeChat (端口: 9000)"
    
    read -p "请选择 [1-7]: " service_choice
    
    local port
    case $service_choice in
        1) port=3000 ;;
        2) port=4000 ;;
        3) port=5000 ;;
        4) port=6000 ;;
        5) port=7000 ;;
        6) port=8000 ;;
        7) port=9000 ;;
        *) 
            echo "无效选项"
            return 1
            ;;
    esac
    
    create_nginx_config "$domain" "$cert_path" "$key_path" "$port"
    
    # 清理临时配置
    rm -f "$nginx_temp"
    
    # 配置自动续期
    echo "配置证书自动续期..."
    (crontab -l 2>/dev/null; echo "0 0 1 * * certbot renew --quiet") | crontab -
    
    echo "证书配置完成!"
    echo "域名访问地址: https://$domain"
}

# 创建Nginx配置
create_nginx_config() {
    domain=$1
    cert_path=$2
    key_path=$3
    port=$4
    
    nginx_config="/etc/nginx/sites-available/$domain"
    
    # 创建最终的Nginx配置
    cat > "$nginx_config" <<EOF
# HTTP重定向到HTTPS
server {
    listen 80;
    server_name $domain;
    
    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/letsencrypt;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS服务配置
server {
    listen 443 ssl http2;
    server_name $domain;
    
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    ssl_trusted_certificate $cert_path;
    
    # SSL配置优化
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+AESGCM:EECDH+AES;
    ssl_ecdh_curve secp384r1;
    ssl_prefer_server_ciphers on;
    
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # 安全头部
    add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # 反向代理配置
    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket支持
        proxy_read_timeout 86400;
    }
}
EOF
    
    # 检查配置并应用
    if nginx -t; then
        ln -sf "$nginx_config" /etc/nginx/sites-enabled/
        systemctl reload nginx
        echo "Nginx配置已更新: https://$domain"
        echo -e "\n按回车键返回主菜单..."
        read
    else
        echo "Nginx配置错误，请检查配置文件"
        rm -f "$nginx_config"
        echo -e "\n按回车键返回主菜单..."
        read
        return 1
    fi
}

##################
#  自动更新配置   #
##################

check_script_update() {
    echo "检查VPSAI脚本更新..."
    
    cd /tmp
    if git clone https://github.com/Protomyst/vpsai.git >/dev/null 2>&1; then
        cd vpsai
        remote_version=$(grep "VERSION=" vpsai.sh | cut -d'"' -f2)
        if [ "$remote_version" != "$VERSION" ]; then
            echo "发现新版本: $remote_version"
            read -p "是否更新？(y/n): " update_choice
            if [ "$update_choice" = "y" ]; then
                cp -r * /root/vpsai/
                echo "更新完成"
            fi
        else
            echo "已是最新版本"
        fi
        cd ..
        rm -rf vpsai
    else
        echo "检查更新失败"
    fi
}

# 配置自动更新
configure_updates() {
    echo "更新配置："
    echo "1. 立即检查更新"
    echo "2. 配置自动更新"
    echo "3. 取消自动更新"
    echo "0. 返回"
    
    read -p "请选择: " choice
    
    case $choice in
        1) check_script_update ;;
        2) setup_auto_update ;;
        3) remove_auto_update ;;
        0) return ;;
        *) echo "无效选项" ;;
    esac
}

# 检查单个服务更新
check_service_update() {
    local service="$1"
    local image="$2"
    
    echo "检查 $service 更新..."
    if docker pull "$image" | grep -q "Image is up to date"; then
        echo "$service 已是最新版本"
        return 0
    else
        echo "发现 $service 新版本"
        read -p "是否更新？(y/n): " update_choice
        if [ "$update_choice" = "y" ]; then
            docker stop "$service"
            docker rm "$service"
            return 1
        fi
    fi
    return 0
}

# 优化自动更新设置
setup_auto_update() {
    # 创建更新脚本
    cat > /etc/cron.daily/vpsai-update <<EOF
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# 更新脚本
cd /root/vpsai && git pull

# 更新服务
for service in \$(docker ps --format "{{.Names}}"); do
    image=\$(docker inspect \$service --format '{{.Config.Image}}')
    docker pull \$image
    if [ \$? -eq 0 ]; then
        docker stop \$service
        docker rm \$service
        docker run --restart always [原有参数] \$image
    fi
done

# 记录日志
logger -t vpsai-update "自动更新完成"
EOF
    
    chmod +x /etc/cron.daily/vpsai-update
    echo "已设置每日自动更新"
}

# 取消自动更新
remove_auto_update() {
    rm -f /etc/cron.daily/vpsai-update
    echo "已取消自动更新"
}


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
    
    while true; do
        show_menu
        # 这里不需要额外的暂停，因为在show_menu中已经处理了
    done
}

main
