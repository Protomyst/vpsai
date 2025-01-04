#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 检查更新
check_update() {
    echo "检查更新中..."
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    # 克隆仓库
    if git clone --quiet https://github.com/Protomyst/vpsai.git; then
        cd vpsai
        
        # 获取最新版本号
        LATEST_VERSION=$(cat vpsai.sh | grep "VERSION=" | cut -d'"' -f2)
        CURRENT_VERSION=$(cat /usr/local/bin/vpsai | grep "VERSION=" | cut -d'"' -f2)
        
        # 比较版本
        if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
            echo -e "${GREEN}发现新版本: $LATEST_VERSION${NC}"
            
            # 更新文件
            cp -r docker-compose nginx cron /etc/vpsai/
            cp vpsai.sh /usr/local/bin/vpsai
            chmod +x /usr/local/bin/vpsai
            
            echo -e "${GREEN}更新完成！${NC}"
        else
            echo "当前已是最新版本"
        fi
    else
        echo -e "${RED}更新检查失败，请检查网络连接${NC}"
    fi
    
    # 清理临时文件
    cd /
    rm -rf $TMP_DIR
}

check_update
