#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Generate OpenWrt release markdown info
# Output:
#   /builder/info/info.md
#   /builder/info/summary.md
# ============================================================

INFO_DIR="${INFO_DIR:-/builder/info}"

mkdir -p "${INFO_DIR}"

INFO_MD="${INFO_DIR}/info.md"
SUMMARY_MD="${INFO_DIR}/summary.md"

OPENWRT_VERSION="${OPENWRT_VERSION:-OpenWrt}"
BUILD_TIME="${BUILD_TIME:-$(date -u '+%Y-%m-%d %H:%M:%S UTC')}"
DEVICE="${DEVICE:-unknown}"
KERNEL_VERSION="${KERNEL_VERSION:-unknown}"
GCC_VERSION="${GCC_VERSION:-unknown}"
WEB_SERVER="${WEB_SERVER:-unknown}"
MIHOMO_CORE="${MIHOMO_CORE:-unknown}"
LAN_ADDR="${LAN_ADDR:-192.168.1.1}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
BUILD_OPTIONS="${BUILD_OPTIONS:-}"
LAN_GATEWAY="${LAN_GATEWAY:-$(echo "${BUILD_OPTIONS}" | sed -nE 's/(^|.*[[:space:]])LAN_GATEWAY=([^[:space:]]+).*/\2/p')}"
LAN_DNS="${LAN_DNS:-$(echo "${BUILD_OPTIONS}" | sed -nE 's/(^|.*[[:space:]])LAN_DNS=([^[:space:]]+).*/\2/p')}"
LAN_GATEWAY="${LAN_GATEWAY:-192.168.1.1}"
LAN_DNS="${LAN_DNS:-192.168.1.1}"
RELEASE_TITLE="${RELEASE_TITLE:-OpenWrt 固件发布}"
CONFIG_FILE="${CONFIG_FILE:-}"

# 插件列表。
# 格式支持：
#   PLUGINS="Docker=true PassWall=true OpenClash=false"
# 或：
#   PLUGINS="Docker PassWall OpenClash Mihomo_Nikki MosDNS OpenAppFilter UPnP TTYD Argon"
#
# 默认使用 auto，避免未检测时误显示“已编译”。
PLUGINS="${PLUGINS:-Docker=auto PassWall=auto OpenClash=auto Mihomo_Nikki=auto MosDNS=auto OpenAppFilter=auto UPnP=auto adguardhome=auto TTYD终端=auto Argon主题=auto}"

escape_md() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  echo "${value}"
}

format_compile_status() {
  local value="${1:-}"

  case "${value}" in
    true|TRUE|yes|YES|y|Y|1|enable|enabled|ENABLE|ENABLED|on|ON)
      echo "✅ 已编译"
      ;;
    false|FALSE|no|NO|n|N|0|disable|disabled|DISABLE|DISABLED|off|OFF)
      echo "❌ 未编译"
      ;;
    auto|AUTO|"")
      echo "🔍 自动检测"
      ;;
    *)
      echo "${value}"
      ;;
  esac
}

format_root_password() {
  local value="${1:-}"

  if [[ -z "${value}" ]]; then
    echo "无密码"
  else
    echo "已设置"
  fi
}

format_gcc() {
  local value="${1:-}"

  case "${value}" in
    GCC16|gcc16|16)
      echo "GCC 16"
      ;;
    GCC15|gcc15|15)
      echo "GCC 15"
      ;;
    GCC14|gcc14|14)
      echo "GCC 14"
      ;;
    *)
      echo "${value}"
      ;;
  esac
}

format_kernel() {
  local value="${1:-}"

  if [[ -z "${value}" ]]; then
    echo "unknown"
  else
    echo "${value}"
  fi
}

# 去掉编译时间结尾的时区缩写（如 CST、UTC、GMT 等），只保留日期时间
format_build_time() {
  local value="${1:-}"
  # 去除结尾的 " XXX"（一个或多个字母组成的时区缩写）及其前置空白
  value="$(echo "${value}" | sed -E 's/[[:space:]]+[A-Za-z]{2,5}$//')"
  echo "${value}"
}

