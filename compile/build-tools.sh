#!/bin/bash
. ./include.sh

# setup misc settings
misc_init() { log "INFO" "Initializing setup phase"; }

# config target branch version
misc_branch() { log "INFO" "Setting branch version: $(echo "${BRANCH}" | cut -d'.' -f1)"; }

# network interfaces and permissions
misc_permissions() {
    if [[ "${TYPE:-}" == "OPHUB" || "${TYPE:-}" == "ULO" ]]; then
        log "INFO" "Sett Amlogic file permissions"
        local files=(
            "files/lib/netifd/proto/3g.sh" 
            "files/lib/netifd/proto/atc.sh" 
            "files/lib/netifd/proto/dhcp.sh"
            "files/lib/netifd/proto/dhcpv6.sh" 
            "files/lib/netifd/proto/ncm.sh" 
            "files/lib/netifd/proto/wwan.sh"
            "files/lib/netifd/wireless/mac80211.sh" 
            "files/lib/netifd/dhcp-get-server.sh" 
            "files/lib/netifd/dhcp.script"
            "files/lib/netifd/dhcpv6.script" 
            "files/lib/netifd/hostapd.sh" 
            "files/lib/netifd/netifd-proto.sh"
            "files/lib/netifd/netifd-wireless.sh" 
            "files/lib/netifd/utils.sh" 
            "files/lib/wifi/mac80211.sh"
        )
        for f in "${files[@]}"; do [ -f "$f" ] && chmod 755 "$f"; done
    else
        log "INFO" "Cleaning lib directory (official build)"
        find "files/lib" -mindepth 1 ! -path "*/netifd" ! -path "*/netifd/proto*" -delete
        local files=(
            "files/lib/netifd/proto/3g.sh" 
            "files/lib/netifd/proto/atc.sh" 
            "files/lib/netifd/proto/dhcp.sh"
            "files/lib/netifd/proto/dhcpv6.sh" 
            "files/lib/netifd/proto/ncm.sh" 
            "files/lib/netifd/proto/wwan.sh"
        )
        for f in "${files[@]}"; do [ -f "$f" ] && chmod 755 "$f"; done
    fi
}

# download scripts
misc_download_scripts() {
    log "INFO" "download scripts"
    local scripts=(
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/syntax|files/usr/bin"
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/x-gpio|files/usr/bin"
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/xidz|files/usr/bin"
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/xdev|files/usr/bin"
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/x-gpioled|files/usr/bin"
        "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xcli/xidzs|files/etc/init.d"
    )
    for s in "${scripts[@]}"; do IFS='|' read -r url path <<< "$s"; mkdir -p "$path"; wget --no-check-certificate -nv -P "$path" "$url" || log "WARN" "Failed to download $url"; done
}

# download qmodem packages
misc_download_qmodem() {
    # exclude on armv6, armv7, and 386
    if [[ ! ( "${ARCH_1:-}" == "armv6" || \
              "${ARCH_1:-}" == "armv7" || \
              "${ARCH_1:-}" == "386" ) ]]; then
        log "INFO" "download qmodem packages"
        
        # Normalize arch string (replace '_' with '-')
        local arch_fmt="${ARCH_3//_/-}"
        
        # Append target suffix for generic aarch64
        if [[ "$arch_fmt" == "aarch64-generic" ]]; then
            arch_fmt="${arch_fmt}-armv8"
        fi

        # Resolve pkg extension and version suffix
        local pkg_ext=""
        local v_suf=""
        case "${VEROP:-}" in
            "25.12") pkg_ext="apk"; v_suf="V25" ;;
            "24.10") pkg_ext="ipk"; v_suf="V24" ;;
            "23.05") pkg_ext="ipk"; v_suf="V23" ;;
            *) log "WARN" "Unsupported VEROP: ${VEROP}"; return 1 ;;
        esac
        
        # Construct dynamic URL
        local qmodem_url="https://raw.githubusercontent.com/syntax-xidz/contenx/main/xmodem/QModem-${arch_fmt}_${pkg_ext}_${v_suf}.zip"

        log "INFO" "Downloading QModem packages from: $qmodem_url"
        wget --no-check-certificate -q "$qmodem_url" -O qmodem.zip
        
        if [[ -f "qmodem.zip" ]]; then
            mkdir -p packages
            unzip -q -o qmodem.zip -d packages/
            rm -f qmodem.zip
            log "SUCCESS" "QModem packages extracted to packages directory"
        else
            log "WARN" "Failed to download QModem ZIP"
        fi
    else
        log "INFO" "Skipp download qmodem packages for arch: ${ARCH_1}"
    fi
}

# set permission files and directory
misc_file_perms() {
    log "INFO" "Applying file sett permissions"
    local exec_files=(
        "files/etc/init.d/xidzs"
        "files/etc/init.d/repair_ro"
        "files/sbin/free.sh"
        "files/sbin/jam"
        "files/sbin/ping.sh"
        "files/sbin/repair_ro"
        "files/usr/bin/xdev"
        "files/usr/bin/xidz"
        "files/usr/bin/syntax"
        "files/usr/bin/x-gpio"
        "files/usr/bin/x-gpioled"
        "files/usr/bin/repair_ro"
        "files/etc/hotplug.d/tty/25-modemmanager-tty"
    )
    for f in "${exec_files[@]}"; do [ -f "$f" ] && chmod 755 "$f"; done
    
    local conf_files=( 
        "files/etc/crontabs/root"
        "files/etc/rc.local"
        "files/etc/sysctl.conf"
    )
    for f in "${conf_files[@]}"; do [ -f "$f" ] && chmod 644 "$f"; done

    local target_dirs=(
        "files/etc/config"
        "files/usr/lib/lua"
        "files/www"
    )
    for d in "${target_dirs[@]}"; do
        if [ -d "$d" ]; then
            find "$d" -type f -exec chmod 644 {} +
            find "$d" -type d -exec chmod 755 {} +
        fi
    done
}

# config base firmware variables
misc_base_config() {
    local uci_dir="files/etc/uci-defaults"

    # ensure directory exists before downloading
    [ ! -d "$uci_dir" ] && mkdir -p "$uci_dir"

    if [[ "${TARGET_BUILD:-}" == "s905x-b860h" || "${TARGET_BUILD:-}" == "s905x" ]]; then
        log "INFO" "Target WIFIOFF detected"
        wget --no-check-certificate -q -O "$uci_dir/99-init-settings.sh" "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xidz/wifioff/99-init-settings.sh" || log "WARN" " 99 script setup download failed"
    else
        log "INFO" "Standard target detected"
        wget --no-check-certificate -q -O "$uci_dir/99-init-settings.sh" "https://raw.githubusercontent.com/syntax-xidz/contenx/main/xidz/wifion/99-init-settings.sh" || log "WARN" "99 script setup download failed"
    fi

    log "INFO" "Configuring base system: ${BASE}"
}

# build ophub and ulo
misc_amlogic() {
    if [[ "${TYPE:-}" == "OPHUB" || "${TYPE:-}" == "ULO" ]]; then
        log "INFO" "Removing Amlogic files"
        rm -f "files/etc/uci-defaults/70-rootpt-resize" "files/etc/uci-defaults/80-rootfs-resize" "files/etc/sysupgrade.conf"
    fi
}

# misc configurations
run_misc() { 
    misc_init
    misc_branch
    misc_permissions
    misc_download_scripts
    #misc_download_qmodem
    misc_file_perms
    misc_base_config
    misc_amlogic
    log "SUCCESS" "Setup phase completed"
}

