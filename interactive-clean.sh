#!/bin/bash

# ==================================
# 🎨 ANSI Colors (safe fallback)
# ==================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
print_ok()    { echo -e "${GREEN}✅ $*${NC}"; }
print_warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
print_error() { echo -e "${RED}❌ $*${NC}"; }
print_head()  { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ==================================
# 🧩 步骤 1：选择并删除容器（支持多选）
# 返回值：0=跳过，1=已执行操作
# ==================================
select_and_remove_containers() {
  local did_something=0
  print_head
  echo -e "${BLUE}📦 步骤 1：选择要停止并删除的容器（支持空格多选）${NC}"
  print_head

  mapfile -t containers < <(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}' 2>/dev/null | sort -k2 2>/dev/null)

  if [ ${#containers[@]} -eq 0 ]; then
    print_warn "未发现任何容器。退出。"
    return 0
  fi

  echo "序号  容器 ID     名称          状态"
  echo "────  ────────── ────────────  ────────────"
  for i in "${!containers[@]}"; do
    id=$(echo "${containers[$i]}" | awk '{print $1}')
    name=$(echo "${containers[$i]}" | awk '{print $2}')
    status=$(echo "${containers[$i]}" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
    printf "%-4d  %-10s %-12s %s\n" "$((i+1))" "$id" "$name" "$status"
  done
  echo

  read -p "请输入要操作的序号（空格分隔，如：1 3 5）或按 Enter 跳过: " -r selections
  echo

  if [[ -z "$selections" ]]; then
    print_warn "未选择容器，跳过容器删除步骤。"
    return 0
  fi

  # 解析序号
  selected_ids=()
  invalid=()
  for sel in $selections; do
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#containers[@]}" ]; then
      name=$(echo "${containers[$((sel-1))]}" | awk '{print $2}')
      selected_ids+=("$name")
    else
      invalid+=("$sel")
    fi
  done

  if [ ${#invalid[@]} -gt 0 ]; then
    print_error "无效序号：${invalid[*]}，退出。"
    return 0
  fi

  if [ ${#selected_ids[@]} -eq 0 ]; then
    print_warn "未解析到有效容器名，退出。"
    return 0
  fi

  # 去重
  readarray -t unique_ids < <(printf '%s\n' "${selected_ids[@]}" | sort -u)

  print_info "将操作以下容器：${unique_ids[*]}"
  read -p "确认？(y/N): " -r confirm
  echo
  if [[ ! $confirm =~ ^[yY][eE]?[sS]?$ ]]; then
    print_warn "已取消容器操作。"
    return 0
  fi

  # ✅ 执行
  for name in "${unique_ids[@]}"; do
    print_info "🔄 处理容器: $name"
    if docker ps -q --filter name="^/$name$" >/dev/null; then
      docker stop "$name" >/dev/null && print_ok "已停止: $name" || print_error "停止失败: $name"
    else
      print_info "容器 $name 未运行（跳过 stop）"
    fi
    if docker rm "$name" >/dev/null; then
      print_ok "已删除: $name"
      did_something=1
    else
      print_error "删除失败: $name"
    fi
  done

  return $did_something
}

# ==================================
# 🖼️ 步骤 2：选择并删除镜像（带依赖检查）
# 返回值：0=跳过，1=已执行操作
# ==================================
select_and_remove_image() {
  local did_something=0
  print_head
  echo -e "${BLUE}🖼️  步骤 2：选择要删除的镜像（仅显示 n8n-with-ffmpeg:*）${NC}"
  print_head

  mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' 'n8n-with-ffmpeg:*' 2>/dev/null | sort -r 2>/dev/null)

  if [ ${#images[@]} -eq 0 ]; then
    print_warn "未找到 n8n-with-ffmpeg:* 镜像。退出。"
    return 0
  fi

  echo "序号  镜像标签"
  echo "────  ────────────────────────────"
  for i in "${!images[@]}"; do
    printf "%-4d  %s\n" "$((i+1))" "${images[$i]}"
  done
  echo

  read -p "请输入镜像序号（如：1）或按 Enter 跳过: " -r img_sel
  echo

  if [[ -z "$img_sel" ]]; then
    print_warn "未选择镜像，跳过镜像删除步骤。"
    return 0
  fi

  if [[ "$img_sel" =~ ^[0-9]+$ ]] && [ "$img_sel" -ge 1 ] && [ "$img_sel" -le "${#images[@]}" ]; then
    IMAGE_TO_DELETE="${images[$((img_sel-1))]}"
  else
    print_error "无效序号，退出。"
    return 0
  fi

  print_info "准备删除镜像：$IMAGE_TO_DELETE"

  # 🔍 检查是否被其他容器使用（排除已删容器）
  used_by=()
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      cid=$(echo "$line" | awk '{print $1}')
      cname=$(echo "$line" | awk '{print $2}')
      cimage=$(docker inspect "$cid" 2>/dev/null | jq -r '.[0].Config.Image' 2>/dev/null | tr -d '"')
      if [[ "$cimage" == "$IMAGE_TO_DELETE" ]]; then
        used_by+=("$cname ($cid)")
      fi
    fi
  done < <(docker ps -a --format '{{.ID}} {{.Names}}' 2>/dev/null)

  if [ ${#used_by[@]} -gt 0 ]; then
    print_error "🚫 镜像 $IMAGE_TO_DELETE 正被以下容器使用："
    printf "   • %s\n" "${used_by[@]}"
    print_warn "请先处理这些容器，或返回上一步重新选择。"
    echo
    read -p "按 Enter 返回容器选择步骤..."
    echo
    select_and_remove_containers
    select_and_remove_image
    return $?
  fi

  read -p "确认删除镜像 '$IMAGE_TO_DELETE'？(y/N): " -r confirm_img
  echo
  if [[ $confirm_img =~ ^[yY][eE]?[sS]?$ ]]; then
    if docker rmi "$IMAGE_TO_DELETE" 2>/dev/null; then
      print_ok "镜像 '$IMAGE_TO_DELETE' 已成功删除！"
      did_something=1
    else
      print_error "删除失败（可能被缓存层引用）。"
    fi
  else
    print_warn "已取消镜像删除。"
  fi

  return $did_something
}

# ==================================
# 🚀 主流程（智能判断是否执行了操作）
# ==================================
main() {
  trap 'echo; print_error "已中断。"; exit 130' INT TERM

  print_info "🎯 n8n 容器与镜像交互式清理工具"
  echo

  # 执行两步，并捕获是否执行了操作
  select_and_remove_containers
  container_done=$?
  echo

  select_and_remove_image
  image_done=$?

  # ✅ 仅当至少一步有操作时，才显示完成提示
  if [ "$container_done" -eq 1 ] || [ "$image_done" -eq 1 ]; then
    print_head
    print_ok "✅ 清理完成！"
    print_head
    echo "💡 提示："
    echo "   • 查看剩余容器：docker ps -a"
    echo "   • 查看剩余镜像：docker images | grep n8n-with-ffmpeg"
  else
    print_head
    print_info "ℹ️  未执行任何清理操作。"
    print_head
  fi
}

# ================
# 🏁 启动
# ================
main "$@"
