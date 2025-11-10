#!/usr/bin/env bash
set -euo pipefail

# bbr.sh - 快速在 Linux 上启用 TCP BBR
# 用法: curl -fsSL https://.../bbr.sh | bash

info(){ printf "[信息] %s\n" "$*" >&2; }
warn(){ printf "[警告] %s\n" "$*" >&2; }
err(){ printf "[错误] %s\n" "$*" >&2; exit 1; }

require_root(){
  if [ "$(id -u)" -ne 0 ]; then
    err "脚本需以 root 身份运行，请使用 sudo 或以 root 运行。"
  fi
}

check_command(){
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

apply_sysctl(){
  local key=$1 val=$2
  sysctl -w "$key=$val" >/dev/null || true
}

persist_bbr_conf(){
  cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
  sysctl --system >/dev/null || true
}

main(){
  require_root

  # check for kernel module and ability
  info "检查系统环境..."
  if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    info "内核支持修改拥塞控制算法。"
  else
    warn "/proc/sys/net/ipv4/tcp_congestion_control 不存在。内核可能过旧或非 Linux。"
  fi

  # Try to load tcp_bbr module
  if lsmod | grep -q '^tcp_bbr'; then
    info "tcp_bbr 模块已加载。"
  else
    if modprobe tcp_bbr 2>/dev/null; then
      info "已加载 tcp_bbr 模块。"
    else
      warn "加载 tcp_bbr 模块失败，可能已内置或内核过旧。"
    fi
  fi

  # Set runtime sysctls
  info "应用运行时 sysctl 设置..."
  apply_sysctl net.core.default_qdisc fq
  apply_sysctl net.ipv4.tcp_congestion_control bbr

  # Persist
  info "将配置写入 /etc/sysctl.d/99-bbr.conf 并生效"
  persist_bbr_conf

  # Verify
  info "验证 BBR 是否启用..."
  local cur_cc
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

  info "完成。大多数情况下无需重启；若模块未能加载，请考虑重启后重试。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
