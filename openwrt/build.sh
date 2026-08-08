#!/bin/bash -e
#####################################
#  NanoPi R4S OpenWrt Build Script  #
#####################################

export RED_COLOR='\e[1;31m' GREEN_COLOR='\e[1;32m' YELLOW_COLOR='\e[1;33m' \
       BLUE_COLOR='\e[1;34m' PINK_COLOR='\e[1;35m' SHAN='\e[1;33;5m' RES='\e[0m'

########## helpers ##########
[ "$(whoami)" = "runner" ] && IS_RUNNER=1 || IS_RUNNER=
[ "$(whoami)" = "sbwml" ]  && IS_SBWML=1  || IS_SBWML=
GROUP=

endgroup() { [ -n "$GROUP" ] && echo "::endgroup::"; GROUP=; }
group() {
    endgroup
    if [ -n "$IS_RUNNER" ]; then echo "::group::  $1"; GROUP=1; fi
}

add_cfg()     { printf '%s\n' "$@" >> .config; }          # 追加配置行
add_cfg_url() { curl -s "$1" >> .config; }                # 远程配置追加
copy_pkgs()   { local f; for f in "$@"; do cp -a $f "$kmodpkg_name/" 2>/dev/null || true; done; }
fmt_time()    { printf '%dh,%dm,%ds' $(($1/3600)) $((($1%3600)/60)) $(($1%60)); }

print_status() {   # name value [false_color] [tail]
    local n=$1 v=$2 fc=${3:-$YELLOW_COLOR} tl=${4:-}
    [ "$v" = "y" ] && echo -e "${GREEN_COLOR}${n}:${RES} ${GREEN_COLOR}true${RES}${tl}" \
                   || echo -e "${GREEN_COLOR}${n}:${RES} ${fc}false${RES}${tl}"
}

########## auth check ##########
if [ "$(whoami)" != "sbwml" ] && [ -z "$git_name" ] && [ -z "$git_password" ]; then
    echo -e "\n${RED_COLOR} Not authorized. Execute the following command to provide authorization information:${RES}\n"
    echo -e "${BLUE_COLOR} export git_name=your_username git_password=your_password${RES}\n"
    exit 1
fi

########## env ##########
ip_info=$(curl -sk https://ip.cooluc.com || true)
export isCN=$(echo "$ip_info" | grep -Po 'country_code":"\K[^"]+' || echo US)
[ -n "$isCN" ] || export isCN=US

export mirror=https://init.cooluc.com
[ -n "$IS_RUNNER" ] && [ "$git_name" != "private" ] && export mirror=http://127.0.0.1:8080
export gitea="git.cooluc.com"
export github="github.com"
[ "$isCN" = "CN" ] && code_mirror="git.cooluc.com" || code_mirror="github.com"

[ "$(id -u)" = "0" ] && export FORCE_UNSAFE_CONFIGURE=1 FORCE=1

CURRENT_DATE=$(date +%s)
cores=$(( $(nproc) + 1 ))
curl --help 2>/dev/null | grep -q progress-bar && CURL_BAR="--progress-bar" || CURL_BAR=

########## args ##########
SUPPORTED_BOARDS="nanopi-r4s nanopi-r5s nanopi-r76s x86_64 armv8"
usage() {
    echo -e "\n${RED_COLOR}Building type not specified or unsupported board: '$2'.${RES}\n"
    echo -e "Usage:\n"
    for b in $SUPPORTED_BOARDS; do
        echo -e "$b releases: ${GREEN_COLOR}bash build.sh rc2 $b${RES}"
        echo -e "$b snapshots: ${GREEN_COLOR}bash build.sh dev $b${RES}"
    done
    echo; exit 1
}
case "$1" in dev|rc2) ;; *) usage "$@" ;; esac
case " $SUPPORTED_BOARDS " in *" $2 "*) ;; *) usage "$@" ;; esac

if [ "$1" = "dev" ]; then
    export branch=openwrt-25.12 version=dev
else
    export branch="v$(curl -s $mirror/tags/v25)" version=rc2
fi

########## defaults ##########
export LAN="${LAN:-192.168.1.10}"
export LAN_ADDR="${LAN_ADDR:-$LAN}"
export LAN_GATEWAY="${LAN_GATEWAY:-192.168.1.1}"
export LAN_DNS="${LAN_DNS:-192.168.1.1}"
export mihomo_core="${mihomo_core:-meta}"

