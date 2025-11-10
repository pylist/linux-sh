# linux-sh: Linux 服务器优化脚本工具集

## 📖 简介

本仓库提供一系列 Linux 服务器优化与配置脚本，旨在简化常见的系统优化任务。

- **目标**：一键执行、易于使用、安全可靠
- **特性**：交互式菜单、远程执行支持、错误处理完善

## 🚀 一键运行

### 方式一：交互式菜单（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | bash
```

或使用 wget：

```bash
wget -qO- https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | bash
```

### 方式二：直接启用 BBR

```bash
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | sudo bash -s -- --enable-bbr
```

或单独使用 BBR 脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/bbr.sh | sudo bash
```

## 📁 项目结构

```
.
├── main.sh    # 主入口脚本（支持交互式菜单和命令行参数）
├── bbr.sh     # BBR 启用脚本（可独立使用）
└── README.md  # 项目文档
```

## 📋 可用功能

### 1. 启用 TCP BBR 拥塞控制

TCP BBR (Bottleneck Bandwidth and RTT) 是 Google 开发的拥塞控制算法，可以显著提升网络性能。

**功能说明：**

- 自动检测当前 BBR 状态
- 加载 `tcp_bbr` 内核模块
- 配置系统参数并持久化
- 验证配置是否生效

**使用方法：**

```bash
# 命令行方式
sudo ./main.sh --enable-bbr

# 或使用独立脚本
sudo ./bbr.sh

# 远程一键执行
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/bbr.sh | sudo bash
```

## 🎯 使用指南

### 本地使用

1. **克隆仓库**

```bash
git clone https://github.com/pylist/linux-sh.git
cd linux-sh
```

2. **赋予执行权限**

```bash
chmod +x main.sh bbr.sh
```

3. **运行主脚本**

```bash
# 显示交互式菜单（默认）
./main.sh

# 列出所有功能
./main.sh --list

# 启用 BBR
sudo ./main.sh --enable-bbr

# 显示帮助信息
./main.sh --help
```

### 远程使用

无需克隆仓库，直接通过 curl 或 wget 执行：

```bash
# 交互式菜单
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | bash

# 直接启用 BBR
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | sudo bash -s -- --enable-bbr

# 查看功能列表
curl -fsSL https://raw.githubusercontent.com/pylist/linux-sh/main/main.sh | bash -s -- --list
```

## 💡 命令行选项

```
用法: ./main.sh [选项]

选项:
  --list, -l        列出所有可用功能
  --enable-bbr, -b  启用 TCP BBR 拥塞控制
  --menu, -m        显示交互式菜单（默认）
  --help, -h        显示帮助信息

示例:
  ./main.sh                    # 显示交互式菜单
  ./main.sh --list             # 列出功能
  sudo ./main.sh --enable-bbr  # 启用 BBR
```

## ⚙️ 系统要求

- **操作系统**：Linux (内核 4.9+)
- **权限**：BBR 功能需要 root 权限
- **工具**：bash, sysctl, modprobe

## ⚠️ 注意事项

### BBR 启用脚本

- 需要 root 权限运行（使用 `sudo`）
- 内核版本需 4.9 或更高才支持 BBR
- 部分云服务器可能已内置 BBR 支持
- 配置会持久化到 `/etc/sysctl.d/99-bbr.conf`
- 大多数情况下无需重启即可生效

### 安全建议

- 仅从可信源下载并执行脚本
- 执行前可先下载查看脚本内容
- 建议在测试环境先验证功能
- - 定期检查系统配置文件

## 🔍 验证 BBR 是否启用

运行以下命令检查 BBR 状态：

```bash
# 检查拥塞控制算法
sysctl net.ipv4.tcp_congestion_control

# 检查可用的拥塞控制算法
sysctl net.ipv4.tcp_available_congestion_control

# 检查 BBR 模块是否加载
lsmod | grep bbr
```

预期输出：

```
net.ipv4.tcp_congestion_control = bbr
```

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

- 新增脚本请确保有完善的错误处理
- 提交前在常见 Linux 发行版上测试
- 代码风格保持一致，添加必要的注释
- 更新相关文档说明

## 📄 许可证

MIT License

## 🔗 相关链接

- [BBR 官方论文](https://queue.acm.org/detail.cfm?id=3022184)
- [Linux 内核 BBR 文档](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/networking/tcp-bbr.txt)

---

**注意**：请将示例中的 `pylist/linux-sh` 替换为你的实际 GitHub 用户名和仓库名。