# apply system configurations and partition size
run_patch() {
    local rootfs_size="${1:-1024}"
    cd "${GITHUB_WORKSPACE}/${WORKING_DIR}" || error_msg "Failed to change directory"

    if [[ "${BASE}" == "openwrt" ]]; then
        log "INFO" "Applying OpenWrt patches"
    elif [[ "${BASE}" == "immortalwrt" ]]; then
        sed -i "\|luci-app-cpufreq|d" include/target.mk
    fi

    if [ -f "repositories.conf" ]; then
        log "INFO" "Disabling signature check in repositories.conf"
        sed -i '\|option check_signature| s|^|#|' repositories.conf 2>/dev/null || true
    else
        log "INFO" "repositories.conf not found, skipping signature patch"
    fi

    if [[ "${VEROP:-}" == "25.12" ]]; then
        log "INFO" "Patching Makefile for 25.12"
        sed -i "s|--no-scripts \$(BUILD_PACKAGES)|--no-scripts --force-overwrite \$(BUILD_PACKAGES)|" Makefile
    else
        log "INFO" "Patching Makefile for 23.05 & 24.10"
        sed -i "s|install \$(BUILD_PACKAGES)|install \$(BUILD_PACKAGES) --force-overwrite --force-downgrade|" Makefile
    fi

    sed -i "s|CONFIG_TARGET_KERNEL_PARTSIZE=.*|CONFIG_TARGET_KERNEL_PARTSIZE=128|" .config
    sed -i "s|CONFIG_TARGET_ROOTFS_PARTSIZE=.*|CONFIG_TARGET_ROOTFS_PARTSIZE=${rootfs_size}|" .config

    if [[ "${TYPE:-}" == "OPHUB" || "${TYPE:-}" == "ULO" ]]; then
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
    fi

    if [[ "${ARCH_2}" == "x86_64" || "${ARCH_2}" == "i386" ]]; then
        sed -i "s|CONFIG_ISO_IMAGES=y|# CONFIG_ISO_IMAGES is not set|" .config
        sed -i "s|CONFIG_VHDX_IMAGES=y|# CONFIG_VHDX_IMAGES is not set|" .config
    fi

    log "SUCCESS" "System patching completed"
}