########## platform table ##########
case "$2" in
    x86_64)      platform=x86_64; model=x86_64;      model_name="x86_64"       ;;
    armv8)       platform=armv8;  model=armv8;       model_name="armsr/armv8"  ;;
    nanopi-r4s)  platform=rk3399; model=nanopi-r4s;  model_name="nanopi-r4s"   ;;
    nanopi-r5s)  platform=rk3568; model=nanopi-r5s;  model_name="nanopi-r5s/r5c" ;;
    nanopi-r76s) platform=rk3576; model=nanopi-r76s; model_name="nanopi-r76s"  ;;
esac
[ "$platform" = "x86_64" ] && toolchain_arch=x86_64 || toolchain_arch=aarch64_generic
export platform toolchain_arch

########## gcc ##########
gcc_version=15
for v in 13 14 15 16; do
    var="USE_GCC$v"
    [ "${!var}" = "y" ] && { gcc_version=$v; break; }
done
export "USE_GCC${gcc_version}=y" gcc_version
[ "$ENABLE_MOLD" = "y" ] && export ENABLE_MOLD=y

export ENABLE_BPF ENABLE_DPDK ENABLE_GLIBC ENABLE_LRNG ENABLE_LTO \
       KERNEL_CLANG_LTO ROOT_PASSWORD

[ "$ENABLE_GLIBC" = "y" ] && LIBC=glibc || LIBC=musl
if   [ "$MINIMAL_BUILD" = "y" ]; then channel=minimal
elif [ "$STD_BUILD"     = "y" ]; then channel=standard
else                                  channel=release; fi

########## banner ##########
echo -e "\r\n${GREEN_COLOR}Building $branch${RES}\r\n"
echo -e "${GREEN_COLOR}Model: ${model_name}${RES}"

# kmod 版本（注意: md5 必须包含结尾换行, 与原脚本保持一致）
kmod_ver=$(curl -s "$mirror/tags/kernel-6.18" | awk -F'HASH-' 'NF>1{print $2}' | awk '{print $1}' | tail -1)
kmodpkg_name="${kmod_ver}~$(printf '%s\n' "$kmod_ver" | md5sum | awk '{print $1}')-r1"

echo -e "${GREEN_COLOR}Kernel: $kmodpkg_name ${RES}"
echo -e "${GREEN_COLOR}Date: $CURRENT_DATE${RES}\r\n"
echo -e "${GREEN_COLOR}SCRIPT_URL:${RES} ${BLUE_COLOR}$mirror${RES}\r\n"
echo -e "${GREEN_COLOR}GCC VERSION: $gcc_version${RES}"
echo -e "${GREEN_COLOR}LAN:${RES} $LAN"
echo -e "${GREEN_COLOR}LAN_GATEWAY:${RES} $LAN_GATEWAY"
echo -e "${GREEN_COLOR}LAN_DNS:${RES} $LAN_DNS"
[ -n "$ROOT_PASSWORD" ] \
    && echo -e "${GREEN_COLOR}Default Password:${RES} ${BLUE_COLOR}$ROOT_PASSWORD${RES}" \
    || echo -e "${GREEN_COLOR}Default Password:${RES} (${YELLOW_COLOR}No password${RES})"
echo -e "${GREEN_COLOR}Standard C Library:${RES} ${BLUE_COLOR}${LIBC}${RES}"
print_status "ENABLE_OTA"        "$ENABLE_OTA"
print_status "ENABLE_DPDK"       "$ENABLE_DPDK"
print_status "ENABLE_MOLD"       "$ENABLE_MOLD"
print_status "ENABLE_BPF"        "$ENABLE_BPF"  "$RED_COLOR"
print_status "ENABLE_LTO"        "$ENABLE_LTO"  "$RED_COLOR"
print_status "ENABLE_LRNG"       "$ENABLE_LRNG" "$RED_COLOR"
print_status "ENABLE_LOCAL_KMOD" "$ENABLE_LOCAL_KMOD"
print_status "BUILD_FAST"        "$BUILD_FAST"
print_status "ENABLE_CCACHE"     "$ENABLE_CCACHE"
print_status "MINIMAL_BUILD"     "$MINIMAL_BUILD"
print_status "STD_BUILD"         "$STD_BUILD"
print_status "ENABLE_ISTORE"     "$ENABLE_ISTORE"
print_status "KERNEL_CLANG_LTO"  "$KERNEL_CLANG_LTO" "$YELLOW_COLOR" "\n"

