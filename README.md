# n8n-ffmpeg

这是一个为 n8n 工作流自动化平台集成 FFmpeg 功能的 Docker 镜像项目。通过此项目，您可以在 n8n 中使用 FFmpeg 进行音视频处理、转码、分析等多媒体操作。

## 项目概述

本项目基于官方 n8n 镜像（1.122.5），集成了 FFmpeg 7.0.2 静态编译版本，提供了完整的音视频处理能力。适用于需要在 n8n 工作流中进行媒体文件处理的各种场景。

## 主要特性

### 🎬 FFmpeg 功能
- **音视频转码**: 支持各种格式之间的转换
- **视频处理**: 剪辑、合并、添加水印、调整分辨率等
- **音频处理**: 提取、合并、转换音频格式
- **媒体分析**: 获取媒体文件详细信息
- **VMAF 支持**: 包含完整的 VMAF 模型库，用于视频质量评估

### 🐳 Docker 集成
- 基于官方 n8n 镜像构建
- 中国时区配置 (Asia/Shanghai)
- 优化的容器配置
- 支持外部数据卷持久化

### 📊 VMAF 模型库
包含完整的 VMAF (Video Multimethod Assessment Fusion) 模型库：
- **标准模型**: vmaf_v0.6.1, vmaf_b_v0.6.3 等
- **4K 模型**: vmaf_4k_v0.6.1, vmaf_4k_rb_v0.6.2 等
- **浮点模型**: vmaf_float 系列
- **Netflix 模型**: 多种 Netflix 训练模型

## 快速开始

### 前提条件
- Docker 和 Docker Compose 已安装
- 可用的域名和 SSL 证书（用于生产环境）

### 1. 克隆项目
```bash
git clone <项目地址>
cd n8n-ffmpeg
```

