#!/bin/bash
set -e
set -o pipefail

# 创建 OpenClash 核心目录（若不存在则自动创建）
mkdir -p files/etc/openclash/core
mkdir -p files/etc/config

# 根据平台设置 core 架构
case "${platform:-}" in
    rockchip|rk3399|rk3568|rk3576|armv8)
        core="arm64"
        ;;
    x86_64)
        core="amd64"
        ;;
    *)
        echo "Unsupported platform: ${platform:-unset}, skip mihomo core preset."
        exit 0
        ;;
esac

# 内核类型，默认 meta
mihomo_core="${mihomo_core:-meta}"
case "$mihomo_core" in
    smart)
        SUBDIR="smart"
        ;;
    meta|*)
        SUBDIR="meta"
        ;;
esac

# 下载链接
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/${SUBDIR}/clash-linux-${core}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
MODEL_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/model.bin"
OPENCLASH_CONFIG_URL="https://github.com/grandway2025/default-settings/releases/download/settings/openclash"
NIKKI_CONFIG_URL="https://github.com/grandway2025/default-settings/releases/download/settings/nikki"
echo "platform=${platform:-unset}"
echo "core=${core}"
echo "mihomo_core=${mihomo_core}"
echo "SUBDIR=${SUBDIR}"
echo "CLASH_META_URL=${CLASH_META_URL}"
echo "MODEL_URL=${MODEL_URL}"
echo "OPENCLASH_CONFIG_URL=${OPENCLASH_CONFIG_URL}"
echo "NIKKI_CONFIG_URL=${NIKKI_CONFIG_URL}"

# 下载并解压 Clash Meta 内核，输出为 clash_meta 可执行文件
wget -qO- "${CLASH_META_URL}" | tar -xzO > files/etc/openclash/core/clash_meta

# 检查 Clash Meta 内核是否下载成功
if [ ! -s files/etc/openclash/core/clash_meta ]; then
    echo "Error: clash_meta download failed."
    exit 1
fi

# 下载 model.bin
wget -qO files/etc/openclash/model.bin "${MODEL_URL}"
# 下载 OpenClash 配置
wget -qO files/etc/config/openclash "${OPENCLASH_CONFIG_URL}"
# 下载 Nikki 配置
wget -qO files/etc/config/nikki "${NIKKI_CONFIG_URL}"
# 下载 GeoIP 数据库
wget -qO files/etc/openclash/GeoIP.dat "${GEOIP_URL}"
# 下载 GeoSite 数据库
wget -qO files/etc/openclash/GeoSite.dat "${GEOSITE_URL}"
# 检查 GeoIP / GeoSite 是否下载成功
if [ ! -s files/etc/openclash/GeoIP.dat ]; then
    echo "Error: GeoIP.dat download failed."
    exit 1
fi
if [ ! -s files/etc/openclash/GeoSite.dat ]; then
    echo "Error: GeoSite.dat download failed."
    exit 1
fi
# 检查 model.bin 是否下载成功
if [ ! -s files/etc/openclash/model.bin ]; then
    echo "Error: model.bin download failed."
    exit 1
fi
# 检查 openclash 配置是否下载成功
if [ ! -s files/etc/config/openclash ]; then
    echo "Error: openclash config download failed."
    exit 1
fi
# 检查 nikki 配置是否下载成功
if [ ! -s files/etc/config/nikki ]; then
    echo "Error: nikki config download failed."
    exit 1
fi
# 权限设置
chmod 0755 files/etc/openclash/core/clash_meta
chmod 0644 files/etc/openclash/model.bin
chmod 0644 files/etc/openclash/GeoIP.dat
chmod 0644 files/etc/openclash/GeoSite.dat
chmod 0644 files/etc/config/openclash
chmod 0644 files/etc/config/nikki
echo "mihomo core preset done."
ls -lh files/etc/openclash/core/clash_meta
ls -lh files/etc/openclash/model.bin
ls -lh files/etc/openclash/GeoIP.dat
ls -lh files/etc/openclash/GeoSite.dat
ls -lh files/etc/config/openclash
ls -lh files/etc/config/nikki