########## source ##########
rm -rf openwrt
group "source code"
git clone --depth=1 "https://$code_mirror/openwrt/openwrt" -b "$branch" || {
    echo -e "${RED_COLOR}Failed to download source code${RES}"; exit 1; }
endgroup

cd openwrt
curl -Os $mirror/openwrt/patch/key2.tar.gz && tar zxf key2.tar.gz && rm -f key2.tar.gz

# tags
if [ "$version" = "rc2" ]; then
    git describe --abbrev=0 --tags > version.txt
else
    git branch | awk '{print $2}' > version.txt
fi

# feeds
: > feeds.conf
for feed in packages luci routing telephony; do
    if [ "$version" = "rc2" ]; then
        rev="^$(grep -m1 "src-git $feed " feeds.conf.default | awk -F^ '{print $2}')"
    else
        rev=";$branch"
    fi
    echo "src-git $feed https://$code_mirror/openwrt/${feed}.git${rev}" >> feeds.conf
done

group "feeds update -a";  ./scripts/feeds update -a;  endgroup
group "feeds install -a"; ./scripts/feeds install -a; endgroup

[ -f ../dl.gz ] && tar xf ../dl.gz -C .

########## patch ##########
echo -e "\n${GREEN_COLOR}Patching ...${RES}\n"
scripts=(00-prepare_base.sh 01-prepare_base-mainline.sh 02-prepare_package.sh
         03-convert_translation.sh 04-fix_kmod.sh 05-fix-source.sh
         06-prepare_adguard_core.sh 07-preset_mihomo_core.sh 99_clean_build_cache.sh)
curl -fsSL --remote-name-all "${scripts[@]/#/$mirror/openwrt/scripts/}"

if [ -n "$git_password" ] && [ -n "$private_url" ]; then
    curl -u "openwrt:$git_password" -sO "$private_url"
else
    curl -sO "$mirror/openwrt/scripts/10-custom.sh"