### 2. 构建镜像
```bash
./build-image.sh
# 或docker build -t n8n-with-ffmpeg:latest .
```
> 脚本说明：[build-image.sh](#build-image)

### 3. 启动服务
```bash
./restart.sh
# 或 docker-compose up -d
```
> 脚本说明：[restart.sh](#restart)

### 4. 使用便捷脚本
项目提供了几个便捷的 shell 脚本来简化容器管理：

#### 🔨 构建镜像脚本 (`build-image.sh`) <a name="build-image"></a>
自动化构建新镜像并更新 docker-compose.yml 文件：
```bash
./build-image.sh
```

**功能特点：**
- 自动构建带有时间戳标签的镜像
- 备份原有的 docker-compose.yml 文件
- 智能替换镜像名称（支持变量和直接引用格式）
- 验证 docker-compose 文件语法
- 自动清理旧镜像（保留最新3个）

**构建过程：**
1. 检查必要文件是否存在
2. 构建新的 Docker 镜像（格式：`n8n-with-ffmpeg:1.122.5-YYYYMMDDhhmmss`）
3. 备份当前的 docker-compose.yml 文件
4. 更新 docker-compose.yml 中的镜像引用
5. 验证配置文件语法
6. 提供部署和清理指导

#### 🔄 重启脚本 (`restart.sh`) <a name="restart"></a>
快速重启 n8n 容器：
```bash
./restart.sh
```

**执行流程：**
- 停止当前运行的容器
- 等待1秒确保完全停止
- 重新启动容器

#### ⏹️ 停止脚本 (`stop.sh`)
停止 n8n 容器：
```bash
./stop.sh
```

**功能：**
- 优雅地停止 n8n 容器
- 释放相关资源

### 5. 访问 n8n
打开浏览器访问 `http://localhost:5678` 即可使用 n8n。

## 配置说明

### Docker Compose 配置

```yaml
version: '3.8'

services:
  n8n:
    image: n8n-with-ffmpeg:1.122.5-20251208182708
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      # 本地化配置
      - N8N_DEFAULT_LOCALE=zh-CN
      - GENERIC_TIMEZONE=Asia/Shanghai
      - TZ=Asia/Shanghai
      
      # URL 配置
      - N8N_EDITOR_BASE_URL=https://your-domain.com
      - WEBHOOK_URL=https://your-domain.com/
      - N8N_HOST=your-domain.com
      
      # 性能优化
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_RUNNERS_ENABLED=false
      
      # 日志配置
      - LOG_LEVEL=debug
      - N8N_LOG_OUTPUT_FORMATTER=simple
      
    volumes:
      - n8n_data:/home/node/.n8n
      - /your/path/files:/home/node/files
    shm_size: '256mb'
```

### 环境变量说明

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `N8N_DEFAULT_LOCALE` | 默认语言 | `zh-CN` |
| `GENERIC_TIMEZONE` | 时区设置 | `Asia/Shanghai` |
| `TZ` | 系统时区 | `Asia/Shanghai` |
| `N8N_EDITOR_BASE_URL` | n8n 编辑器基础 URL | - |
| `WEBHOOK_URL` | Webhook 基础 URL | - |
| `N8N_HOST` | n8n 主机名 | - |
| `N8N_DEFAULT_BINARY_DATA_MODE` | 二进制数据存储模式 | `filesystem` |
| `LOG_LEVEL` | 日志级别 | `debug` |

## 使用示例

### 在 n8n 中使用 FFmpeg

#### 1. 执行节点中使用 FFmpeg
在 Execute Command 节点中，您可以直接使用 ffmpeg 命令：

```bash
# 获取视频信息
ffmpeg -i input.mp4

# 转换视频格式
ffmpeg -i input.mp4 -c:v libx264 -c:a aac output.mp4

# 提取音频
ffmpeg -i input.mp4 -vn -acodec copy output.aac

# 调整视频分辨率
ffmpeg -i input.mp4 -vf scale=1280:720 output_720p.mp4
```

#### 2. 使用 VMAF 进行视频质量评估
```bash
# 使用 VMAF 模型比较两个视频的质量
ffmpeg -i reference.mp4 -i distorted.mp4 -lavfi "libvmaf=model_path=/usr/local/share/model/vmaf_v0.6.1.pkl" -f null -
```

#### 3. 批量处理示例
```bash
# 批量转换目录中的所有视频文件
for file in *.mov; do
  ffmpeg -i "$file" -c:v libx264 -c:a aac "${file%.mov}.mp4"
done
```

## 文件结构

```
n8n-ffmpeg/
├── Dockerfile                    # Docker 镜像构建文件
├── docker-compose.yml          # Docker Compose 配置文件
├── build-image.sh             # 智能构建镜像脚本
├── restart.sh                 # 快速重启容器脚本
├── stop.sh                    # 停止容器脚本
├── ffmpeg-7.0.2-amd64-static/  # FFmpeg 静态编译版本
│   ├── ffmpeg                   # FFmpeg 可执行文件
│   ├── ffprobe                  # FFprobe 可执行文件
│   ├── manpages/               # 帮助文档
│   └── model/                  # VMAF 模型库
└── README.md                   # 项目说明文档
```

## 便捷脚本使用指南

本项目提供了三个实用的 shell 脚本，用于简化容器管理操作：

### 🔨 build-image.sh - 智能构建脚本

这是最强大的脚本，自动化了整个镜像构建和部署流程。

**使用方法：**
```bash
chmod +x build-image.sh  # 确保脚本有执行权限
./build-image.sh
```

**脚本功能详解：**
1. **环境检查**：验证 Dockerfile 和 docker-compose.yml 文件存在
2. **镜像构建**：创建带时间戳标签的新镜像
3. **自动备份**：为 docker-compose.yml 创建带时间戳的备份
4. **智能替换**：自动更新 docker-compose.yml 中的镜像引用
5. **语法验证**：确保更新后的配置文件语法正确
6. **清理建议**：提供清理旧镜像的命令

**输出示例：**
```
🎯 Building new image: n8n-with-ffmpeg:1.122.5-20241216153045
✅ Image built successfully.
🔍 Verifying built image:
REPOSITORY          TAG                           IMAGE ID       SIZE
n8n-with-ffmpeg     1.122.5-20241216153045        abc123def456   1.23GB
💾 Backup saved as: docker-compose.yml.bak.20241216153045
🔍 Step 3/5: Previewing change...
--- docker-compose.yml
+++ docker-compose.yml
@@ -1,5 +1,5 @@
 services:
   n8n:
-    image: n8n-with-ffmpeg:1.122.5-20241216150000
+    image: n8n-with-ffmpeg:1.122.5-20241216153045
✅ Compose file is valid and ready to deploy.
```

### 🔄 restart.sh - 快速重启脚本

用于快速重启 n8n 容器，常用于配置更新后。

**使用方法：**
```bash
chmod +x restart.sh
./restart.sh
```

**执行过程：**
```
stop...
[+] Running 2/2
 ✔ Container n8n  Stopped
start...
[+] Running 2/2
 ✔ Container n8n  Started
```

### ⏹️ stop.sh - 容器停止脚本

优雅地停止 n8n 容器服务。

**使用方法：**
```bash
chmod +x stop.sh
./stop.sh
```

**执行结果：**
```
stop...
[+] Running 2/2
 ✔ Container n8n  Stopped
```

### 💡 脚本使用最佳实践

1. **定期构建**：建议定期运行 `build-image.sh` 获取最新的安全更新
2. **重启策略**：配置更新后使用 `restart.sh` 而不是手动操作
3. **备份管理**：build-image.sh 会自动创建备份，但建议定期清理旧备份
4. **权限设置**：首次使用时确保脚本有执行权限 (`chmod +x *.sh`)

### 🛠️ 故障排除

**脚本执行权限问题：**
```bash
# 如果提示权限不足
chmod +x build-image.sh restart.sh stop.sh
```

**Docker 命令未找到：**
```bash
# 确保 Docker 和 Docker Compose 已正确安装
docker --version
docker compose version
```

**构建失败：**
- 检查 Dockerfile 是否存在且语法正确
- 确认网络连接正常（需要下载基础镜像）
- 查看详细的错误信息输出

## 性能优化建议

### 1. 资源配置
- **内存**: 建议分配至少 2GB 内存用于媒体处理
- **共享内存**: 设置 `shm_size: '256mb'` 或更高
- **CPU**: 媒体转码需要较强的 CPU 性能

### 2. 存储优化
- 使用 `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` 模式
- 将文件存储卷挂载到高速存储设备
- 定期清理临时文件

### 3. 网络配置
- 配置适当的 Webhook URL
- 使用 CDN 加速静态资源访问
- 配置反向代理以提高安全性

## 故障排除

### 常见问题

#### 1. FFmpeg 命令执行失败
- 检查输入文件路径是否正确
- 确认文件权限是否足够
- 查看容器日志获取详细错误信息

#### 2. 内存不足
- 增加 Docker 容器内存限制
- 优化 FFmpeg 命令参数
- 分批处理大文件

#### 3. 处理速度慢
- 检查 CPU 资源分配
- 使用硬件加速（如可用）
- 优化编码参数

### 日志查看
```bash
# 查看容器日志
docker logs n8n

# 实时查看日志
docker logs -f n8n
```

## 安全注意事项

1. **文件权限**: 确保挂载卷的文件权限设置正确
2. **网络安全**: 在生产环境中使用 HTTPS 和身份验证
3. **资源限制**: 设置适当的容器资源限制
4. **定期更新**: 保持镜像和依赖项的最新状态

## 更新和维护

### 使用便捷脚本更新
推荐使用提供的脚本来简化更新过程：

```bash
# 构建新镜像并自动更新配置
./build-image.sh

# 重启容器应用更新
./restart.sh
```

### 手动更新 FFmpeg
1. 下载新版本的 FFmpeg 静态包 [ffmpeg-release-amd64-static.tar.xz](https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz)
2. 替换 `ffmpeg-7.0.2-amd64-static` 目录
3. 更新 Dockerfile 中的版本引用
4. 运行 `./build-image.sh` 重新构建镜像

### 手动更新 n8n
1. 修改 Dockerfile 中的基础镜像版本
2. 运行 `./build-image.sh` 重新构建镜像
3. 测试兼容性

## 许可证

本项目采用 GPLv3 许可证。FFmpeg 静态包及其包含的组件遵循各自的许可证条款。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进此项目。

## 支持

如果您遇到问题或有建议，请通过以下方式联系：
- 提交 GitHub Issue
- 查看 FFmpeg 官方文档: https://ffmpeg.org/documentation.html
- 查看 n8n 官方文档: https://docs.n8n.io/

---

**注意**: 使用此项目即表示您同意遵守所有相关软件许可证条款和条件。