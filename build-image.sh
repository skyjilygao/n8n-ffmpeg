#!/bin/bash

# ==================== 配置区 ====================
COMPOSE_FILE="docker-compose.yml"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${COMPOSE_FILE}.bak.${TIMESTAMP}"
NEW_IMAGE_NAME="n8n-with-ffmpeg:1.122.5-${TIMESTAMP}"

# ==================== 安全检查 ====================
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ Error: $COMPOSE_FILE not found in current directory!"
  exit 1
fi

if [ ! -f "Dockerfile" ] && [ ! -f "dockerfile" ]; then
  echo "❌ Error: Dockerfile not found! Cannot build image."
  exit 1
fi

echo "🎯 Building new image: ${NEW_IMAGE_NAME}"

# ==================== 构建镜像 ====================
if ! docker build -t "${NEW_IMAGE_NAME}" .; then
  echo "❌ Failed to build image '${NEW_IMAGE_NAME}'."
  exit 1
fi
echo "✅ Image built successfully."

# ==================== 查看新镜像 ====================
echo "🔍 Verifying built image:"
docker images --filter "reference=${NEW_IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"

# ==================== 提取旧镜像名（首次出现的 image: 行的值） ====================
OLD_IMAGE_NAME=$(awk '
  /^[[:space:]]*image:[[:space:]]*[^[:space:]#]+/ && !found {
    match($0, /image:[[:space:]]*([^[:space:]#]+)/, arr)
    if (arr[1] != "") {
      print arr[1]
      found = 1
    }
  }
' "$COMPOSE_FILE")

if [ -n "$OLD_IMAGE_NAME" ]; then
  echo "📦 Current image in $COMPOSE_FILE: $OLD_IMAGE_NAME"
else
  echo "⚠️  No 'image:' line found in $COMPOSE_FILE (or empty value)."
fi

# ==================== 备份原 compose 文件（带时间戳） ====================
cp "$COMPOSE_FILE" "$BACKUP_FILE"
if [ $? -ne 0 ]; then
  echo "❌ Failed to create backup: $BACKUP_FILE"
  exit 1
fi
echo "💾 Backup saved as: $BACKUP_FILE"

# ==================== 替换第一处 image: 的值（兼容 ${VAR} 和 plain） ====================
echo "✏️  Step 1/5: Generating updated compose content to ${COMPOSE_FILE}.tmp..."

# Step 1: 执行 awk 转换 → 写入 .tmp 文件
if ! awk -v new="$NEW_IMAGE_NAME" '
  /^[[:space:]]*image:[[:space:]]*[^[:space:]#]+/ && !replaced {
    # 匹配 ${VAR} 形式：image: ${IMAGE_NAME}
    if (/image:[[:space:]]*\$\{[^}]+\}/) {
      match($0, /^([[:space:]]*image:[[:space:]]*)(\$\{[^}]+\})/, arr)
      if (arr[1] != "") {
        print arr[1] new
        replaced = 1
        next
      }
    }
    # 匹配普通形式：image: xxx
    match($0, /^([[:space:]]*image:[[:space:]]*)([^[:space:]#]+)/, arr)
    if (arr[1] != "") {
      print arr[1] new
      replaced = 1
      next
    }
  }
  { print }
' "$COMPOSE_FILE" > "${COMPOSE_FILE}.tmp"; then
  echo "❌ Step 1 FAILED: awk conversion failed."
  echo "   Check syntax in $COMPOSE_FILE (e.g., unbalanced braces, tabs vs spaces)."
  exit 1
fi

# Step 2: 验证 .tmp 文件是否生成且非空
if [ ! -s "${COMPOSE_FILE}.tmp" ]; then
  echo "❌ Step 2 FAILED: ${COMPOSE_FILE}.tmp is empty or missing!"
  echo "   Raw output of awk:"
  awk -v new="$NEW_IMAGE_NAME" '
    /^[[:space:]]*image:[[:space:]]*[^[:space:]#]+/ && !replaced {
      if (/image:[[:space:]]*\$\{[^}]+\}/) {
        match($0, /^([[:space:]]*image:[[:space:]]*)(\$\{[^}]+\})/, arr)
        if (arr[1] != "") { print "MATCHED: " $0; print "REPLACED: " arr[1] new; exit }
      }
      match($0, /^([[:space:]]*image:[[:space:]]*)([^[:space:]#]+)/, arr)
      if (arr[1] != "") { print "MATCHED: " $0; print "REPLACED: " arr[1] new; exit }
    }
    { print "LINE: " $0 > "/dev/stderr" }
  ' "$COMPOSE_FILE" 2>&1 | head -n 20
  exit 1
fi

# Step 3: 查看 diff（确认改对了哪一行）
echo "🔍 Step 3/5: Previewing change..."
diff -u "$COMPOSE_FILE" "${COMPOSE_FILE}.tmp" || true

# Step 4: 安全移动（加 -f 防止提示，加 -v 显示动作）
echo "🔄 Step 4/5: Replacing $COMPOSE_FILE..."
if ! mv -fv "${COMPOSE_FILE}.tmp" "$COMPOSE_FILE"; then
  echo "❌ Step 4 FAILED: mv command failed!"
  echo "   Possible causes:"
  echo "     • Permission denied (check: ls -l $COMPOSE_FILE)"
  echo "     • File locked by another process (e.g., editor, docker compose)"
  echo "     • Disk full (check: df -h)"
  exit 1
fi

# Step 5: 最终验证 —— 确保新值已生效
UPDATED_IMAGE=$(grep -E '^[[:space:]]*image:' "$COMPOSE_FILE" | head -n1 | sed -E 's/^[[:space:]]*image:[[:space:]]*(.*)$/\1/' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
if [[ "$UPDATED_IMAGE" == "$NEW_IMAGE_NAME" ]]; then
  echo "✅ Step 5/5: Confirmed! $COMPOSE_FILE now uses:"
  echo "   image: $UPDATED_IMAGE"
else
  echo "❌ Step 5 FAILED: Replacement not found in final file!"
  echo "   Expected: $NEW_IMAGE_NAME"
  echo "   Found:    '$UPDATED_IMAGE'"
  echo "   Full line: $(grep -E '^[[:space:]]*image:' "$COMPOSE_FILE" | head -n1)"
  exit 1
fi
# ==================== 日志输出变更 ====================
if [ -n "$OLD_IMAGE_NAME" ]; then
  echo "🔄 Image updated: $OLD_IMAGE_NAME → $NEW_IMAGE_NAME"
else
  echo "🆕 First-time setup: image set to $NEW_IMAGE_NAME"
fi

# ==================== 验证 compose 文件语法 ====================
echo "🧪 Validating docker-compose.yml syntax..."
if docker compose config > /dev/null 2>&1; then
  echo "✅ Compose file is valid and ready to deploy."
else
  echo "❌ Invalid compose file! Please check:"
  docker compose config 2>&1
  echo ""
  echo "💡 Tip: Restore backup with:"
  echo "   cp '$BACKUP_FILE' '$COMPOSE_FILE'"
  exit 1
fi

# ==================== 下一步提示 ====================
echo ""
echo "🚀 Deployment ready! Run:"
echo "   docker compose up -d"
echo ""
echo "📋 To view logs:"
echo "   docker logs -f n8n"
echo ""
echo "🧹 To clean up old images (keep latest 3):"
echo "   docker images --format '{{.Repository}}:{{.Tag}}\t{{.Tag}}'   | awk -F'\t' '$1 ~ /n8n-with-ffmpeg/ && NF==2 { print $0 }'   | sort -k2,2r   | tail -n +4   | cut -f1   | xargs -r docker rmi -f 2>/dev/null || true"