fi
chmod 0755 ./*sh

group "patching openwrt"
for s in 00-prepare_base 01-prepare_base-mainline 02-prepare_package 04-fix_kmod \
         05-fix-source 06-prepare_adguard_core 07-preset_mihomo_core; do
    bash "$s.sh"
done
[ -f 10-custom.sh ] && bash 10-custom.sh
find feeds -type f -name "*.orig" -delete
endgroup

echo -e "\n${GREEN_COLOR}Inject default network settings ...${RES}"
echo -e "${GREEN_COLOR}LAN:${RES} ${LAN}"
echo -e "${GREEN_COLOR}LAN_GATEWAY:${RES} ${LAN_GATEWAY}"
echo -e "${GREEN_COLOR}LAN_DNS:${RES} ${LAN_DNS}"
find . -type f -name "zzz-default-settings" -print -exec sed -i \
    -e "s|__LAN_ADDR__|${LAN}|g" \
    -e "s|__LAN_GATEWAY__|${LAN_GATEWAY}|g" \
    -e "s|__LAN_DNS__|${LAN_DNS}|g" {} +
echo -e "\n${GREEN_COLOR}Check zzz-default-settings:${RES}"
find . -type f -name "zzz-default-settings" -exec \
    grep -n "LAN_ADDR\|LAN_GATEWAY\|LAN_DNS\|network.lan.ipaddr\|network.lan.gateway\|network.lan.dns" {} \; || true
rm -f 0*-*.sh 10-custom.sh

########## config ##########
case "$platform" in
    x86_64) dev_cfg=25-config-musl-x86 ;;
    rk3568) dev_cfg=25-config-musl-r5s ;;
    rk3576) dev_cfg=25-config-musl-r76s ;;
    armv8)  dev_cfg=25-config-musl-armsr-armv8 ;;
    *)      dev_cfg=25-config-musl-r4s ;;
esac
curl -s "$mirror/openwrt/$dev_cfg" > .config

if [ "$MINIMAL_BUILD" = "y" ]; then
    add_cfg_url "$mirror/openwrt/25-config-minimal-common"
    echo 'VERSION_TYPE="minimal"' >> package/base-files/files/usr/lib/os-release
elif [ "$STD_BUILD" = "y" ]; then
    add_cfg_url "$mirror/openwrt/25-config-std-common"
    echo 'VERSION_TYPE="standard"' >> package/base-files/files/usr/lib/os-release
else
    add_cfg_url "$mirror/openwrt/25-config-common"
    [ "$platform" = "armv8" ] && sed -i '/DOCKER/Id' .config
fi

# AdGuardHome
sed -i '/CONFIG_PACKAGE_adguardhome/d' .config
add_cfg 'CONFIG_PACKAGE_adguardhome=y'

# ota
[ "$ENABLE_OTA" = "y" ] && [ "$version" = "rc2" ] && add_cfg 'CONFIG_PACKAGE_luci-app-ota=y'

# bpf
add_cfg_url "$mirror/openwrt/generic/config-bpf"
[ "$ENABLE_BPF" != "y" ] && sed -i '/KERNEL_DEBUG_INFO\|KERNEL_MODULE_ALLOW_BTF/d' .config

# LTO / glibc
[ "$ENABLE_LTO" = "y" ] && add_cfg_url "$mirror/openwrt/generic/config-lto"
[ "$ENABLE_GLIBC" = "y" ] && { add_cfg_url "$mirror/openwrt/generic/config-glibc"; sed -i '/NaiveProxy/d' .config; }

# DPDK / istore / mold
[ "$ENABLE_DPDK"   = "y" ] && add_cfg 'CONFIG_PACKAGE_dpdk-tools=y' 'CONFIG_PACKAGE_numactl=y'
[ "$ENABLE_ISTORE" = "y" ] && add_cfg 'CONFIG_PACKAGE_luci-app-store=y' 'CONFIG_PACKAGE_luci-app-quickstart=y'
[ "$ENABLE_MOLD"   = "y" ] && add_cfg 'CONFIG_USE_MOLD=y'

# kernel - CLANG + LTO  (原逻辑: USE_GCC15 || (USE_GCC16 && ENABLE_CCACHE))
if [ "$KERNEL_CLANG_LTO" = "y" ]; then
    if [ "$USE_GCC15" = "y" ] || { [ "$USE_GCC16" = "y" ] && [ "$ENABLE_CCACHE" = "y" ]; }; then
        kernel_cc="ccache clang"
    else
        kernel_cc="clang"
    fi
    add_cfg '# Kernel - CLANG LTO' "CONFIG_KERNEL_CC=\"$kernel_cc\"" \
            'CONFIG_EXTRA_OPTIMIZATION=""' '# CONFIG_PACKAGE_kselftests-bpf is not set'
fi

# kernel - LRNG
[ "$ENABLE_LRNG" = "y" ] && add_cfg '' '# Kernel - LRNG' 'CONFIG_KERNEL_LRNG=y' \
    '# CONFIG_PACKAGE_urandom-seed is not set' '# CONFIG_PACKAGE_urngd is not set'

# local kmod
[ "$ENABLE_LOCAL_KMOD" = "y" ] && add_cfg '' '# local kmod' 'CONFIG_TARGET_ROOTFS_LOCAL_PACKAGES=y'

# gcc
add_cfg '' "# gcc ${gcc_version}" 'CONFIG_DEVEL=y' 'CONFIG_TOOLCHAINOPTS=y' \
        "CONFIG_GCC_USE_VERSION_${gcc_version}=y" ''

# uhttpd / kmod / core
[ "$ENABLE_UHTTPD" = "y" ] && { sed -i '/nginx/d' .config; add_cfg 'CONFIG_PACKAGE_ariang=y'; }
[ "$NO_KMOD" = "y" ] && sed -i '/CONFIG_ALL_KMODS=y/d; /CONFIG_ALL_NONSHARED=y/d' .config
[ "$OPENWRT_CORE" = "y" ] && {
    add_cfg_url "$mirror/openwrt/generic/config-wwan"
    add_cfg 'CONFIG_PACKAGE_kmod-mt7927-firmware=m'
}

# ccache
if [ "$ENABLE_CCACHE" = "y" ]; then
    add_cfg 'CONFIG_CCACHE=y'
    [ -n "$IS_RUNNER" ] && add_cfg 'CONFIG_CCACHE_DIR="/builder/.ccache"'
    [ -n "$IS_SBWML" ]  && add_cfg 'CONFIG_CCACHE_DIR="/home/sbwml/.ccache"'
    tools_suffix="_ccache"
fi

# nanopi-r76s
[ "$platform" = "rk3576" ] && sed -i '/samba4/d; /qbittorrent/d' .config

# add to core
[ "$OPENWRT_CORE" = "y" ] && add_cfg_url "$mirror/openwrt/generic/config-build-only"

########## toolchain cache ##########
if [ "$BUILD_FAST" = "y" ]; then
    [ "$isCN" = "CN" ] && github_proxy="ghp.ci/" || github_proxy=""
    echo -e "\n${GREEN_COLOR}Download Toolchain ...${RES}"
    PLATFORM_ID=""
    [ -f /etc/os-release ] && source /etc/os-release
    if [ "$PLATFORM_ID" = "platform:el10" ]; then
        TOOLCHAIN_URL="http://127.0.0.1:8080"
    else
        TOOLCHAIN_URL="https://${github_proxy}github.com/grandway2025/Toolchain-Cache/releases/download/openwrt-25.12"
    fi
    curl -L "${TOOLCHAIN_URL}/toolchain_${LIBC}_${toolchain_arch}_gcc-${gcc_version}${tools_suffix}.tar.zst" \
         -o toolchain.tar.zst $CURL_BAR
    echo -e "\n${GREEN_COLOR}Downloaded toolchain:${RES}"; ls -lh toolchain.tar.zst
    echo -e "\n${GREEN_COLOR}Process Toolchain ...${RES}"
    tar -I zstd -xf toolchain.tar.zst && rm -f toolchain.tar.zst
    mkdir -p bin
    find staging_dir tmp -exec touch {} + >/dev/null 2>&1 || true
fi

########## build ##########
rm -rf tmp/*
[ "$BUILD" = "n" ] && exit 0
make defconfig

if [ "$BUILD_TOOLCHAIN" = "y" ]; then
    echo -e "\r\n${GREEN_COLOR}Building Toolchain ...${RES}\r\n"
    make -j$cores toolchain/compile || make -j$cores toolchain/compile V=s || exit 1
    mkdir -p toolchain-cache
    tar -I "zstd -19 -T$(nproc --all)" \
        -cf "toolchain-cache/toolchain_${LIBC}_${toolchain_arch}_gcc-${gcc_version}${tools_suffix}.tar.zst" \
        ./{build_dir,dl,staging_dir,tmp}
    echo -e "\n${GREEN_COLOR} Build success! ${RES}"
    exit 0
fi

echo -e "\r\n${GREEN_COLOR}Building OpenWrt ...${RES}\r\n"
sed -i "/BUILD_DATE/d" package/base-files/files/usr/lib/os-release
sed -i "/BUILD_ID/aBUILD_DATE=\"$CURRENT_DATE\"" package/base-files/files/usr/lib/os-release
make -j$cores IGNORE_ERRORS="n m" || true

SEC=$SECONDS
if compgen -G "bin/targets/*/*/sha256sums" >/dev/null; then
    echo -e "${GREEN_COLOR} Build success! ${RES}"
    echo -e " Build time: $(fmt_time $SEC)"
