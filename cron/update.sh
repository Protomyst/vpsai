#!/bin/bash

# 检查更新
check_update() {
    cd /etc/vpsai
    git fetch origin main
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        git pull
        chmod +x /usr/local/bin/vpsai
        echo "VPSAI 已更新到最新版本"
    fi
}

check_update
