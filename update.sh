#!/bin/bash

# 检查脚本更新
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
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

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