else
    echo -e "\n${RED_COLOR} Build error... ${RES}"
    echo -e " Build time: $(fmt_time $SEC)\n"
    exit 1
fi

########## package & ota ##########
pack_kmods() {   # $1 target包目录 $2 包架构 $3 固件通配 $4 tar前缀
    local tdir="$1" parch="$2" fw="$3" prefix="$4"
    cp -a $tdir "$kmodpkg_name"
    rm -f "$kmodpkg_name"/Packages*
    copy_pkgs "bin/packages/$parch/base/"$fw
    if [ "$OPENWRT_CORE" = "y" ]; then
        copy_pkgs "bin/packages/$parch/base/"*{3ginfo,modemband,sms-tool,quectel}*.apk \
                  "bin/packages/aarch64_generic/base/"{natflow,appfilter,luci-app-oaf,luci-i18n-oaf}*.apk
    fi
    [ "$ENABLE_DPDK" = "y" ] && copy_pkgs "bin/packages/$parch/base/"*{dpdk,numa}*.apk
    bash kmod-sign "$kmodpkg_name"
    tar zcf "${prefix}-${kmodpkg_name}.tar.gz" "$kmodpkg_name"
    rm -rf "$kmodpkg_name"
}

ota_json() {     # 三元组: board 镜像通配 url文件名 ...
    mkdir -p ota
    local out="{" sep="" sha
    while [ $# -ge 3 ]; do
        sha=$(sha256sum $2 | awk '{print $1}')
        out+="$sep
  \"$1\": [
    {
      \"build_date\": \"$CURRENT_DATE\",
      \"sha256sum\": \"$sha\",
      \"url\": \"$OTA_URL/$3\"
    }
  ]"
        sep=","; shift 3
    done
    printf '%s\n}\n' "$out" > ota/fw.json
}

