# VPSAI - 开源AI服务快速部署工具

<p align="center">
    <em>轻松部署和管理各类AI服务的自动化脚本工具</em>
</p>

<div align="center">

![Version](https://img.shields.io/badge/version-0.0.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-required-blue)

</div>

## ✨ 特性

- 🚀 一键部署多种流行AI服务
- 🔧 自动配置运行环境(Docker/Nginx)
- 🔐 支持HTTPS和证书自动配置
- 💾 数据持久化和备份方案
- 🔄 支持服务状态监控和自动更新

## 📦 支持的服务

### API网关
| 服务名 | 默认端口 | 说明 |
|--------|----------|------|
| OneAPI | 3000 | OpenAI API代理聚合 |
| NewAPI | 4000 | 新一代API管理平台 |
| VoAPI  | 5000 | 语音服务API(仅x86) |

### Chat前端
| 服务名 | 默认端口 | 说明 |
|--------|----------|------|
| Open-WebUI | 6001 | 开源Web界面 |
| NextChat | 7000 | 轻量级聊天前端 |
| LibreChat | 8000 | 功能丰富的聊天系统 |
| LobeChat | 9000 | AI助手交互界面 |

## 🚀 快速开始

### 一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/Protomyst/vpsai/main/install.sh | sudo bash
```

或者手动安装：
```bash
git clone https://github.com/Protomyst/vpsai.git && cd vpsai && sudo bash vpsai.sh
```

### 使用教程

1. **选择服务类型**
```bash
1. API服务
2. Chat服务
```

2. **配置参数**
- 端口号(可自定义)  
- API Key(部分服务需要)
- 访问密码(可选)

3. **域名配置**
```bash
# 使用自定义证书
vpsai > 5 > 1

# 自动申请Let's Encrypt
vpsai > 5 > 2
```

## 💻 环境要求

- Linux系统(Debian/Ubuntu/CentOS)
- Root权限
- Docker环境
- 最低配置:
  - CPU: 1核
  - 内存: 2G
  - 硬盘: 20G

## 📝 配置说明

### 数据目录结构
```
/root/ai/
├── data/           # 服务数据
│   ├── one-api/
│   ├── new-api/
│   └── ...
├── logs/           # 运行日志
└── backup/         # 备份文件
```

### 端口使用
- API服务: 3000-5000
- Chat服务: 6001-9000
- 可自定义修改

## 🔒 安全建议

1. 修改默认密码
2. 配置域名和HTTPS
3. 定期备份数据
4. 及时更新版本

## 🆘 常见问题

<details>
<summary>1. 端口冲突解决</summary>
检查占用端口进程:
```bash 
netstat -tunlp | grep 端口号
```
</details>

<details>
<summary>2. 服务无法访问</summary>
- 检查防火墙配置
- 确认端口是否开放
- 查看服务日志
</details>

## 📞 获取帮助

- Issues: https://github.com/Protomyst/vpsai/issues
- 邮箱: protomyst@outlook.com

## 📄 开源协议

本项目采用 [MIT](LICENSE) 协议开源。
