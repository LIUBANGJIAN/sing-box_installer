#!/bin/bash

# --- 1. 权限检查：确保使用 root 权限运行 ---
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以 root 权限运行此脚本，或使用 sudo ./install.sh"
  exit 1
fi

# --- 2. 获取并设置主机名/etc/hostname为外网 IP ---
echo "--- 1/5 正在获取外网 IP 并设置为主机名 ---"

# 获取 IP -> 设置当前主机名 -> 写入 /etc/hostname
curl -s https://api-ipv4.ip.sb/ip | xargs -I {} sh -c '
    /bin/hostname "{}" 
    echo "{}" | tee /etc/hostname > /dev/null
    echo "检测到外网 IP 并设置为主机名: {}"
'

if [ $? -ne 0 ]; then
    echo "错误：设置主机名失败，请检查网络连接或权限。"
    exit 1
fi

echo "当前主机名已设置为: $(hostname)"

# --- 3. 下载所需文件并设置权限 (已优化为链式单行逻辑) ---
echo "--- 2/5 正在下载 sing-box.sh 和 config.conf，并设置权限 ---"

# 定义不同的下载地址
SINGBOX_URL="https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh"
CONFIG_URL="https://alist.lbj3.top:8443/d/m3u8/config.conf"

# 将两个文件的下载和 sing-box.sh 的权限设置合并到一行，只有前一个成功，后一个才会执行
curl -L -s -o sing-box.sh "${SINGBOX_URL}" && \
curl -L -s -o config.conf "${CONFIG_URL}" && \
chmod +x sing-box.sh

if [ ! -f "sing-box.sh" ] || [ ! -f "config.conf" ]; then
    echo "错误：文件下载失败，请检查网络连接或下载地址是否正确。"
    exit 1
fi

# --- 4. 修复 sing-box.sh 内部的下载代理 (解决 cp: can't stat 错误) ---
echo "--- 3/5 正在替换 sing-box.sh 脚本中的 GitHub 代理 ---"
# 将 GH_PROXY 变量替换为空字符串，即使用官方直连下载
sed -i "s/^GH_PROXY=.*$/GH_PROXY=''/g" sing-box.sh
echo "GH_PROXY 已设置为直连 GitHub，以修复下载问题。"


# --- 5. 检查并确保 config.conf 满足自动配置条件 (修复 sed 语法) ---
echo "--- 4/5 正在检查 config.conf 自动配置字段 ---"
# 强制将配置项设置为空，启用自动配置
sed -i "s/^UUID_CONFIRM=.*$/UUID_CONFIRM=''/g" config.conf
sed -i "s/^SERVER_IP=.*$/SERVER_IP=''/g" config.conf

if ! grep -q '^NODE_NAME_CONFIRM=' config.conf; then
    echo "NODE_NAME_CONFIRM=''" >> config.conf
else
    sed -i "s/^NODE_NAME_CONFIRM=.*$/NODE_NAME_CONFIRM=''/g" config.conf
fi
echo "UUID_CONFIRM, SERVER_IP, NODE_NAME_CONFIRM 均已强制设置为空，启用自动配置。"


# --- 6. 运行 sing-box 全自动安装 ---
echo "--- 5/5 正在启动 sing-box 全自动安装 (非交互模式) ---"
# 使用 yes "" 通过管道模拟用户不断按下回车
yes "" | bash ./sing-box.sh -f ./config.conf

# 检查安装结果
if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "--- sing-box 自动安装流程已成功完成 (全程无需人工参与) ---"
    echo "--------------------------------------------------------"
else
    echo "--------------------------------------------------------"
    echo "--- 警告：sing-box 自动安装流程可能遇到错误，请检查上面的输出 ---"
    echo "--------------------------------------------------------"
fi