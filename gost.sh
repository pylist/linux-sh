#!/usr/bin/env bash
set -euo pipefail

# gost.sh - Gost 代理服务管理脚本
# 仓库: https://github.com/pylist/linux-sh
# 作者: pylist
# 许可: MIT

# ============================================================================
# 配置变量
# ============================================================================

GOST_DIR="/root/gost"
GOST_BIN="${GOST_DIR}/gost"
GOST_CONFIG="${GOST_DIR}/config.json"
SERVICE_NAME="gost"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# ============================================================================
# 辅助函数
# ============================================================================

info() { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[0;33m[!]\033[0m %s\n" "$*"; }
error() { printf "\033[0;31m[✗]\033[0m %s\n" "$*" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "需要 root 权限，请使用 sudo 运行"
    exit 1
  fi
}

# 检查 gost 是否存在
check_gost_exists() {
  if [ ! -f "$GOST_BIN" ]; then
    error "未找到 gost 二进制文件: $GOST_BIN"
    exit 1
  fi
  
  if [ ! -x "$GOST_BIN" ]; then
    warn "gost 文件不可执行，尝试添加执行权限..."
    chmod +x "$GOST_BIN"
  fi
}

# 检查配置文件
check_config() {
  if [ ! -f "$GOST_CONFIG" ]; then
    warn "配置文件不存在: $GOST_CONFIG"
    warn "将使用命令行参数方式运行"
    return 1
  fi
  return 0
}

# 检查 systemd 是否可用
check_systemd() {
  if ! command -v systemctl &> /dev/null; then
    error "systemd 不可用，无法创建系统服务"
    exit 1
  fi
}

# ============================================================================
# 服务管理功能
# ============================================================================

# 创建 systemd 服务
create_service() {
  require_root
  check_systemd
  check_gost_exists
  
  echo ""
  info "开始创建 gost systemd 服务..."
  
  # 确定启动命令
  local exec_start
  if check_config; then
    exec_start="${GOST_BIN} -C ${GOST_CONFIG}"
    info "使用配置文件: $GOST_CONFIG"
  else
    # 如果没有配置文件，提示用户输入启动参数
    echo ""
    warn "未找到配置文件，请输入 gost 启动参数"
    warn "示例: -L :8080 或 -L http2://:443"
    printf "请输入参数（直接回车使用 -L :8080）: "
    read -r gost_args
    
    if [ -z "$gost_args" ]; then
      gost_args="-L :8080"
    fi
    
    exec_start="${GOST_BIN} ${gost_args}"
    info "使用命令行参数: $gost_args"
  fi
  
  # 创建服务文件
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gost Proxy Service
Documentation=https://github.com/go-gost/gost
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${GOST_DIR}
ExecStart=${exec_start}
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

# 安全选项
NoNewPrivileges=true
PrivateTmp=true

# 日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gost

[Install]
WantedBy=multi-user.target
EOF
  
  info "服务文件已创建: $SERVICE_FILE"
  
  # 重载 systemd
  info "重载 systemd 配置..."
  systemctl daemon-reload
  
  echo ""
  info "✓ gost 服务创建成功！"
  echo ""
  info "可用命令:"
  echo "  启动服务: sudo systemctl start $SERVICE_NAME"
  echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
  echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
  echo "  查看状态: sudo systemctl status $SERVICE_NAME"
  echo "  开机自启: sudo systemctl enable $SERVICE_NAME"
  echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
  echo ""
  
  # 询问是否立即启动
  printf "是否立即启动服务？[Y/n]: "
  read -r answer
  
  case "${answer,,}" in
    n|no)
      info "已跳过启动"
      ;;
    *)
      info "正在启动服务..."
      systemctl start "$SERVICE_NAME"
      sleep 2
      
      if systemctl is-active --quiet "$SERVICE_NAME"; then
        info "✓ 服务启动成功！"
        systemctl status "$SERVICE_NAME" --no-pager
      else
        error "服务启动失败，请查看日志:"
        echo "  sudo journalctl -u $SERVICE_NAME -n 50"
      fi
      ;;
  esac
  
  # 询问是否开机自启
  printf "\n是否设置开机自启？[Y/n]: "
  read -r answer
  
  case "${answer,,}" in
    n|no)
      info "已跳过开机自启设置"
      ;;
    *)
      info "设置开机自启..."
      systemctl enable "$SERVICE_NAME"
      info "✓ 已设置开机自启"
      ;;
  esac
  
  echo ""
}

# 删除服务
remove_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    warn "服务文件不存在: $SERVICE_FILE"
    return
  fi
  
  echo ""
  info "准备删除 gost 服务..."
  
  # 停止服务
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "停止服务..."
    systemctl stop "$SERVICE_NAME"
  fi
  
  # 禁用开机自启
  if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    info "禁用开机自启..."
    systemctl disable "$SERVICE_NAME"
  fi
  
  # 删除服务文件
  info "删除服务文件..."
  rm -f "$SERVICE_FILE"
  
  # 重载 systemd
  systemctl daemon-reload
  
  echo ""
  info "✓ gost 服务已删除"
  echo ""
}

# 查看服务状态
show_status() {
  echo ""
  if [ -f "$SERVICE_FILE" ]; then
    info "服务配置文件: $SERVICE_FILE"
    systemctl status "$SERVICE_NAME" --no-pager || true
  else
    warn "gost 服务未安装"
    info "使用 '$0 --install' 创建服务"
  fi
  echo ""
}

