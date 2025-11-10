#!/usr/bin/env bash
set -euo pipefail

# main.sh - Linux 服务器优化脚本工具集
# 仓库: https://github.com/pylist/linux-sh
# 作者: pylist
# 许可: MIT

# ============================================================================
# 辅助函数
# ============================================================================

info() { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[0;33m[!]\033[0m %s\n" "$*"; }
error() { printf "\033[0;31m[✗]\033[0m %s\n" "$*" >&2; }

# 检查 BBR 状态
check_bbr_status() {
  local cur_cc
  cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
  echo "$cur_cc"
}

# 显示 BBR 状态（带格式）
show_bbr_status() {
  local status
  status=$(check_bbr_status)
  echo ""
  if [ "$status" = "bbr" ]; then
    info "BBR 状态: 已启用"
  else
    warn "BBR 状态: 未启用 (当前: $status)"
  fi
  echo ""
}

# 显示功能列表
print_features() {
  cat <<'EOF'

╔════════════════════════════════════════════════════════════╗
║           Linux 服务器优化脚本工具集                        ║
╚════════════════════════════════════════════════════════════╝

可用功能:

  1. 启用 TCP BBR 拥塞控制
     - 自动检测并启用 BBR
     - 加载内核模块并持久化配置
     - 验证配置是否生效

使用示例:

  # 交互式菜单
  ./main.sh

  # 查看功能列表
  ./main.sh --list

  # 启用 BBR
  sudo ./main.sh --enable-bbr

  # 远程执行
  curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | sudo bash -s -- --enable-bbr

EOF
}

# 显示帮助信息
print_help() {
  cat <<EOF
用法: $0 [选项]

选项:
  --list, -l        列出所有可用功能
  --enable-bbr, -b  启用 TCP BBR 拥塞控制
  --menu, -m        显示交互式菜单（默认）
  --help, -h        显示此帮助信息

示例:
  $0                      # 显示交互式菜单
  $0 --list               # 列出功能
  sudo $0 --enable-bbr    # 启用 BBR
  $0 --help               # 显示帮助

远程执行:
  curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh -o main.sh && chmod +x main.sh && ./main.sh

EOF
}

# 显示非交互提示
print_non_interactive_hint() {
  cat <<'EOF'

检测到非交互式环境（通过管道执行）

要使用交互式菜单，请下载后执行:
  curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh -o main.sh && chmod +x main.sh && ./main.sh

或直接执行功能:
  查看列表: curl ... | bash -s -- --list
  启用 BBR: curl ... | sudo bash -s -- --enable-bbr

EOF
  print_features
}

# ============================================================================
# BBR 启用功能
# ============================================================================

embed_bbr() {
  local tmp_script="/tmp/bbr_install_$$.sh"
  
  # 创建临时脚本
  cat > "$tmp_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

info() { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
warn() { printf "\033[0;33m[!]\033[0m %s\n" "$*"; }
error() { printf "\033[0;31m[✗]\033[0m %s\n" "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "需要 root 权限，请使用 sudo 运行"
  fi
}

apply_sysctl() {
  local key=$1 val=$2
  sysctl -w "$key=$val" >/dev/null 2>&1 || true
}

persist_bbr_conf() {
  cat > /etc/sysctl.d/99-bbr.conf <<'CONF'
# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
CONF
  sysctl --system >/dev/null 2>&1 || true
}

main() {
  require_root
  
  echo ""
  info "开始检查 BBR 状态..."
  
  local cur_cc
  cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "")
  
  if [ "$cur_cc" = "bbr" ]; then
    info "BBR 已启用，无需重复设置"
    echo ""
    return 0
  fi
  
  info "尝试加载 tcp_bbr 模块..."
  if lsmod | grep -q '^tcp_bbr'; then
    info "tcp_bbr 模块已加载"
  else
    if modprobe tcp_bbr 2>/dev/null; then
      info "成功加载 tcp_bbr 模块"
    else
      warn "无法加载模块，可能已内置或内核版本过低"
    fi
  fi
  
  info "应用运行时配置..."
  apply_sysctl net.core.default_qdisc fq
  apply_sysctl net.ipv4.tcp_congestion_control bbr
  
  info "持久化配置到 /etc/sysctl.d/99-bbr.conf..."
  persist_bbr_conf
  
  info "验证配置..."
  cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "")
  
  echo ""
  if [ "$cur_cc" = "bbr" ]; then
    info "✓ BBR 启用成功！"
  else
    warn "配置已应用，但当前值为: $cur_cc"
    warn "建议重启后再次检查"
  fi
  echo ""
}

main "$@"
EOF
  
  chmod +x "$tmp_script"
  
  # 执行并清理
  trap "rm -f '$tmp_script'" EXIT
  "$tmp_script"
}

# ============================================================================
# 交互式菜单
# ============================================================================

show_menu() {
  clear
  cat <<'MENU'
╔════════════════════════════════════════════════════════════╗
║              Linux 服务器优化工具菜单                       ║
╚════════════════════════════════════════════════════════════╝

  1) 启用 BBR 拥塞控制
  2) 检查 BBR 状态
  3) 列出所有功能
  4) 显示帮助信息
  0) 退出

╔════════════════════════════════════════════════════════════╗
MENU
  printf "请选择 [0-4]: "
}

run_interactive_menu() {
  while true; do
    show_menu
    read -r choice </dev/tty
    
    case "$choice" in
      1)
        echo ""
        info "准备启用 BBR..."
        embed_bbr
        read -rp "按回车键返回菜单..." _ </dev/tty
        ;;
      2)
        show_bbr_status
        read -rp "按回车键返回菜单..." _ </dev/tty
        ;;
      3)
        print_features
        read -rp "按回车键返回菜单..." _ </dev/tty
        ;;
      4)
        print_help
        read -rp "按回车键返回菜单..." _ </dev/tty
        ;;
      0)
        echo ""
        info "退出程序"
        echo ""
        exit 0
        ;;
      *)
        echo ""
        warn "无效选择: $choice"
        sleep 1
        ;;
    esac
  done
}

# ============================================================================
# 主程序入口
# ============================================================================


# ============================================================================
# 主程序入口
# ============================================================================

main() {
  case "${1:---menu}" in
    --list|-l)
      print_features
      ;;
    --enable-bbr|-b)
      embed_bbr
      ;;
    --help|-h)
      print_help
      ;;
    --menu|-m|"")
      # 检查是否为交互式终端
      if [ ! -t 0 ]; then
        print_non_interactive_hint
        exit 0
      fi
      run_interactive_menu
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