#!/bin/bash

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
    
    create_nginx_config "$domain" "$cert_path" "$key_path"
}

# 配置Let's Encrypt证书
configure_letsencrypt() {
    read -p "请输入域名: " domain
    
    # 安装certbot
    if ! command -v certbot &> /dev/null; then
        echo "正在安装certbot..."
        sudo apt-get update
        sudo apt-get install -y certbot
    fi
    
    # 申请证书
    sudo certbot certonly --standalone -d "$domain"
    
    # 获取证书路径
    cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    key_path="/etc/letsencrypt/live/$domain/privkey.pem"
    
    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        echo "证书申请失败"
        return
    fi
    
    create_nginx_config "$domain" "$cert_path" "$key_path"
}

# 创建Nginx配置
create_nginx_config() {
    domain=$1
    cert_path=$2
    key_path=$3
    
    nginx_config="/etc/nginx/sites-available/$domain"
    
    sudo tee "$nginx_config" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain;
    
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    sudo ln -s "$nginx_config" /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
}

# 主菜单
main_menu() {
    echo "主菜单："
    echo "1. 配置域名"
    echo "0. 退出"
    
    read -p "请选择: " choice
    
    case $choice in
        1) configure_domain ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

# 运行主菜单
main_menu