# custom packages repository
run_packages() {
    local kiddin9_ver="${VEROP}"
    [[ "${VEROP}" == "23.05" ]] && kiddin9_ver="24.10"
    local kiddin9_url="https://dl.openwrt.ai/releases/${kiddin9_ver}/packages/${ARCH_3}/kiddin9"
    
    declare -A REPOS=(
        ["OPENWRT"]="https://downloads.openwrt.org/releases/packages-${VEROP:-24.10}/${ARCH_3}"
        ["IMMORTALWRT"]="https://downloads.immortalwrt.org/releases/packages-${VEROP:-24.10}/${ARCH_3}"
        ["KYARUCLOUD_IMMORTALWRT"]="https://immortalwrt.kyarucloud.moe/releases/packages-${VEROP:-24.10}/${ARCH_3}"
        ["KIDDIN9"]="${kiddin9_url}"
        ["GSPOTX2F"]="https://github.com/gSpotx2f/packages-openwrt/raw/refs/heads/master/current"
        ["DLLKIDS"]="https://op.dllkids.xyz/packages/${ARCH_3}"
        ["OPENWRTRU"]="https://openwrt.132lan.ru/packages/${VEROP:-24.10}/packages/${ARCH_3}/modemfeed"
    )

    local MODEM_REPO="${REPOS[KIDDIN9]}"
    local WATCHDOG_REPO="${REPOS[KIDDIN9]}"
    local SMSTOOL_REPO="${REPOS[KIDDIN9]}"
    
    if [[ "${VEROP:-}" == "25.12" ]]; then
        MODEM_REPO="${REPOS[OPENWRTRU]}"
        WATCHDOG_REPO="https://api.github.com/repos/4IceG/luci-app-lite-watchdog/releases/latest"
        SMSTOOL_REPO="https://api.github.com/repos/4IceG/luci-app-sms-tool-js/releases/latest"
    fi

    # download packages for 23.05.x | 24.10.x | 25.12.x
    declare -a packages_core=(
        "luci-app-diskman|${REPOS[IMMORTALWRT]}/luci"
        "luci-app-ramfree|${REPOS[IMMORTALWRT]}/luci"
        "luci-app-ttyd|${REPOS[OPENWRT]}/luci"
        "luci-app-lite-watchdog|${WATCHDOG_REPO}"
        "luci-app-mmconfig|${REPOS[OPENWRTRU]}"
        "luci-app-modeminfo|${MODEM_REPO}"
        "modeminfo-serial-tw|${MODEM_REPO}"
        "modeminfo-serial-dell|${MODEM_REPO}"
        "modeminfo-serial-sierra|${MODEM_REPO}"
        "modeminfo-serial-xmm|${MODEM_REPO}"
        "modeminfo-serial-fibocom|${MODEM_REPO}"
        "atinout|${MODEM_REPO}"
        "luci-app-sms-tool-js|${SMSTOOL_REPO}"
        "tailscale|${REPOS[OPENWRT]}/packages"
        "luci-theme-footstrap|https://api.github.com/repos/VizzleTF/luci-theme-footstrap/releases/latest"
        "luci-theme-luxe|https://api.github.com/repos/de-quenx/luci-theme-luxe/releases/latest"
        "luci-theme-argon|https://api.github.com/repos/de-quenx/luci-theme-argon/releases/latest"
        "luci-app-temp-status|https://api.github.com/repos/de-quenx/kwrt-packages/releases/latest"
        "luci-app-tinyfm|https://api.github.com/repos/de-quenx/luci-app-tinyfm/releases/latest"
        "luci-app-netmonitor|https://api.github.com/repos/de-quenx/luci-app-netmonitor/releases/latest"
        "luci-app-ttl|https://api.github.com/repos/de-quenx/custom-x/releases/latest"
        "luci-app-ipinfo|https://api.github.com/repos/de-quenx/luci-app-ipinfo/releases/latest"
        "luci-app-tailscale|https://api.github.com/repos/asvow/luci-app-tailscale/releases/latest"
        "modemdata|https://api.github.com/repos/4IceG/luci-app-modemdata/releases/latest"
        "luci-app-modemdata|https://api.github.com/repos/4IceG/luci-app-modemdata/releases/latest"
    )
    
    if [[ "${TYPE:-}" == "OPHUB" || "${TYPE:-}" == "ULO" ]]; then 
        packages_core+=("luci-app-amlogic|https://api.github.com/repos/ophub/luci-app-amlogic/releases/latest")
    fi

    # download packages for 25.12.x
    if [[ "${VEROP:-}" == "25.12" ]]; then
        packages_core+=(
            "xmm-modem|${REPOS[OPENWRTRU]}"
            "luci-proto-xmm|${REPOS[OPENWRTRU]}"
            "luci-app-eqosplus|https://api.github.com/repos/sirpdboy/luci-app-eqosplus/releases/latest"
        )
    fi

    # check condition for internet-detector
    local skip_internetd=0
    if [[ "${VEROP:-}" == "25.12" ]]; then
        if [[ "${PROFILE:-}" == "rpi-5" || "${PROFILE:-}" == "rpi" || "${PROFILE:-}" == "rpi-2" || ( "${PROFILE:-}" == "generic" && "${ARCH_2:-}" == "i386" ) ]]; then
            skip_internetd=1
            log "INFO" "Skipping internet-detector packages download for ${PROFILE} on Os 25.12.x"
        fi
    fi

    # internet-detector for 23.05.x & 24.10.x
    if [[ "${VEROP:-}" == "23.05" || "${VEROP:-}" == "24.10" ]]; then
        if [[ $skip_internetd -eq 0 ]]; then
            packages_core+=(
                "luci-app-internet-detector|${REPOS[KIDDIN9]}"
                "internet-detector|${REPOS[KIDDIN9]}"
                "internet-detector-mod-modem-restart|${REPOS[KIDDIN9]}"
            )
        fi
    fi

    # download packages for 23.05.x | 24.10.x
    declare -a packages_custom=(
        "luci-app-poweroffdevice|${REPOS[KIDDIN9]}"
        "ookla-speedtest|${REPOS[KIDDIN9]}"
        "luci-app-eqosplus|${REPOS[KIDDIN9]}"
    )

    log "INFO" "download core packages"
    download_packages packages_core

    # dynamic 'modeminfo' versions and clean up 'modeminfo-telegram' 
    rm -f packages/modeminfo-telegram* 2>/dev/null || true
    local pkg_ext=$(get_package_extension "${VEROP:-24.10}")
    
    # filter strictly for modeminfo, ensure version is dynamic
    local mi_filename=$(curl -sL "${MODEM_REPO}/" | grep -oE 'href="[^"]+"' | sed 's/href="//;s/"//' | awk -F'/' '{print $NF}' | grep -E "^modeminfo[-_][0-9].*\.${pkg_ext}$" | sort -V | tail -n 1)
    
    if [[ -n "$mi_filename" ]]; then
        log "INFO" "Targeting latest dynamic modeminfo: ${mi_filename}"
        ariadl "${MODEM_REPO}/${mi_filename}" "packages/${mi_filename}"
        # append back for end-of-function package verification
        packages_core+=("modeminfo|${MODEM_REPO}")
    else
        log "WARN" "Failed to strictly fetch exact modeminfo package"
    fi

    if [[ "${VEROP:-}" == "23.05" || "${VEROP:-}" == "24.10" ]]; then
        log "INFO" "OS 23.05.x | 24.10.x custom packages"
        download_packages packages_custom
        packages_core+=("${packages_custom[@]}")
        
        log "INFO" "Os 23.05.x | 24.10.x: ATC ipk packages"
        ariadl "https://raw.githubusercontent.com/de-quenx/openwrt/master/atc/luci-proto-atc_2025.01.10-r2_all.ipk" "packages/luci-proto-atc_2025.01.10-r2_all.ipk"
        ariadl "https://raw.githubusercontent.com/de-quenx/openwrt/master/atc/fib-l8x0_gl/atc-fib-l8x0_gl_2025-09-06-r0.3_all.ipk" "packages/atc-fib-l8x0_gl_2025-09-06-r0.3_all.ipk"
        ariadl "https://raw.githubusercontent.com/de-quenx/openwrt/master/atc/fib-fm350_gl/atc-fib-fm350_gl_2025.02.01-r3_all.ipk" "packages/atc-fib-fm350_gl_2025.02.01-r3_all.ipk"
    else
        log "INFO" "Os 25.12.x: Skipp custom packages"
        
        log "INFO" "Os 25.12.x: ATC apk packages"
        ariadl "https://raw.githubusercontent.com/de-quenx/openwrt/master/atc/luci-proto-atc-2025.01.10-r2.apk" "packages/luci-proto-atc-2025.01.10-r2.apk"
        ariadl "https://raw.githubusercontent.com/de-quenx/openwrt/master/atc/fib-l8x0_gl/atc-fib-l8x0_gl-2025.09.06-r3.apk" "packages/atc-fib-l8x0_gl-2025.09.06-r3.apk"
        
        if [[ $skip_internetd -eq 0 ]]; then
            # 25.12.x: Internet-detector packages
            log "INFO" "Os 25.12.x: Internet-detector packages"
            ariadl "https://fantastic-packages.github.io/releases/25.12/packages/${ARCH_3}/luci/luci-app-internet-detector-1.7.3-r1.apk" "packages/luci-app-internet-detector-1.7.3-r1.apk"
            ariadl "https://fantastic-packages.github.io/releases/25.12/packages/${ARCH_3}/packages/internet-detector-1.7.3-r1.apk" "packages/internet-detector-1.7.3-r1.apk"
            ariadl "https://fantastic-packages.github.io/releases/25.12/packages/${ARCH_3}/packages/internet-detector-mod-modem-restart-1.7.3-r1.apk" "packages/internet-detector-mod-modem-restart-1.7.3-r1.apk"
            
            # internet-detector for 25.12.x
            packages_core+=(
                "luci-app-internet-detector|fantastic-packages"
                "internet-detector|fantastic-packages"
                "internet-detector-mod-modem-restart|fantastic-packages"
            )
        fi
    fi

    # verify downloaded packages
    local pkg_dir="packages" failed_packages=() pkg_ext=$(get_package_extension "${VEROP:-24.10}")
    local total_found=$(find "$pkg_dir" -type f \( -name "*.apk" -o -name "*.ipk" \) | wc -l)
    
    for p in "${packages_core[@]}"; do 
        local p_name="${p%%|*}"
        if ! find "$pkg_dir" -name "${p_name}*.${pkg_ext}" -print -quit | grep -q .; then 
            if ! find "$pkg_dir" -name "${p_name}*.ipk" -print -quit | grep -q .; then
                failed_packages+=("$p_name")
            fi
        fi
    done

    if ((${#failed_packages[@]} > 0)); then 
        for fp in "${failed_packages[@]}"; do log "WARN" "Missing package: $fp"; done
        error_msg "Package verification failed"
    fi
    log "SUCCESS" "Package verification passed"
}

# Main tunnel configuration
run_tunnel() {
    local mode="${1:-}"
    if [ -z "$mode" ]; then error_msg "Usage tunnel <mode>"; fi
    local pkg_ext=$(get_package_extension "${VEROP:-24.10}")
    local meta_file="mihomo-linux-${ARCH_1}"
    if [[ "${ARCH_3}" == "x86_64" ]]; then meta_file="mihomo-linux-${ARCH_1}-compatible"; fi
    
    setup_openclash() {
        local oc_core=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | jq -r '.assets[].browser_download_url' | grep -oE "https.*${meta_file}-v[0-9]+\.[0-9]+\.[0-9]+\.gz" | head -n 1)
        local oc_ipk=$(curl -s "https://api.github.com/repos/Yogxx/OpenClash/releases" | jq -r '.[0].assets[].browser_download_url' | grep -iE "luci-app-openclash.*\.${pkg_ext}$" | head -n 1)
        [[ -z "$oc_core" || -z "$oc_ipk" ]] && { log "ERROR" "Failed to fetch OpenClash URLs"; return 1; }
        
        local clean_name=$(basename "${oc_ipk}" | sed -E 's/^[0-9\.\+\-_]+luci-app/luci-app/')
        ariadl "${oc_ipk}" "packages/${clean_name}"
        ariadl "${oc_core}" "files/etc/openclash/core/clash_meta.gz"
        
        gzip -d "files/etc/openclash/core/clash_meta.gz"
        chmod 755 "files/etc/openclash/core/clash_meta" "files/etc/openclash/Country.mmdb" "files/etc/openclash/GeoIP.dat" "files/etc/openclash/GeoSite.dat"
        sed -i "/# Tunnel/a \    ln -sf /etc/openclash/history/xidzs.db /etc/openclash/cache.db\n    ln -sf /etc/openclash/core/clash_meta /etc/openclash/clash" "files/etc/uci-defaults/99-init-settings.sh"
    }
    setup_passwall() {
        # Dynamic versioning
        local pw_search="luci-app-passwall"
        if [[ "${VEROP:-}" == "25.12" ]]; then
            pw_search="25\.12(%2B|\+)_luci-app-passwall"
        elif [[ "${VEROP:-}" == "24.10" || "${VEROP:-}" == "23.05" ]]; then
            pw_search="23\.05-24\.10_luci-app-passwall"
        fi
        
        local pw_ipk=$(curl -s "https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest" | jq -r '.assets[].browser_download_url' | grep -iE "${pw_search}.*\.${pkg_ext}$" | head -n 1)
        
        [[ -z "$pw_ipk" ]] && pw_ipk=$(curl -s "https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest" | jq -r '.assets[].browser_download_url' | grep -iE "luci-app-passwall.*\.${pkg_ext}$" | head -n 1)
        
        [[ -z "$pw_ipk" ]] && { log "ERROR" "Failed to fetch Passwall URL"; return 1; }
        
        local clean_name=$(basename "${pw_ipk}" | sed -E 's/^.*(luci-app-passwall.*)$/\1/')
        ariadl "${pw_ipk}" "packages/${clean_name}"
        
        local IMRT_BASE_URL="https://downloads.immortalwrt.org/releases/packages-${VEROP:-24.10}/${ARCH_3}"
        declare -a pw_deps=(
            "chinadns-ng|${IMRT_BASE_URL}/packages"
            "dns2socks|${IMRT_BASE_URL}/packages"
            "tcping|${IMRT_BASE_URL}/packages"
            "dns2tcp|${IMRT_BASE_URL}/packages"
        )
        download_packages pw_deps
    }
    setup_nikki() {
        local nikki_url=$(curl -s "https://api.github.com/repos/Yogxx/OpenWrt-nikkiku/releases" | jq -r '.[0].assets[].browser_download_url' | grep -oE "https.*nikki_${ARCH_3}-openwrt-${VEROP:-24.10}.*\.tar.gz" | head -n 1)
        if [[ "${VEROP:-}" == "23.05" ]]; then 
            nikki_url=$(curl -s "https://api.github.com/repos/Yogxx/OpenWrt-nikkiku/releases/tags/v1.25.0" | jq -r '.assets[].browser_download_url' | grep -oE "https.*nikki_${ARCH_3}-openwrt-${VEROP}.*\.tar.gz" | head -n 1)
        fi
        [[ -z "$nikki_url" ]] && { log "ERROR" "Failed to fetch Nikki URL"; return 1; }
        
        local n_file=$(basename "${nikki_url}")
        ariadl "${nikki_url}" "packages/${n_file}"
        tar -xzvf "packages/${n_file}" -C "packages" && rm -f "packages/${n_file}"
        chmod 755 "files/etc/nikki/run/Country.mmdb" "files/etc/nikki/run/GeoIP.dat" "files/etc/nikki/run/GeoSite.dat"
    }
    setup_fusiontunx() {
    
        local ft_prefix="fusiontunx_"
        [[ "$pkg_ext" == "apk" ]] && ft_prefix="fusiontunx-"
        
        local ft_ipk=$(curl -s "https://api.github.com/repos/bobbyunknown/FusionTunX/releases" | jq -r '.[0].assets[].browser_download_url' | grep -iE "luci-app-fusiontunx.*\.${pkg_ext}$" | head -n 1)
        local ft_core=$(curl -s "https://api.github.com/repos/bobbyunknown/FusionTunX/releases" | jq -r '.[0].assets[].browser_download_url' | grep -iE "${ft_prefix}[^\"]*${ARCH_3}[^\"]*\.${pkg_ext}$" | head -n 1)
        [[ -z "$ft_ipk" || -z "$ft_core" ]] && { log "ERROR" "Failed to fetch FusionTunX URLs"; return 1; }
        
        local clean_name=$(basename "${ft_ipk}" | sed -E 's/^[0-9\.\+\-_]+luci-app/luci-app/')
        ariadl "${ft_ipk}" "packages/${clean_name}"
        
        local core_name=$(basename "${ft_core}")
        
        if [[ "$pkg_ext" == "apk" ]]; then
            core_name="${clean_name/luci-app-/}"
        fi
        
        ariadl "${ft_core}" "packages/${core_name}"
    }
    setup_qtun() {
        local qtun_search="luci-app-qtun_.*_${ARCH_3}\.${pkg_ext}$"
        local qtun_url=$(curl -s "https://api.github.com/repos/QcomWrt/luci-app-qtun/releases/latest" | jq -r '.assets[].browser_download_url' | grep -iE "${qtun_search}" | head -n 1)
        [[ -z "$qtun_url" ]] && { log "ERROR" "Failed to fetch Qtun URL"; return 1; }
        
        local clean_name=$(basename "${qtun_url}" | sed -E "s/_${ARCH_3}//")
        
        if [[ "$pkg_ext" == "apk" ]]; then
            clean_name="${clean_name/_/-}"
            if [[ "$clean_name" =~ -([0-9]+)\.apk$ ]]; then
                clean_name="${clean_name/-${BASH_REMATCH[1]}.apk/-r${BASH_REMATCH[1]}.apk}"
            elif [[ ! "$clean_name" =~ -r[0-9]+\.apk$ ]]; then
                clean_name="${clean_name/.apk/-r1.apk}"
            fi
        else
            [[ ! "$clean_name" =~ -[0-9]+\.ipk$ ]] && clean_name="${clean_name/.ipk/-1.ipk}"
        fi
        
        ariadl "${qtun_url}" "packages/${clean_name}"
    }
    setup_clashoo() {
        local co_prefix="clashoo_"
        [[ "$pkg_ext" == "apk" ]] && co_prefix="clashoo-"
        
        local co_ipk=$(curl -s "https://api.github.com/repos/kenzok8/openwrt-clashoo/releases/latest" | jq -r '.assets[].browser_download_url' | grep -iE "luci-app-clashoo.*(${ARCH_3}|all)\.${pkg_ext}$" | head -n 1)
        local co_core=$(curl -s "https://api.github.com/repos/kenzok8/openwrt-clashoo/releases/latest" | jq -r '.assets[].browser_download_url' | grep -iE "${co_prefix}[^\"]*${ARCH_3}\.${pkg_ext}$" | grep -vi "luci-app" | head -n 1)
        [[ -z "$co_ipk" || -z "$co_core" ]] && { log "ERROR" "Failed to fetch Clashoo URLs"; return 1; }
        
        local clean_name=$(basename "${co_ipk}" | sed -E 's/^[0-9\.\+\-_]+luci-app/luci-app/')
        
        if [[ "$pkg_ext" == "apk" ]]; then
            clean_name="${clean_name/-${ARCH_3}/}"
        fi
        
        ariadl "${co_ipk}" "packages/${clean_name}"
        
        local core_name=$(basename "${co_core}")
        
        if [[ "$pkg_ext" == "apk" ]]; then
            core_name="${core_name/-${ARCH_3}/}"
        else
            core_name="${core_name/_${ARCH_3}/}"
        fi
        
        core_name=$(echo "$core_name" | sed -E 's/([0-9]{4}\.[0-9]{2}\.[0-9]{2})\.([a-z0-9]+)/\1~\2/')
        
        ariadl "${co_core}" "packages/${core_name}"
    }
    
    clean_oc() { rm -rf "files/etc/openclash"; }
    clean_pw() { rm -f "files/etc/config/passwall"; }
    clean_nk() { rm -rf "files/etc/nikki" "files/etc/config/nikki"; }
    clean_ft() { rm -rf "files/etc/fusiontunx"; }
    clean_co() { rm -rf "files/etc/clashoo"; }
    
    case "${mode}" in
        openclash) setup_openclash; clean_pw; clean_nk; clean_ft; clean_co ;;
        qtun) setup_qtun; clean_oc; clean_pw; clean_nk; clean_ft; clean_co ;;
        nikki) setup_nikki; clean_oc; clean_pw; clean_ft; clean_co ;;
        fusiontunx) setup_fusiontunx; clean_oc; clean_pw; clean_nk; clean_co ;;
        passwall) setup_passwall; clean_oc; clean_nk; clean_ft; clean_co ;;
        clashoo) setup_clashoo; clean_oc; clean_pw; clean_nk; clean_ft ;;
        nikki-passwall) setup_nikki; setup_passwall; clean_oc; clean_ft; clean_co ;;
        nikki-fusiontunx) setup_nikki; setup_fusiontunx; clean_oc; clean_pw; clean_co ;;
        nikki-qtun) setup_nikki; setup_qtun; clean_oc; clean_pw; clean_ft; clean_co ;;
        passwall-qtun) setup_passwall; setup_qtun; clean_oc; clean_nk; clean_ft; clean_co ;;
        fusiontunx-qtun) setup_fusiontunx; setup_qtun; clean_oc; clean_pw; clean_nk; clean_co ;;
        openclash-nikki) setup_openclash; setup_nikki; clean_pw; clean_ft; clean_co ;;
        openclash-qtun) setup_openclash; setup_qtun; clean_pw; clean_nk; clean_ft; clean_co ;;
        openclash-passwall) setup_openclash; setup_passwall; clean_nk; clean_ft; clean_co ;;
        openclash-fusiontunx) setup_openclash; setup_fusiontunx; clean_pw; clean_nk; clean_co ;;
        clashoo-passwall) setup_clashoo; setup_passwall; clean_oc; clean_nk; clean_ft ;;
        clashoo-qtun) setup_clashoo; setup_qtun; clean_oc; clean_pw; clean_nk; clean_ft ;;
        clashoo-fusiontunx) setup_clashoo; setup_fusiontunx; clean_oc; clean_pw; clean_nk ;;
        openclash-clashoo) setup_openclash; setup_clashoo; clean_pw; clean_nk; clean_ft ;;
        openclash-nikki-passwall) setup_openclash; setup_nikki; setup_passwall; clean_ft; clean_co ;;
        no-tunnel) clean_oc; clean_pw; clean_nk; clean_ft; clean_co ;;
        *) error_msg "Invalid option: ${mode}" ;;
    esac
    log "SUCCESS" "Tunnel configured: ${mode}"
    
    # Inspect downloaded packages
    log "INFO" "Inspecting packages directory contents:"
    [ -d "packages" ] && ls -lh packages/ 2>/dev/null || log "WARN" "Packages directory not found"
}

