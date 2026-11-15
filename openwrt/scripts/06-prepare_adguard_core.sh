#!/bin/bash
set -e

# 创建 AdGuardHome 目录
mkdir -p files/usr/bin
mkdir -p files/etc/adguardhome

# 根据平台设置 AdGuardHome 架构
case "${platform:-}" in
    rockchip|rk3399|rk3568|rk3576|armv8)
        core="arm64"
        ;;
    x86_64)
        core="amd64"
        ;;
    *)
        echo "Unsupported platform: ${platform:-unset}, skip AdGuardHome core preset."
        exit 0
        ;;
esac
# AdGuardHome 下载链接
ADGUARDHOME_URL="https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_${core}.tar.gz"
# AdGuardHome.yaml 下载链接
YAML_URL="https://github.com/grandway2025/default-settings/releases/download/settings/AdGuardHome.yaml"
echo "platform=${platform:-unset}"
echo "core=${core}"
echo "ADGUARDHOME_URL=${ADGUARDHOME_URL}"
echo "YAML_URL=${YAML_URL}"
# 下载并解压 AdGuardHome
wget -qO- "${ADGUARDHOME_URL}" | tar xOz ./AdGuardHome/AdGuardHome > files/usr/bin/AdGuardHome
# 下载 AdGuardHome.yaml
wget -qO files/etc/adguardhome/adguardhome.yaml "${YAML_URL}"
# 检查是否下载成功
if [ ! -s files/usr/bin/AdGuardHome ]; then
    echo "Error: AdGuardHome core download failed."
    exit 1
fi
# 检查 AdGuardHome.yaml 是否下载成功
if [ ! -s files/etc/adguardhome/adguardhome.yaml ]; then
  echo "Error: AdGuardHome.yaml download failed."
  exit 1
fi
# 赋予执行权限
chmod +x files/usr/bin/AdGuardHome
echo "AdGuardHome core preset done."
ls -lh files/etc/adguardhome/adguardhome.yaml
ls -lh files/usr/bin/AdGuardHome
