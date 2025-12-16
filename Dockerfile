FROM ghcr.io/n8n-io/n8n:1.122.5

# 切换到 root 执行系统级操作（时区、安装 ffmpeg）
USER root

# 设置中国时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone

# 复制你已下载的 jellyfin ffmpeg 静态包（单行）
COPY ffmpeg-release-amd64-static.tar.xz /tmp/ffmpeg.tar.xz

# 解压、提取 ffmpeg/ffprobe、设权限、清理临时文件（全部单行，无 \）
RUN mkdir -p /tmp/ffmpeg && tar -xf /tmp/ffmpeg.tar.xz --strip-components=1 -C /tmp/ffmpeg && cp /tmp/ffmpeg/ffmpeg /tmp/ffmpeg/ffprobe /usr/local/bin/ && chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe && rm -rf /tmp/ffmpeg /tmp/ffmpeg.tar.xz

# 切回 node 用户（必须！否则 entrypoint 会报错）
USER node

EXPOSE 5678

# ✅ 关键修复：不覆盖 CMD，让官方 entrypoint 自动运行 n8n
# （即：删除你原来的 CMD 行，什么都不写 → 继承原镜像的 ENTRYPOINT+CMD）
