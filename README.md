# VPSAI - 一键式AI服务部署工具

> 一个用于快速部署和管理AI相关服务的自动化脚本工具
> 
> Version: v0.0.1 by Protomyst

## 📖 功能特点

- 🚀 一键安装多种AI服务
- 🔧 自动配置Docker和Nginx
- 🔐 支持SSL证书自动配置
- 💾 数据持久化存储
- 🔄 支持自动更新

## 🎯 支持的服务

### API服务
- OneAPI (默认端口: 3000)
- NewAPI (默认端口: 4000)
- VoAPI (默认端口: 5000)

### Chat服务
- Open-WebUI (默认端口: 6000)
- NextChat (默认端口: 7000)
- LibreChat (默认端口: 8000)
- LobeChat (默认端口: 9000)

## 💻 系统要求

- Linux系统 (支持Debian/Ubuntu/CentOS)
- Root权限
- Docker环境
- 最小配置建议：1核2G内存

## 🚀 快速开始

1. 下载脚本：
```bash
git clone https://github.com/Protomysy/vpsai.git
cd vpsai
```

2. 运行脚本：
```bash
sudo bash vpsai.sh
```

3. 后续使用：
```bash
vpsai
```

## 📝 使用说明

### 主菜单选项
1. 安装API服务
2. 安装Chat服务
3. 检查服务状态
4. 配置更新服务
5. 修改Docker配置
6. 修改Nginx配置
7. 删除服务
8. 帮助
9. 退出

### 数据目录
所有服务数据存储在 `~/ai/data/` 目录下：
```
~/ai/data/
├── oneapi/
├── newapi/
├── voapi/
├── open-webui/
├── nextchat/
├── librechat/
└── lobechat/
```

## 🔒 安全说明

- 所有密码和密钥请自行修改
- 建议配置域名和SSL证书
- 定期备份数据目录

## 🆘 常见问题

1. **端口被占用**: 脚本会自动检测并提示更换端口
2. **ARM架构限制**: VoAPI不支持ARM架构
3. **配置要求**: Open-WebUI建议配置不低于1C1G

## 📞 技术支持

- GitHub Issues: https://github.com/Protomysy/vpsai/issues
- Email: protomyst@outlook.com

## 📄 开源协议

MIT License