# 查看日志
show_logs() {
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装"
    exit 1
  fi
  
  info "显示 gost 服务日志（Ctrl+C 退出）..."
  echo ""
  journalctl -u "$SERVICE_NAME" -f
}

# 启动服务
start_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装，请先运行: $0 --install"
    exit 1
  fi
  
  info "启动 gost 服务..."
  systemctl start "$SERVICE_NAME"
  sleep 1
  
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "✓ 服务启动成功"
    systemctl status "$SERVICE_NAME" --no-pager
  else
    error "服务启动失败"
    exit 1
  fi
}

# 停止服务
stop_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装"
    exit 1
  fi
  
  info "停止 gost 服务..."
  systemctl stop "$SERVICE_NAME"
  info "✓ 服务已停止"
}

# 重启服务
restart_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装"
    exit 1
  fi
  
  info "重启 gost 服务..."
  systemctl restart "$SERVICE_NAME"
  sleep 1
  
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "✓ 服务重启成功"
    systemctl status "$SERVICE_NAME" --no-pager
  else
    error "服务重启失败"
    exit 1
  fi
}

# 开机自启
enable_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装"
    exit 1
  fi
  
  info "设置开机自启..."
  systemctl enable "$SERVICE_NAME"
  info "✓ 已设置开机自启"
}

# 禁用开机自启
disable_service() {
  require_root
  
  if [ ! -f "$SERVICE_FILE" ]; then
    error "gost 服务未安装"
    exit 1
  fi
  
  info "禁用开机自启..."
  systemctl disable "$SERVICE_NAME"
  info "✓ 已禁用开机自启"
}

# ============================================================================
# 手动后台运行（备用方案）
# ============================================================================

# 使用 nohup 后台运行
run_background() {
  require_root
  check_gost_exists
  
  # 检查是否已经在运行
  if pgrep -f "$GOST_BIN" > /dev/null; then
    warn "gost 进程已在运行中"
    pgrep -af "$GOST_BIN"
    return
  fi
  
  local log_file="${GOST_DIR}/gost.log"
  
  echo ""
  info "使用 nohup 后台运行 gost..."
  
  if check_config; then
    nohup "$GOST_BIN" -C "$GOST_CONFIG" > "$log_file" 2>&1 &
    info "使用配置文件: $GOST_CONFIG"
  else
    warn "未找到配置文件，使用默认参数: -L :8080"
    nohup "$GOST_BIN" -L :8080 > "$log_file" 2>&1 &
  fi
  
  local pid=$!
  sleep 1
  
  if kill -0 "$pid" 2>/dev/null; then
    info "✓ gost 已在后台运行 (PID: $pid)"
    info "日志文件: $log_file"
    info "查看日志: tail -f $log_file"
    info "停止进程: kill $pid"
  else
    error "启动失败，请检查日志: $log_file"
  fi
  echo ""
}

# 停止后台进程
stop_background() {
  require_root
  
  local pids
  pids=$(pgrep -f "$GOST_BIN" || true)
  
  if [ -z "$pids" ]; then
    warn "未找到运行中的 gost 进程"
    return
  fi
  
  echo ""
  info "找到以下 gost 进程:"
  pgrep -af "$GOST_BIN"
  echo ""
  
  printf "确认停止这些进程？[y/N]: "
  read -r answer
  
  case "${answer,,}" in
    y|yes)
      info "停止进程..."
      pkill -f "$GOST_BIN"
      sleep 1
      
      if pgrep -f "$GOST_BIN" > /dev/null; then
        warn "进程未停止，尝试强制停止..."
        pkill -9 -f "$GOST_BIN"
      fi
      
      info "✓ 进程已停止"
      ;;
    *)
      info "已取消"
      ;;
  esac
  echo ""
}

# ============================================================================
# 帮助信息
# ============================================================================

print_help() {
  cat <<EOF
用法: $0 [选项]

Systemd 服务管理（推荐）:
  --install           创建并安装 gost systemd 服务
  --remove            删除 gost systemd 服务
  --start             启动 gost 服务
  --stop              停止 gost 服务
  --restart           重启 gost 服务
  --status            查看服务状态
  --enable            设置开机自启
  --disable           禁用开机自启
  --logs              查看服务日志（实时）

后台运行（备用方案）:
  --run-bg            使用 nohup 后台运行
  --stop-bg           停止后台运行的进程

其他:
  --help, -h          显示此帮助信息

配置信息:
  Gost 目录:   $GOST_DIR
  Gost 二进制: $GOST_BIN
  配置文件:    $GOST_CONFIG
  服务文件:    $SERVICE_FILE

示例:
  # 安装并启动服务（推荐）
  sudo $0 --install

  # 查看服务状态
  sudo $0 --status

  # 查看实时日志
  sudo $0 --logs

  # 重启服务
  sudo $0 --restart

EOF
}

# ============================================================================
# 主程序入口
# ============================================================================

main() {
  case "${1:---help}" in
    --install)
      create_service
      ;;
    --remove)
      remove_service
      ;;
    --start)
      start_service
      ;;
    --stop)
      stop_service
      ;;
    --restart)
      restart_service
      ;;
    --status)
      show_status
      ;;
    --enable)
      enable_service
      ;;
    --disable)
      disable_service
      ;;
    --logs)
      show_logs
      ;;
    --run-bg)
      run_background
      ;;
    --stop-bg)
      stop_background
      ;;
    --help|-h)
      print_help
      ;;
    *)
      error "未知选项: $1"
      echo ""
      echo "使用 '$0 --help' 查看帮助信息"
      exit 1
      ;;
  esac
}

main "$@"
