#!/bin/bash

# API服务安装
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