render_plugins_table() {
  echo "| 插件 | 状态 |"
  echo "|---|---|"
  local item name value display_name plugin_count
  plugin_count=0
  # shellcheck disable=SC2206
  local plugins_array=(${PLUGINS})
  for item in "${plugins_array[@]}"; do
    if [[ "${item}" == *"="* ]]; then
      name="${item%%=*}"
      value="${item#*=}"
    else
      name="${item}"
      value="true"
    fi
    case "${value}" in
      true|TRUE|yes|YES|y|Y|1|enable|enabled|ENABLE|ENABLED|on|ON)
        display_name="${name//_/ }"
        echo "| $(escape_md "${display_name}") | ✅ 已编译 |"
        plugin_count=$((plugin_count + 1))
        ;;
    esac
  done
  if [[ "${plugin_count}" -eq 0 ]]; then
    echo "| 无 | 未检测到已编译插件 |"
  fi
}

GCC_DISPLAY="$(format_gcc "${GCC_VERSION}")"
KERNEL_DISPLAY="$(format_kernel "${KERNEL_VERSION}")"
ROOT_PASSWORD_DISPLAY="$(format_root_password "${ROOT_PASSWORD}")"
BUILD_TIME_DISPLAY="$(format_build_time "${BUILD_TIME}")"

{
  echo "# 🎉 ${RELEASE_TITLE}"
  echo
  echo "> 请确认固件与设备型号匹配后再刷机，刷机有风险，操作需谨慎!"
  echo
  echo "---"
  echo
  echo "## 📊 构建信息"
  echo
  echo "| 项目 | 值 |"
  echo "|---|---|"
  echo "| 🏷️ 版本 | \`${OPENWRT_VERSION}\` |"
  echo "| 📅 编译时间 | \`${BUILD_TIME_DISPLAY}\` |"
  echo "| 🎯 目标设备 | \`${DEVICE}\` |"
  echo "| 🐧 内核版本 | \`${KERNEL_DISPLAY}\` |"
  echo "| 🛠️ GCC 版本 | \`${GCC_DISPLAY}\` |"
  echo "| 🌐 Web 服务 | \`${WEB_SERVER}\` |"
  echo "| 🐱 Mihomo 内核 | \`${MIHOMO_CORE}\` |"
  echo "| 🌍 默认 LAN | \`${LAN_ADDR}\` |"
  echo "| 🚪 LAN 网关 | \`${LAN_GATEWAY}\` |"
  echo "| 🧭 LAN DNS | \`${LAN_DNS}\` |"
  echo "| 🔑 默认密码 | \`${ROOT_PASSWORD_DISPLAY}\` |"

  if [[ -n "${CONFIG_FILE}" ]]; then
    echo "| ⚙️ 配置文件 | \`${CONFIG_FILE}\` |"
  fi

  echo
  echo "---"
  echo
  echo "## ⚙️ 构建选项"
  echo

  if [[ -n "${BUILD_OPTIONS}" ]]; then
    echo '```text'
    echo "${BUILD_OPTIONS}"
    echo '```'
  else
    echo "> 未提供额外构建选项。"
  fi

  echo
  echo "---"
  echo
  echo "## 📦 已编译插件"
  echo
  render_plugins_table
} > "${INFO_MD}"

{
  echo "## 🎉 OpenWrt 构建完成"
  echo
  echo "| 项目 | 值 |"
  echo "|---|---|"
  echo "| 版本 | \`${OPENWRT_VERSION}\` |"
  echo "| 设备 | \`${DEVICE}\` |"
  echo "| 内核 | \`${KERNEL_DISPLAY}\` |"
  echo "| GCC | \`${GCC_DISPLAY}\` |"
  echo "| Web 服务 | \`${WEB_SERVER}\` |"
  echo "| Mihomo | \`${MIHOMO_CORE}\` |"
  echo "| LAN | \`${LAN_ADDR}\` |"
  echo "| LAN 网关 | \`${LAN_GATEWAY}\` |"
  echo "| LAN DNS | \`${LAN_DNS}\` |"
  echo
  echo "### 构建选项"
  echo

  if [[ -n "${BUILD_OPTIONS}" ]]; then
    echo '```text'
    echo "${BUILD_OPTIONS}"
    echo '```'
  else
    echo "> 未提供额外构建选项。"
  fi

  echo
  echo "### 已编译插件"
  echo
  render_plugins_table
} > "${SUMMARY_MD}"

echo "Generated release info:"
echo "  ${INFO_MD}"
echo "  ${SUMMARY_MD}"