[ "$version" = "rc2" ] && VERSION=$(sed 's/v//g' version.txt)

case "$platform" in
x86_64)
    [ "$NO_KMOD" != "y" ] && pack_kmods "bin/targets/x86/*/packages" x86_64 'rtl88*a-firmware*.apk' x86_64
    if [ "$version" = "rc2" ]; then
        OTA_URL="https://dev.cooluc.com/$channel/x86_64"
        ota_json "x86_64" "bin/targets/x86/64*/*-generic-squashfs-combined-efi.img.gz" \
                 "openwrt-$VERSION-x86-64-generic-squashfs-combined-efi.img.gz"
    fi
    ;;
armv8)
    [ "$NO_KMOD" != "y" ] && pack_kmods "bin/targets/armsr/armv8*/packages" aarch64_generic 'rtl88*a-firmware*.apk' armv8
    if [ "$version" = "rc2" ]; then
        OTA_URL="https://dev.cooluc.com/$channel/armv8"
        ota_json "armsr,armv8" "bin/targets/armsr/armv8*/*-generic-squashfs-combined-efi.img.gz" \
                 "openwrt-$VERSION-armsr-armv8-generic-squashfs-combined-efi.img.gz"
    fi
    ;;
*)
    if [ "$NO_KMOD" != "y" ] && [ "$platform" != "rk3399" ]; then
        pack_kmods "bin/targets/rockchip/armv8*/packages" aarch64_generic 'rtl88*-firmware*.apk' aarch64
    fi
    if [ "$version" = "rc2" ]; then
        OTA_URL="https://dev.cooluc.com/$channel/$model"
        IMG="bin/targets/rockchip/armv8*"
        PFX="openwrt-$VERSION-rockchip-armv8-friendlyarm"
        case "$model" in
            nanopi-r4s)
                ota_json "friendlyarm,nanopi-r4s" "$IMG/*-squashfs-sysupgrade.img.gz" \
                         "${PFX}_nanopi-r4s-squashfs-sysupgrade.img.gz" ;;
            nanopi-r5s)
                ota_json "friendlyarm,nanopi-r5c" "$IMG/*-r5c-squashfs-sysupgrade.img.gz" \
                         "${PFX}_nanopi-r5c-squashfs-sysupgrade.img.gz" \
                         "friendlyarm,nanopi-r5s" "$IMG/*-r5s-squashfs-sysupgrade.img.gz" \
                         "${PFX}_nanopi-r5s-squashfs-sysupgrade.img.gz" ;;
            nanopi-r76s)
                ota_json "friendlyarm,nanopi-r76s" "$IMG/*-r76s-squashfs-sysupgrade.img.gz" \
                         "${PFX}_nanopi-r76s-squashfs-sysupgrade.img.gz" ;;
        esac
    fi
    ;;
esac

# Backup download cache (armv8 不备份, 与原脚本一致)
if [ "$isCN" = "CN" ] && [ "$version" = "rc2" ] && [ "$platform" != "armv8" ]; then
    rm -rf dl/geo* dl/go-mod-cache
    tar cf ../dl.gz dl
fi
exit 0