# compilation using imagebuilder
run_makeimage() {
    local target_profile="$1"
    local tunnel_option="${2:-}"
    local build_files="files"
    local PACKAGES=""
    local DISABLED_SERVICES="xidzs zram"
    local EXCLUDED=""
    
    log "INFO" "Initiating build: $target_profile | Tunnel: ${tunnel_option:-no-tunnel}"
    
    # base system and Luci
    PACKAGES+=" dnsmasq-full libc block-mount zram-swap zoneinfo-core zoneinfo-asia bash screen uhttpd uhttpd-mod-ubus \
    luci luci-ssl luci-base luci-compat luci-mod-admin-full luci-mod-network \
    luci-mod-system luci-mod-status luci-app-firewall luci-app-opkg openssh-sftp-server adb curl wget-ssl \
    httping htop jq tar unzip coreutils-base64 coreutils-sleep coreutils-stat "
    
    # network and driver modems
    PACKAGES+=" kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-rndis \
    kmod-usb-net-cdc-ether kmod-usb-net-cdc-ncm kmod-usb-net-sierrawireless kmod-usb-net-qmi-wwan kmod-usb-acm kmod-usb-net-huawei-cdc-ncm kmod-usb-net-cdc-mbim \
    kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan kmod-usb-serial-qualcomm kmod-usb-serial-sierrawireless modemmanager luci-proto-modemmanager \
    qmi-utils mbim-utils uqmi umbim luci-proto-ncm kmod-usb-ohci kmod-usb-uhci \
    kmod-usb2 kmod-usb-ehci kmod-usb3 usbutils usb-modeswitch kmod-nls-utf8 kmod-macvlan xmm-modem luci-proto-xmm "
    
    # wireless drivers
    if [[ "${TARGET_BUILD:-}" == "s905x-b860h" || "${TARGET_BUILD:-}" == "s905x" ]]; then
        log "INFO" "Target WIFIOFF detected: Excluding wireless drivers"
    else
        log "INFO" "Standard target: Including wireless drivers"
        if [[ "$target_profile" =~ rpi-[2-5] ]]; then
            PACKAGES+=" wpad-basic-mbedtls iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211"
        else
            PACKAGES+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211"
        fi
    fi
    
    # storage + nas
    local STORAGE="kmod-usb-storage luci-app-diskman kmod-usb-storage-uas ntfs-3g"
    
    # modem rakitan + autorekonek
    local MODEM="atinout sms-tool luci-app-sms-tool-js picocom minicom modemdata luci-app-modemdata luci-app-mmconfig luci-app-lite-watchdog"
    
    # qmodem
    local QMODEM="ubus-at-daemon sms-tool_q ndisc6 quectel-CM-5G-M qmodem tom_modem sms-forwarder-next luci-app-qmodem-next"
    
    # tinyfm + php8
    local TINYFM="php8 php8-cli php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo \
    php8-mod-zip php8-mod-iconv php8-mod-mbstring luci-app-tinyfm"
    
    # monitoring statistic
    local STATS="vnstat2 vnstati2 luci-app-netmonitor"
    
    # theme
    local THEME="luci-theme-luxe luci-theme-argon luci-theme-footstrap"
    
    # other
    local OTHER="luci-app-ramfree ttyd luci-app-ttyd luci-app-ttl luci-app-ipinfo luci-app-eqosplus"
    
    # internet detector packages
    local INTERNETD="internet-detector internet-detector-mod-modem-restart luci-app-internet-detector"
    if [[ "${VEROP:-}" == "25.12" ]]; then
        if [[ "$target_profile" == "rpi-5" || "$target_profile" == "rpi-2" || "$target_profile" == "rpi" || ( "$target_profile" == "generic" && "${ARCH_2:-}" == "i386" ) ]]; then
            log "INFO" "Excluding internet-detector packages for $target_profile on Os ${VEROP}"
            INTERNETD=""
        fi
    fi
    
    # all variable build firmware
    PACKAGES+=" ${STORAGE} ${MODEM} ${INTERNETD} \
    ${STATS} ${THEME} ${TINYFM} ${OTHER} "
    
    # exclude qmodem on armv6, armv7, and 386
    if [[ ! ( "${ARCH_1:-}" == "armv6" || \
              "${ARCH_1:-}" == "armv7" || \
              "${ARCH_1:-}" == "386" ) ]]; then
        PACKAGES+="" # ${QMODEM}
    fi
    
    # packages spesific
    if [[ "${VEROP:-}" == "23.05" || "${VEROP:-}" == "24.10" ]]; then
        # Os 23.05.x | 24.10.x
        PACKAGES+=" atc-fib-l8x0_gl atc-fib-fm350_gl luci-proto-atc tailscale luci-app-tailscale ookla-speedtest luci-app-poweroffdevice "
    else
        # Os 25.12.x
        PACKAGES+=" atc-fib-l8x0_gl luci-proto-atc tailscale luci-app-tailscale "
    fi
    
    local OPENCLASH="luci-app-openclash"
    local NIKKI="nikki luci-app-nikki"
    local QTUN="luci-app-qtun"
    local FUSIONTUNX="fusiontunx luci-app-fusiontunx"
    local NEKO="luci-app-neko"
    local PASSWALL="chinadns-ng dns2socks tcping dns2tcp luci-app-passwall"
    local CLASHOO="clashoo luci-app-clashoo"
    
    # tunnel option
    case "$tunnel_option" in
        openclash) PACKAGES+=" $OPENCLASH " ;;
        nikki) PACKAGES+=" $NIKKI " ;;
        neko) PACKAGES+=" $NEKO " ;;
        fusiontunx) PACKAGES+=" $FUSIONTUNX " ;;
        passwall) PACKAGES+=" $PASSWALL " ;;
        qtun) PACKAGES+=" $QTUN " ;;
        clashoo) PACKAGES+=" $CLASHOO " ;;
        nikki-passwall) PACKAGES+=" $NIKKI $PASSWALL " ;;
        nikki-fusiontunx) PACKAGES+=" $NIKKI $FUSIONTUNX " ;;
        nikki-qtun) PACKAGES+=" $NIKKI $QTUN " ;;
        passwall-qtun) PACKAGES+=" $PASSWALL $QTUN " ;;
        fusiontunx-qtun) PACKAGES+=" $FUSIONTUNX $QTUN " ;;
        openclash-nikki) PACKAGES+=" $OPENCLASH $NIKKI " ;;
        openclash-passwall) PACKAGES+=" $OPENCLASH $PASSWALL " ;;
        openclash-fusiontunx) PACKAGES+=" $OPENCLASH $FUSIONTUNX " ;;
        openclash-qtun) PACKAGES+=" $OPENCLASH $QTUN " ;;
        clashoo-passwall) PACKAGES+=" $CLASHOO $PASSWALL " ;;
        clashoo-qtun) PACKAGES+=" $CLASHOO $QTUN " ;;
        clashoo-fusiontunx) PACKAGES+=" $CLASHOO $FUSIONTUNX " ;;
        openclash-clashoo) PACKAGES+=" $OPENCLASH $CLASHOO " ;;
        openclash-nikki-passwall) PACKAGES+=" $OPENCLASH $NIKKI $PASSWALL " ;;
    esac
    
    # device specific packages
    if [[ "$target_profile" =~ rpi-[2-5] ]]; then
        PACKAGES+=" kmod-i2c-bcm2835 i2c-tools kmod-i2c-core kmod-i2c-gpio "
    elif [[ "${ARCH_2:-}" == "x86_64" ]] || [[ "${ARCH_2:-}" == "i386" ]]; then
        PACKAGES+=" kmod-iwlwifi iw-full pciutils wireless-tools "
    fi
    
    # builder spesific
    if [[ "${TYPE:-}" == "OPHUB" ]] || [[ "${TYPE:-}" == "ULO" ]]; then
        PACKAGES+=" btrfs-progs kmod-fs-btrfs luci-app-amlogic "
        EXCLUDED+=" -procd-ujail "
    fi
    
    # firmware base spesific
    if [[ "${BASE:-}" == "openwrt" ]]; then
        PACKAGES+=" luci-app-temp-status "
        EXCLUDED+=" -dnsmasq "
    elif [[ "${BASE:-}" == "immortalwrt" ]]; then
        EXCLUDED+=" -dnsmasq -cpusage -automount -libustream-openssl -default-settings-chn -luci-i18n-base-zh-cn "
        if [[ "${ARCH_2:-}" == "x86_64" ]] || [[ "${ARCH_2:-}" == "i386" ]]; then EXCLUDED+=" -kmod-usb-net-rtl8152-vendor "; fi
    fi
    
    make info
    make image PROFILE="$target_profile" \
               PACKAGES="$PACKAGES $EXCLUDED" \
               FILES="$build_files" \
               DISABLED_SERVICES="$DISABLED_SERVICES"
               
    local build_status=$?
    if [ "$build_status" -eq 0 ]; then
        log "SUCCESS" "Build completed successfully"
    else
        error_msg "Build failed with exit code $build_status"
    fi
}

