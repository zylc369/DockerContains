# Docker 容器集合

本项目包含三个 Docker 化的服务，用于搭建完整的开发和文件管理环境。

## 📦 服务概览

| 服务 | 用途 | 端口 |
|------|------|------|
| **ai-container** | AI 编程助手开发环境 | 4097 (Web UI) |
| **Gitea** | 自托管 Git 服务 | 3000 (Web), 222 (SSH) |
| **OpenListNew** | 文件管理与下载服务 | 5244 |

## 🚀 快速开始

### 前置要求

- Docker 和 Docker Compose
- GitHub Personal Access Token（用于 ai-container）
- API Key（用于 OpenCode）

### 1. AI 开发环境 (ai-container)

基于 Ubuntu 22.04 的 AI 编程环境，包含：
- Node.js + Bun 运行时
- OpenCode (zylc369 自定义版本)
- oh-my-opencode 扩展
- 自动 Git 仓库克隆

```bash
cd ai-container

# 首次启动（会提示输入 GitHub Token 和 API Key）
./start.sh

# 强制重启
./start.sh --restart

# 完全重建
./rebuild.sh

# 查看日志
docker-compose logs -f

# 进入容器
docker exec -it ai-container bash
```

**访问地址**: http://localhost:4097

#### 配置说明

1. **GitHub Token**: 首次运行时会提示输入，用于访问私有仓库
   - 创建地址: https://github.com/settings/tokens
   - 权限要求: Contents (Read and write)

2. **API Key**: 用于 OpenCode 服务（zai-coding-plan 和 zhipuai-coding-plan）

3. **自动克隆仓库**: 编辑 `ai-container/data/home/.config/repos/repos.json`

```json
{
  "repos": [
    {
      "url": "https://github.com/owner/repo",
      "branch": "main",
      "directory": "/home/aiuser/Codes/repo"
    }
  ]
}
```

4. **数据持久化**:
   - `./data/home/Codes/` - 代码目录
   - `./data/home/.local/share/opencode/auth.json` - API 密钥
   - `./data/home/.config/opencode/` - OpenCode 配置

### 2. Git 托管服务 (Gitea)

轻量级自托管 Git 服务，使用 PostgreSQL 数据库。

```bash
cd Gitea

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 停止服务
docker-compose down
```

**访问地址**: 
- Web UI: http://localhost:3000
- SSH: `git clone ssh://git@localhost:222/username/repo.git`

**数据存储**:
- `./gitea/` - Gitea 数据
- `./postgres/` - PostgreSQL 数据

### 3. 文件管理服务 (OpenListNew)

文件管理平台，集成多个下载器。

**包含的服务**:
- **OpenList**: 核心文件管理服务 (端口 5244)
- **Aria2**: 下载器 (端口 6800, 6888)
- **AriaNG**: Aria2 Web UI (端口 6880)
- **qBittorrent**: BT 下载器 (端口 8080, 6881)
- **Transmission**: BT 下载器 (端口 9091, 51413)

```bash
cd OpenListNew

# 配置环境变量（首次使用）
cp .env.example .env
# 编辑 .env 文件，设置必要的环境变量

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 停止服务
docker-compose down
```

**访问地址**:
- OpenList: http://localhost:5244
- AriaNG: http://localhost:6880
- qBittorrent: http://localhost:8080
- Transmission: http://localhost:9091

#### 环境变量配置

创建 `OpenListNew/.env` 文件：

```bash
# 用户 ID
OPLISTDX_PUID=1000
OPLISTDX_PGID=1000

# 时区
OPLISTDX_TZ=Asia/Shanghai

# 数据目录
OPLISTDX_DATA=/path/to/data
OPLISTDX_DOWNLOADS=/path/to/downloads
OPLISTDX_TEMP=/path/to/temp

# Aria2 密钥
OPLISTDX_ARIA2TOKEN=your_aria2_token

# Transmission 配置
OPLISTDX_TRANSMISSION_USER=admin
OPLISTDX_TRANSMISSION_PASS=password
OPLISTDX_TRANSMISSION_PEERPORT=51413
OPLISTDX_TRANSMISSION_WEB_HOME=
OPLISTDX_TRANSMISSION_WHITELIST=
OPLISTDX_TRANSMISSION_HOST_WHITELIST=
OPLISTDX_TRANSMISSIONWATCH=/path/to/watch
```

## 📁 项目结构

```
.
├── ai-container/          # AI 开发环境
│   ├── start.sh          # 启动脚本
│   ├── rebuild.sh        # 重建脚本
│   ├── Dockerfile        # 容器定义
│   ├── docker-compose.yml
│   ├── entrypoint.sh     # 入口脚本
│   └── data/             # 数据持久化
│       └── home/
│           ├── Codes/    # 代码仓库
│           └── .config/  # 配置文件
│
├── Gitea/                # Git 托管服务
│   ├── docker-compose.yml
│   ├── gitea/           # Gitea 数据
│   └── postgres/        # 数据库数据
│
└── OpenListNew/         # 文件管理服务
    ├── docker-compose.yml
    └── .env             # 环境配置
```

## ⚙️ 高级配置

### AI 容器自定义

#### 修改 OpenCode 版本

编辑 `ai-container/Dockerfile`，修改安装源：

```dockerfile
# 使用自定义 fork
RUN git clone https://github.com/zylc369/opencode.git
```

#### 更改默认密码

⚠️ **安全警告**: 修改 `ai-container/Dockerfile` 第 50 行的默认密码

```dockerfile
RUN echo "aiuser:your_password" | chpasswd
```

#### 端口映射

编辑 `ai-container/docker-compose.yml`：

```yaml
ports:
  - "4097:4096"  # Web UI
  - "4173:4173"  # Serve
```

### Gitea 数据库配置

编辑 `Gitea/docker-compose.yml`：

```yaml
environment:
  - GITEA__database__USER=your_user
  - GITEA__database__PASSWD=your_password
```

## 🔧 故障排查

### AI 容器无法启动

1. 检查 `.env` 文件是否包含有效的 `GITHUB_TOKEN`
2. 检查 `auth.json` 是否包含有效的 API Key
3. 查看日志: `docker-compose logs -f`

### Gitea 无法连接数据库

1. 确认 PostgreSQL 容器正在运行: `docker-compose ps`
2. 检查数据库密码是否一致
3. 查看数据库日志: `docker-compose logs db`

### OpenListNew 服务异常

1. 确认 `.env` 文件中所有路径变量已设置
2. 确认用户 ID (PUID/PGID) 有正确的文件系统权限
3. 检查端口是否被占用

## ⚠️ 安全注意事项

1. **不要**在 Dockerfile 或脚本中硬编码 `GITHUB_TOKEN`
2. **不要**使用 root 用户运行容器（ai-container 使用 aiuser）
3. **修改** AI 容器的默认密码（生产环境必须）
4. **保护** `.env` 和 `auth.json` 文件，不要提交到版本控制
5. **定期更新** Docker 镜像以获取安全补丁

## 📝 开发指南

### 修改容器配置

1. 修改相应的 `docker-compose.yml` 或 `Dockerfile`
2. 对于 ai-container，运行 `./rebuild.sh` 完全重建
3. 对于其他服务，运行 `docker-compose up -d --build`

### 添加新仓库到 AI 容器

编辑 `ai-container/data/home/.config/repos/repos.json` 并重启容器。

## 📄 许可证

本项目仅供个人学习和开发使用。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**维护者**: [@aserlili](https://github.com/aserlili)  
**最后更新**: 2026-03-12
