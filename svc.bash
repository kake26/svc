#!/bin/sh

# svc.sh - Unified service and package management wrapper for systemd, OpenRC (Devuan), and OpenRC (Alpine)
# Usage: svc.sh <command> [service|package]

# Detect init system
if [ -f /run/systemd/system ] || command -v systemctl >/dev/null || grep -q systemd /proc/1/comm; then
    INIT_SYSTEM="systemd"
elif [ -f /sbin/openrc ]; then
    if grep -qi "alpine" /etc/os-release; then
        INIT_SYSTEM="openrc-alpine"
    else
        INIT_SYSTEM="openrc"
    fi
else
    echo "Unsupported init system"
    exit 1
fi

# Detect package manager
if command -v apt >/dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null; then
    PKG_MANAGER="dnf"
elif command -v pacman >/dev/null; then
    PKG_MANAGER="pacman"
elif command -v apk >/dev/null; then
    PKG_MANAGER="apk"
else
    PKG_MANAGER="none"
fi

# Service management functions
case "$INIT_SYSTEM" in
    systemd)
        svc_start() { systemctl start "$1"; }
        svc_stop() { systemctl stop "$1"; }
        svc_enable() { systemctl enable "$1"; }
        svc_disable() { systemctl disable "$1"; }
        svc_status() { systemctl status "$1"; }
        svc_list() { systemctl list-units --type=service --state=running; }
        ;;
    openrc)
        svc_start() { service "$1" start; }
        svc_stop() { service "$1" stop; }
        svc_enable() { rc-update add "$1" default; }
        svc_disable() { rc-update del "$1" default; }
        svc_status() { service "$1" status; }
        svc_list() { rc-status -a; }
        ;;
    openrc-alpine)
        svc_start() { rc-service "$1" start; }
        svc_stop() { rc-service "$1" stop; }
        svc_enable() { rc-update add "$1" default; }
        svc_disable() { rc-update del "$1" default; }
        svc_status() { rc-service "$1" status; }
        svc_list() { rc-status; }
        ;;
esac

# Package management functions
case "$PKG_MANAGER" in
    apt)
        pkg_install() { apt install -y "$1"; }
        pkg_remove() { apt remove -y "$1"; }
        pkg_update() { apt update && apt upgrade -y; }
        pkg_search() { apt search "$1"; }
        ;;
    dnf)
        pkg_install() { dnf install -y "$1"; }
        pkg_remove() { dnf remove -y "$1"; }
        pkg_update() { dnf upgrade -y; }
        pkg_search() { dnf search "$1"; }
        ;;
    pacman)
        pkg_install() { pacman -S --noconfirm "$1"; }
        pkg_remove() { pacman -R --noconfirm "$1"; }
        pkg_update() { pacman -Syu --noconfirm; }
        pkg_search() { pacman -Ss "$1"; }
        ;;
    apk)
        pkg_install() { apk add "$1"; }
        pkg_remove() { apk del "$1"; }
        pkg_update() { apk update && apk upgrade; }
        pkg_search() { apk search "$1"; }
        ;;
    none)
        pkg_install() { echo "No package manager detected"; exit 1; }
        pkg_remove() { echo "No package manager detected"; exit 1; }
        pkg_update() { echo "No package manager detected"; exit 1; }
        pkg_search() { echo "No package manager detected"; exit 1; }
        ;;
esac

# Main command handler
case "$1" in
    start)
        [ -z "$2" ] && { echo "Usage: $0 start <service>"; exit 1; }
        svc_start "$2"
        ;;
    stop)
        [ -z "$2" ] && { echo "Usage: $0 stop <service>"; exit 1; }
        svc_stop "$2"
        ;;
    enable)
        [ -z "$2" ] && { echo "Usage: $0 enable <service>"; exit 1; }
        svc_enable "$2"
        ;;
    disable)
        [ -z "$2" ] && { echo "Usage: $0 disable <service>"; exit 1; }
        svc_disable "$2"
        ;;
    status)
        [ -z "$2" ] && { echo "Usage: $0 status <service>"; exit 1; }
        svc_status "$2"
        ;;
    list)
        svc_list
        ;;
    install)
        [ -z "$2" ] && { echo "Usage: $0 install <package>"; exit 1; }
        pkg_install "$2"
        ;;
    remove)
        [ -z "$2" ] && { echo "Usage: $0 remove <package>"; exit 1; }
        pkg_remove "$2"
        ;;
    update)
        pkg_update
        ;;
    search)
        [ -z "$2" ] && { echo "Usage: $0 search <package>"; exit 1; }
        pkg_search "$2"
        ;;
    *)
        echo "Usage: $0 {start|stop|enable|disable|status|list|install|remove|update|search} [service|package]"
        exit 1
        ;;
esac