# repack generic armv8 firmware to device specifics
run_repack() {
    local b_type="" board="" kernel="" tunnel="" rootfs_size="1024"
    
    # robust argument parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ophub|--ulo) b_type="$1"; shift ;;
            -t|--target) board="$2"; shift 2 ;;
            -k|--kernel) kernel="$2"; shift 2 ;;
            -tn|--tunnel) tunnel="$2"; shift 2 ;;
            -s|--size) rootfs_size="$2"; shift 2 ;;
            *) shift ;; # skip unknown args
        esac
    done
    
    # detailed debugging dump before failing
    if [[ -z "$b_type" || -z "$board" || -z "$kernel" || -z "$tunnel" ]]; then
        log "ERROR" "Arg Dump -> type:[${b_type}] board:[${board}] kernel:[${kernel}] tunnel:[${tunnel}]"
        error_msg "Missing repack parameters (Check target string match in variables step)"
    fi
    
    local BRANCH="${GITHUB_REF_NAME:-main}"
    [[ "${GITHUB_REF_TYPE:-branch}" != "branch" ]] && BRANCH="main"
    
    local work_dir="$GITHUB_WORKSPACE/$WORKING_DIR" 
    local output_dir="${work_dir}/compiled_images"
    local url="https://github.com/syntax-xidz/ULO-Builder/archive/refs/heads/${BRANCH}.zip"
    local b_dir="${work_dir}/ULO-Builder-${BRANCH}"
    
    if [[ "$b_type" == "--ophub" ]]; then
        url="https://github.com/syntax-xidz/amlogic-s9xxx-openwrt/archive/refs/heads/${BRANCH}.zip"
        b_dir="${work_dir}/amlogic-s9xxx-openwrt-${BRANCH}"
    fi
    
    cd "${work_dir}"
    if ! ariadl "${url}" "${BRANCH}.zip"; then
        if [[ "$b_type" == "--ophub" ]]; then 
            b_dir="${work_dir}/amlogic-s9xxx-openwrt-main"
            url="https://github.com/syntax-xidz/amlogic-s9xxx-openwrt/archive/refs/heads/main.zip"
        else 
            b_dir="${work_dir}/ULO-Builder-main"
            url="https://github.com/syntax-xidz/ULO-Builder/archive/refs/heads/main.zip"
        fi
        ariadl "${url}" "main.zip"
    fi
    
    unzip -q "*.zip" && rm -f *.zip
    [[ "$b_type" == "--ophub" ]] && mkdir -p "${b_dir}/openwrt-armsr" || mkdir -p "${b_dir}/rootfs"
    
    local rf_files=("${output_dir}/"*"_${tunnel}-rootfs.tar.gz")
    [[ ${#rf_files[@]} -ne 1 ]] && error_msg "Rootfs count mismatch"
    
    local t_path="${b_dir}/rootfs/${BASE}-armsr-armv8-generic-rootfs.tar.gz"
    [[ "$b_type" == "--ophub" ]] && t_path="${b_dir}/openwrt-armsr/${BASE}-armsr-armv8-generic-rootfs.tar.gz"
    cp -f "${rf_files[0]}" "${t_path}"
    cd "${b_dir}"
    
    if [[ "$b_type" == "--ophub" ]]; then
        sudo ./remake -b "$board" -k "$kernel" -s "$rootfs_size"
        cp -rf ./openwrt/out/* "${output_dir}/"
    else
        [ -f "./.github/workflows/ULO_Workflow.patch" ] && patch -p1 < ./.github/workflows/ULO_Workflow.patch
        sudo ./ulo -y -m "$board" -r $(basename "${t_path}") -k "$kernel" -s "$rootfs_size"
        cp -rf "./out/${board}"/* "${output_dir}/"
    fi
    sudo rm -rf "${b_dir}"
    log "SUCCESS" "Image repacking completed"
}

# modsdcard for b860h and hg680p
run_modsdcard() {
    # compile specific and patch loop device
    build_mod_sdcard() {
        local image_path="$1"
        local dtb="$2"
        local suffix="$3"

        # extract kernel early for precise logging
        local file_name=$(basename "${image_path%.gz}")
        local kernel=$(grep -oP 'k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)?' <<<"${file_name}")
        local kernel_clean="${kernel#k}"
        local log_target="${suffix}-${kernel_clean}"

        log "INFO" "modifying boot config for ${log_target}"
        
        if [ -z "$suffix" ] || [ -z "$dtb" ] || [ -z "$image_path" ]; then
            error_msg "missing io parameters for ${log_target}"
            return 1
        fi

        cd "$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images" || return 1
        local file_to_process="$image_path"

        # drop loop allocations safely on exit
        cleanup() {
            sudo umount boot 2>/dev/null || true
            sudo losetup -D 2>/dev/null || true
        }
        trap cleanup EXIT

        [ ! -f "$file_to_process" ] && { error_msg "payload not found for ${log_target}"; return 1; }

        # retrieve mod package resources
        ariadl "https://github.com/rizkikotet-dev/mod-boot-sdcard/archive/refs/heads/main.zip" "main.zip"
        unzip -q main.zip || { error_msg "failed to extract mod files for ${log_target}"; return 1; }
        rm -f main.zip
        sleep 3

        mkdir -p "${suffix}/boot"
        cp "$file_to_process" "${suffix}/"
        sudo cp mod-boot-sdcard-main/BootCardMaker/u-boot.bin mod-boot-sdcard-main/files/mod-boot-sdcard.tar.gz "${suffix}/" || { error_msg "failed to copy bootloader for ${log_target}"; return 1; }
        cd "${suffix}" || return 1

        sudo gunzip "${file_name}.gz" || { error_msg "failed to decompress image for ${log_target}"; return 1; }

        # bind active image array pointer
        local device=""
        for i in {1..3}; do
            device=$(sudo losetup -fP --show "${file_name}" 2>/dev/null)
            [ -n "$device" ] && break
            sleep 1
        done
        [ -z "$device" ] && { error_msg "loop device binding failed for ${log_target}"; return 1; }

        local attempts=0
        while [ $attempts -lt 3 ]; do
            sudo mount "${device}p1" boot && break
            attempts=$((attempts + 1))
            sleep 1
        done
        [ $attempts -eq 3 ] && { error_msg "partition mount timeout for ${log_target}"; return 1; }

        sudo tar -xzf mod-boot-sdcard.tar.gz -C boot || { error_msg "failed to extract boot modifications for ${log_target}"; return 1; }

        # refactor u-boot config maps
        local uenv=$(sudo cat boot/uEnv.txt | grep APPEND | awk -F "root=" '{print $2}')
        local extlinux=$(sudo cat boot/extlinux/extlinux.conf | grep append | awk -F "root=" '{print $2}')
        local boot=$(sudo cat boot/boot.ini | grep dtb | awk -F "/" '{print $4}' | cut -d'"' -f1)

        sudo sed -i "s|$extlinux|$uenv|g" boot/extlinux/extlinux.conf
        sudo sed -i "s|$boot|$dtb|g" boot/boot.ini
        sudo sed -i "s|$boot|$dtb|g" boot/extlinux/extlinux.conf
        sudo sed -i "s|$boot|$dtb|g" boot/uEnv.txt

        sync
        sudo umount boot

        # dd direct loader segments
        sudo dd if=u-boot.bin of="${device}" bs=1 count=444 conv=fsync 2>/dev/null || { error_msg "failed to write u-boot header for ${log_target}"; return 1; }
        sudo dd if=u-boot.bin of="${device}" bs=512 skip=1 seek=1 conv=fsync 2>/dev/null || { error_msg "failed to write u-boot body for ${log_target}"; return 1; }

        # unbind and compress payload
        sudo losetup -d "${device}"
        sudo gzip "${file_name}" || { error_msg "failed to compress image for ${log_target}"; return 1; }
        [ -f "../${file_name}.gz" ] && rm -rf "../${file_name}.gz"

        # format output artifact metadata
        local new_name="XIDZsOs-${OP_BASE}-${BRANCH}-${suffix}-${kernel}-${TUNNEL}-${DATE}-MODSDCARD.img.gz"

        mv "${file_name}.gz" "../${new_name}" || { error_msg "failed to rename image file for ${log_target}"; return 1; }

        cd ..
        rm -rf "${suffix}" mod-boot-sdcard-main
        cleanup
        log "SUCCESS" "sdcard modifier applied to ${log_target}"
        return 0
    }

    # iterate build array vectors and dynamically process all matching kernel versions
    process_builds() {
        local img_dir="$1"
        local builds=("${@:2}")
        local exit_code=0
        
        for build in "${builds[@]}"; do
            IFS=: read -r device dtb model <<< "$build"
            
            # fetch all artifacts matching the device base string, excluding already modified payloads
            local image_files=($(find "$img_dir" -maxdepth 1 -type f -name "*${device}*.img.gz" ! -name "*-MODSDCARD.img.gz"))
            
            if ((${#image_files[@]} > 0)); then
                for img in "${image_files[@]}"; do
                    if ! build_mod_sdcard "$img" "$dtb" "$model"; then
                        local img_name=$(basename "$img")
                        local krnl=$(grep -oP 'k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)?' <<<"${img_name}")
                        error_msg "subroutine failed for ${model}-${krnl#k}"
                        exit_code=1
                    fi
                done
            else
                log "WARNING" "artifact omitted for $model ($device)"
            fi
        done
        
        return $exit_code
    }

    local img_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    local builds=()
    
    # isolate logic for specific targets
    if [[ "$MATRIXTARGET" == *"Amlogic s905x HG680P"* && "$MATRIXTARGET" == *"MODSDCARD"* ]]; then
        local p_suffix="s905x_HG680P-WIFION"
        local p_prefix="_s905x-wifion"
        if [[ "$MATRIXTARGET" == *"WIFIOFF"* ]]; then
            p_suffix="s905x_HG680P-WIFIOFF"
            p_prefix="_s905x"
        fi
        
        # generic device to dtb bypassing hardcoded kernel versions
        builds=(
            "${p_prefix}_:meson-gxl-s905x-p212.dtb:${p_suffix}"
        )
    elif [[ "$MATRIXTARGET" == *"Amlogic s905x B860H"* && "$MATRIXTARGET" == *"MODSDCARD"* ]]; then
        local p_suffix="s905x_B860H-WIFION"
        local p_prefix="_s905x-b860h-wifion"
        if [[ "$MATRIXTARGET" == *"WIFIOFF"* ]]; then
            p_suffix="s905x_B860H-WIFIOFF"
            p_prefix="_s905x-b860h"
        fi
        
        # generic device to dtb bypassing hardcoded kernel versions
        builds=(
            "${p_prefix}_:meson-gxl-s905x-b860h.dtb:${p_suffix}"
        )
    fi
    
    [ ${#builds[@]} -eq 0 ] && return 0
    [ ! -d "$img_dir" ] && { error_msg "directory trace missing: $img_dir"; return 1; }
    
    process_builds "$img_dir" "${builds[@]}"
    return $?
}

# clean and rename output images
run_rename() {
    log "INFO" "Renaming compiled images"
    local f_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    cd "${f_dir}" || error_msg "Failed to change directory"
    
    local patterns=(
        "-bcm27xx-bcm2708-rpi-ext4-factory|RaspberryPi_1B-Ext4_Factory"
        "-bcm27xx-bcm2708-rpi-ext4-sysupgrade|RaspberryPi_1B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2708-rpi-squashfs-factory|RaspberryPi_1B-Squashfs_Factory"
        "-bcm27xx-bcm2708-rpi-squashfs-sysupgrade|RaspberryPi_1B-Squashfs_Sysupgrade"
        "-bcm27xx-bcm2709-rpi-2-ext4-factory|RaspberryPi_2B-Ext4_Factory"
        "-bcm27xx-bcm2709-rpi-2-ext4-sysupgrade|RaspberryPi_2B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2709-rpi-2-squashfs-factory|RaspberryPi_2B-Squashfs_Factory"
        "-bcm27xx-bcm2709-rpi-2-squashfs-sysupgrade|RaspberryPi_2B-Squashfs_Sysupgrade"
        "-bcm27xx-bcm2710-rpi-3-ext4-factory|RaspberryPi_3B-Ext4_Factory"
        "-bcm27xx-bcm2710-rpi-3-ext4-sysupgrade|RaspberryPi_3B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2710-rpi-3-squashfs-factory|RaspberryPi_3B-Squashfs_Factory"
        "-bcm27xx-bcm2710-rpi-3-squashfs-sysupgrade|RaspberryPi_3B-Squashfs_Sysupgrade"
        "-bcm27xx-bcm2711-rpi-4-ext4-factory|RaspberryPi_4B-Ext4_Factory"
        "-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade|RaspberryPi_4B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2711-rpi-4-squashfs-factory|RaspberryPi_4B-Squashfs_Factory"
        "-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade|RaspberryPi_4B-Squashfs_Sysupgrade"
        "-bcm27xx-bcm2712-rpi-5-ext4-factory|RaspberryPi_5-Ext4_Factory"
        "-bcm27xx-bcm2712-rpi-5-ext4-sysupgrade|RaspberryPi_5-Ext4_Sysupgrade"
        "-bcm27xx-bcm2712-rpi-5-squashfs-factory|RaspberryPi_5-Squashfs_Factory"
        "-bcm27xx-bcm2712-rpi-5-squashfs-sysupgrade|RaspberryPi_5-Squashfs_Sysupgrade"
        "-widora_mangopi-m28c-ext4-sysupgrade|Widora_Mangopi-M28C-Ext4-Sysupgrade"
        "-widora_mangopi-m28c-squashfs-sysupgrade|Widora_Mangopi-M28C-Squashfs-Sysupgrade"
        "-widora_mangopi-m28k-ext4-sysupgrade|Widora_Mangopi-M28K-Ext4-Sysupgrade"
        "-widora_mangopi-m28k-squashfs-sysupgrade|Widora_Mangopi-M28K-Squashfs-Sysupgrade"       
        "-xunlong_orangepi-r1-plus-lts-squashfs-sysupgrade|OrangePi-R1-Plus-LTS-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-lts-ext4-sysupgrade|OrangePi-R1-Plus-LTS-ext4-sysupgrade"
        "-xunlong_orangepi-r1-plus-squashfs-sysupgrade|OrangePi-R1-Plus-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-ext4-sysupgrade|OrangePi-R1-Plus-ext4-sysupgrade"
        "-xunlong_orangepi-pc2-squashfs-sdcard|OrangePi-Pc2-squashfs-sdcard"
        "-xunlong_orangepi-pc2-ext4-sdcard|OrangePi-Pc2-ext4-sdcard"
        "-xunlong_orangepi-zero-plus-squashfs-sdcard|OrangePi-Zero-Plus-squashfs-sdcard"
        "-xunlong_orangepi-zero-plus-ext4-sdcard|OrangePi-Zero-Plus-ext4-sdcard"
        "-xunlong_orangepi-zero2-squashfs-sdcard|OrangePi-Zero2-squashfs-sdcard"
        "-xunlong_orangepi-zero2-ext4-sdcard|OrangePi-Zero2-ext4-sdcard"
        "-xunlong_orangepi-zero3-squashfs-sdcard|OrangePi-Zero3-squashfs-sdcard"
        "-xunlong_orangepi-zero3-ext4-sdcard|OrangePi-Zero3-ext4-sdcard"
        "-friendlyarm_nanopi-r2c-ext4-sysupgrade|Nanopi-R2C-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-ext4-sysupgrade|Nanopi-R2C-Plus-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2s-ext4-sysupgrade|Nanopi-R2S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2s-plus-ext4-sysupgrade|Nanopi-R2S-Plus-ext4-sysupgrade"
        "-friendlyarm_nanopi-r3s-ext4-sysupgrade|Nanopi-R3S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r4s-ext4-sysupgrade|Nanopi-R4S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r5s-ext4-sysupgrade|Nanopi-R5S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r6s-ext4-sysupgrade|Nanopi-R6S-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo2-ext4-sysupgrade|Nanopi-Neo2-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-ext4-sysupgrade|Nanopi-Neo-Plus2-ext4-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-ext4-sysupgrade|Nanopi-R1-H5-ext4-sysupgrade"
        "-firefly_roc-rk3328-cc-ext4-sysupgrade|Firefly_Roc-RK3328-CC-ext4-sysupgrade"
        "-firefly_roc-rk3328-cc-squashfs-sysupgrade|Firefly_Roc-RK3328-CC-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-squashfs-sysupgrade|Nanopi-R2C-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-squashfs-sysupgrade|Nanopi-R2C-Plus-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2s-squashfs-sysupgrade|Nanopi-R2S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2s-plus-squashfs-sysupgrade|Nanopi-R2S-Plus-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r3s-squashfs-sysupgrade|Nanopi-R3S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r4s-squashfs-sysupgrade|Nanopi-R4S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r5s-squashfs-sysupgrade|Nanopi-R5S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r6s-squashfs-sysupgrade|Nanopi-R6S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo2-squashfs-sysupgrade|Nanopi-Neo2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-squashfs-sysupgrade|Nanopi-Neo-Plus2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-squashfs-sysupgrade|Nanopi-R1S-H5-squashfs-sysupgrade"
        "x86-64-generic-ext4-combined-efi|X86_64_Generic_Ext4_Combined_EFI"
        "x86-64-generic-ext4-combined|X86_64_Generic_Ext4_Combined"
        "x86-64-generic-ext4-rootfs|X86_64_Generic_Ext4_Rootfs"
        "x86-64-generic-squashfs-combined-efi|X86_64_Generic_Squashfs_Combined_EFI"
        "x86-64-generic-squashfs-combined|X86_64_Generic_Squashfs_Combined"
        "x86-64-generic-squashfs-rootfs|X86_64_Generic_Squashfs_Rootfs"
        "x86-64-generic-rootfs|X86_64_Generic_Rootfs"
        "x86-generic-generic-ext4-combined-efi|X86_32_Generic_Ext4_Combined_EFI"
        "x86-generic-generic-ext4-combined|X86_32_Generic_Ext4_Combined"
        "x86-generic-generic-ext4-rootfs|X86_32_Generic_Ext4_Rootfs"
        "x86-generic-generic-squashfs-combined-efi|X86_32_Generic_Squashfs_Combined_EFI"
        "x86-generic-generic-squashfs-combined|X86_32_Generic_Squashfs_Combined"
        "x86-generic-generic-squashfs-rootfs|X86_32_Generic_Squashfs_Rootfs"
        "x86-generic-generic-rootfs|X86_32_Generic_Rootfs"
        "-h5-orangepi-pc2-|OrangePi_PC2"
        "-h5-orangepi-prime-|OrangePi_Prime"
        "-h5-orangepi-zeroplus-|OrangePi_ZeroPlus"
        "-h5-orangepi-zeroplus2-|OrangePi_ZeroPlus2"
        "-h6-orangepi-1plus-|OrangePi_1Plus"
        "-h6-orangepi-3-|OrangePi_3"
        "-h6-orangepi-3lts-|OrangePi_3LTS"
        "-h6-orangepi-lite2-|OrangePi_Lite2"
        "-h616-orangepi-zero2-|OrangePi_Zero2"
        "-h618-orangepi-zero2w-|OrangePi_Zero2W"
        "-h618-orangepi-zero3-|OrangePi_Zero3"
        "-rk3566-orangepi-3b-|OrangePi_3B"
        "-rk3588s-orangepi-5-|OrangePi_5"
        "-firefly_roc-rk3328-cc-|Firefly-RK3328"
        "-s905x-b860h-|s905x-B860H"
        "-s905x-hg680p-|s905x-HG680P"
        "-s905x2-b860hv5-|s905x2-B860H-V5"
        "-s905x2-hg680fj-|s905x2-HG680-FJ"
        "-s905x2-b860h-v5-v2|s905x2-B860H-V5"
        "-s905x2-hg680-fj-v2|s905x2-HG680-FJ"
        "-s905x3-|s905x3"
        "-s905x4-|s905x4_AT01-Ax810"
        "_s905x-wifion_|s905x_HG680P-WIFION"
        "_s905x-b860h-wifion_|s905x_B860H-WIFION"
        "_s905x_|s905x_HG680P-WIFIOFF"
        "_s905x-b860h_|s905x_B860H-WIFIOFF"
        "_s905d_|s905d_Phicomm-N1"
        "_s905l-mg101_|s905l_Mibox-4"
        "_s905l_|s905l_B860AV2"
        "_s905l2_|s905l2_M301A"
        "_s905l3_|s905l3_HG680-LC"
        "_s905l3b-e900v22e_|s905l3b_MGV2000"
        "_s905lb-q96-mini_|s905lb_Q96-mini"
        "_s905l3a-m401a_|s905l3a_B863AV3"
        "_s905-beelink-mini_|s905_Beelink-Mini"
        "_s905-mxqpro-plus_|s905_MXQ-Pro+"
        "_s922x-gtking_|s922x_GtKing"
        "_s922x_|s922x_GtKing-Pro"
        "_s922x-gtkingpro-h_|s922x_GtKing-Pro-H"
        "_s922x-ugoos-am6_|s922x_UGOOS-AM6-Plus"
        "_s912-nexbox-a1_|s912_Nexbox-A1-A95X"
        "_s912-nexbox-a2_|s912_Nexbox-A95X-A2"
        "_s905l2_|s905l2_MGV_M301A"
        "_s905x2-x96max-2g_|s905x2-x96Max2Gb-A95X-F2"
        "_s905x2_|s905x2_x96Max-4Gb-Tx5-Max"
        "_s905x2-b860h-v5_|s905x2_B860H_V5"
        "_s905x2-hg680-fj_|s905x2_HG680_FJ"
        "_s905x3-x96air_|s905x3-X96Air100M"
        "_s905x3-x96air-gb_|s905x3-x96Air1Gbps"
        "_s905x3-hk1_|s905x3-HK1BOX"
        "_s905x3_|s905x3_X96MAX+_100Mb"
        "_s905x3-x96max_|s905x3_X96MAX+_1Gb"
        "_s905x3-a95xf3-gb_|s905x3_A95xF3-1Gb"
        "_s905x3-a95xf3_|s905x3_A95xF3-100M"
        "_s905x3-x88-pro-x3_|s905x3_X88-Pro-X3"
        "_s905x3-h96max_|s905x3_H96-Max-X3"
        "_s905x4-advan_|s905x4_AT01-AX810"
        "_s905w_|s905w_TX3_Mini"
        "_s905w-x96-mini_|s905w-X96-Mini"
        "_s905w-x96w_|s905w-X96W"
        "_s912-t95z-plus_|s912-T95Z-Plus"
        "_x98h_|X98H-H618"
        "_s912-tx9-pro-3g_|s912-Tx9-Pro-1Gb"
        "_s912-tx9-pro-2g_|s912-Tx9-Pro-100M"
        "_allwinner_orangepi-3_|OrangePi_3"
        "_allwinner_orangepi-zplus_|OrangePi_ZeroPlus"
        "_allwinner_orangepi-zplus2_|OrangePi_ZeroPlus2"
        "_allwinner_orangepi-zero2_|OrangePi_Zero2"
        "_allwinner_orangepi-zero3_|OrangePi_Zero3"
        "_allwinner_tanix-tx6_|Tanix-TX6"
        "_rk3318-box_|rk3318-Box"
        "_renegade-rk3328_|Firefly-RK3328"
        "_panther-x2_|rk3566-Panther-X2"
        "_rock5b_|rk3588-Rock5B"
        "_king3399_|rk3399-King3399"
        "_nanopi-m5_|rk3576-NanoPi-M5"
        "_h96-max-m2_|rk3528-H96-Max-M2"
        "_orangepi-5b_|rk3588s-OrangePi_5B"
        "_orangepi-5-plus_|rk3588-OrangePi_5Plus"
        "_nanopi-r5s_|Nanopi-r5s"
        "_nanopi-r5c_|Nanopi-r5c"
    )

    for item in "${patterns[@]}"; do
        local search="${item%%|*}" replace="${item##*|}"
        for file in *"${search}"*.img.gz; do
            if [[ -f "$file" ]]; then
                local kernel=""
                if [[ "$file" =~ k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)? ]]; then kernel="${BASH_REMATCH[0]}"; fi
                local new_name="XIDZsOs-${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}-${DATE}.img.gz"
                if [[ -n "$kernel" ]]; then new_name="XIDZsOs-${OP_BASE}-${BRANCH}-${replace}-${kernel}-${TUNNEL}-${DATE}.img.gz"; fi
                log "INFO" "Renaming $file → $new_name"
                mv "$file" "$new_name" || log "WARN" "Failed to rename $file"
            fi
        done
        for file in *"${search}"*.tar.gz; do
            if [[ -f "$file" ]]; then
                local new_name="XIDZsOs-${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}-${DATE}.img.gz"
                log "INFO" "Renaming $file → $new_name"
                mv "$file" "$new_name" || log "WARN" "Failed to rename $file"
            fi
        done
    done
    sync && sleep 3
    log "SUCCESS" "Image renaming completed"
}

# script execution matrix
case "${1:-}" in
    misc) run_misc ;;
    patch) shift; run_patch "$@" ;;
    packages) run_packages ;;
    tunnel) shift; run_tunnel "$@" ;;
    makeimage) shift; run_makeimage "$@" ;;
    repack) shift; run_repack "$@" ;;
    modsdcard) run_modsdcard ;;
    rename) run_rename ;;
    *) echo "Usage $0 {misc|patch|packages|tunnel|makeimage|repack|modsdcard|rename}" ; exit 1 ;;
esac