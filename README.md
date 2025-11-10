# linux-sh: 常用 SSH 脚本集合

简介

- 本仓库收集常用的 SSH 相关小脚本与示例配置，方便远程登录、隧道、文件同步与链路保持。
- 目标：可即用、易读、易改。

先决条件

- 已安装 ssh、scp、rsync、autossh（若需链路保持）。
- 公钥/私钥对已生成，且公钥已部署到目标主机（或提供脚本帮助部署）。

目录（示例）

- bin/
  - ssh-connect.sh — 基于主机别名与用户快速连接脚本
  - ssh-copykey.sh — 自动化部署公钥到多台主机
  - ssh-tunnel.sh — 建立本地/远程端口转发
  - rsync-backup.sh — 使用 rsync 做远程备份
  - autossh-monitor.sh — 用 autossh 保持反向隧道
- examples/
  - ssh_config — 推荐的 ~/.ssh/config 配置示例
  - bastion.example — 通过堡垒机跳转的示例

快速开始（示例命令）

- 连接到主机：

```bash
./bin/ssh-connect.sh -h host.example.com -u deploy
```

- 一键部署公钥到多台主机：

```bash
./bin/ssh-copykey.sh hosts.txt ~/.ssh/id_rsa.pub
```

- 建立本地端口转发（本地 8080 -> 远端 80）：

```bash
./bin/ssh-tunnel.sh -L 8080:localhost:80 user@remote
```

- 使用 rsync 同步目录：

```bash
./bin/rsync-backup.sh /local/dir user@remote:/backup/dir
```

推荐 ~/.ssh/config（简化示例）

```ssh-config
Host bastion
    HostName bastion.example.com
    User jumpuser
    IdentityFile ~/.ssh/id_rsa

Host internal-*
    User deploy
    IdentityFile ~/.ssh/id_rsa_deploy
    ProxyJump bastion
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

安全建议

- 私钥设置合理权限：chmod 600 ~/.ssh/id_rsa
- 避免在脚本中明文保存密码或敏感信息
- 定期轮换密钥并控制 authorized_keys 权限

如何贡献

- 新增脚本请放入 bin/，附带可执行权限与简短说明头
- 提交前确保脚本在常见 Linux 发行版上可执行并有错误处理

许可证

- MIT（或项目指定的其他许可证），请在仓库根目录添加 LICENSE 文件。

快速启用 BBR 的脚本

使用方法：

1. 直接下载并运行（推荐使用 curl 或 wget）：

curl -fsSL https://your-server.example.com/bbr.sh -o bbr.sh && sudo bash bbr.sh

或者：

wget -qO- https://your-server.example.com/bbr.sh | sudo bash

2. 脚本会尝试：

- 检查 /proc/sys/net/ipv4/tcp_congestion_control
- 加载 tcp_bbr 模块（如果可用）
- 设置运行时 sysctl（net.core.default_qdisc=fq, net.ipv4.tcp_congestion_control=bbr）
- 将配置持久化到 /etc/sysctl.d/99-bbr.conf
- 验证当前设置并输出结果

注意事项：

- 该脚本需以 root 权限运行（sudo）。
- 如果内核版本过旧或编译时未包含 BBR 支持，脚本会提示并可能无法启用。
- 下载时请把示例 URL 替换为你自己的脚本托管地址，或者把 `bbr.sh` 复制到服务器后直接运行。

安全建议

- 私钥设置合理权限：chmod 600 ~/.ssh/id_rsa
- 避免在脚本中明文保存密码或敏感信息
- 定期轮换密钥并控制 authorized_keys 权限
