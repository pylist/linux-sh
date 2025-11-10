#!/usr/bin/env bash
set -euo pipefail

# main.sh - 项目单文件主入口
# 用法示例：
#   curl -fsSL https://your-server.example.com/main.sh | bash -s -- --list
#   curl -fsSL https://your-server.example.com/main.sh | sudo bash -s -- --enable-bbr

print_features(){
  cat <<'EOF'
此仓库提供以下脚本功能：

1) 启用 BBR (enable-bbr)
   - 检查当前系统是否已启用 BBR，若未启用会尝试加载 tcp_bbr 模块、设置运行时 sysctl、并持久化到 /etc/sysctl.d/99-bbr.conf。

命令行示例：
  列出功能：
    ./main.sh --list

  在服务器上直接启用 BBR：
    curl -fsSL https://your-server.example.com/main.sh | sudo bash -s -- --enable-bbr

EOF
}

embed_bbr(){
  # 将 bbr.sh 的必要实现内嵌在这里，简化为在目标机上写出 bbr.sh 并执行
  cat > /tmp/bbr.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
info(){ printf "[信息] %s\n" "$*" >&2; }
warn(){ printf "[警告] %s\n" "$*" >&2; }
err(){ printf "[错误] %s\n" "$*" >&2; exit 1; }
require_root(){ if [ "$(id -u)" -ne 0 ]; then err "脚本需以 root 身份运行，请使用 sudo 或以 root 运行。"; fi }
apply_sysctl(){ local key=$1 val=$2; sysctl -w "$key=$val" >/dev/null || true; }
persist_bbr_conf(){ cat >/etc/sysctl.d/99-bbr.conf <<'CONF'
# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
CONF
  sysctl --system >/dev/null || true
}
main(){
  require_root
  info "检查当前是否已启用 BBR..."
  local cur_cc
  cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)
  if [ "$cur_cc" = "bbr" ]; then
    info "检测到 BBR 已启用，跳过设置。当前 tcp_congestion_control=$cur_cc"
    exit 0
  fi

  if lsmod | grep -q '^tcp_bbr'; then
    info "tcp_bbr 模块已加载。"
  else
    if modprobe tcp_bbr 2>/dev/null; then
      info "已加载 tcp_bbr 模块。"
    else
      warn "加载 tcp_bbr 模块失败，可能已内置或内核过旧。"
    fi
  fi

  info "应用运行时 sysctl 设置..."
  apply_sysctl net.core.default_qdisc fq
  apply_sysctl net.ipv4.tcp_congestion_control bbr
  info "将配置写入 /etc/sysctl.d/99-bbr.conf 并生效"
  persist_bbr_conf

  info "验证 BBR 是否启用..."
  cur_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)
  if [ "$cur_cc" = "bbr" ]; then
    info "成功：TCP 拥塞控制已设置为 bbr。"
  else
    warn "当前 TCP 拥塞控制为 '$cur_cc'（期望 'bbr'）。"
  fi

  if lsmod | grep -q '^tcp_bbr'; then
    info "tcp_bbr 模块已加载。"
  else
    warn "lsmod 中未列出 tcp_bbr 模块，可能已内置或未加载。"
  fi
  info "完成。若模块未能加载，请考虑重启后重试。"
}
main "$@"
EOF
  chmod +x /tmp/bbr.sh
  /tmp/bbr.sh
}

case "${1:---menu}" in
  --list|-l)
    print_features
    ;;
  --enable-bbr|-b)
    embed_bbr "$@"
    ;;
  --menu|-m|"")
    # 简化交互式菜单：仅列出已实现的功能
    bbr_status(){
      local cur
      cur=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)
      if [ "$cur" = "bbr" ]; then
        echo "当前 BBR 状态: 已启用 (tcp_congestion_control=$cur)"
      else
        echo "当前 BBR 状态: 未启用 (tcp_congestion_control=$cur)"
      fi
    }

    while true; do
      clear
      cat <<'MENU'
---------------- 服务器工具菜单 ----------------
可用功能 (仅列出已实现项)：

1) 启用 BBR
2) 检查 BBR 状态
3) 列出功能
4) 帮助
0) 退出

请选择 [0-4]:
MENU
      read -r choice
      case "$choice" in
        1)
          echo "准备启用 BBR..."
          embed_bbr
          read -rp "按回车返回..." _
          ;;
        2)
          bbr_status
          read -rp "按回车返回..." _
          ;;
        3)
          print_features
          read -rp "按回车返回..." _
          ;;
        4)
          echo "帮助：可通过 --list 查看功能，或使用 --enable-bbr 非交互启用 BBR。"
          read -rp "按回车返回..." _
          ;;
        0)
          exit 0
          ;;
        *)
          echo "无效选择: $choice"
          read -rp "按回车返回..." _
          ;;
      esac
    done
    ;;
  --help|-h)
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --list, -l        列出所有可用功能"
    echo "  --enable-bbr, -b  启用 TCP BBR 拥塞控制"
    echo "  --menu, -m        显示交互式菜单"
    echo "  --help, -h        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --list"
    echo "  sudo $0 --enable-bbr"
    echo "  curl -fsSL https://your-server.example.com/main.sh | sudo bash -s -- --enable-bbr"
    ;;
  *)
    echo "用法: $0 --list | --enable-bbr | --menu | --help"
    echo "传入 --help 查看详细帮助信息。"
    exit 1
    ;;
esac
