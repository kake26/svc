#!/bin/bash

# svc.sh: Unified wrapper for OpenRC, systemd, and package management (apt, dnf, pacman)

# Exit on error
set -e

# Detect package manager
detect_pkg_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "none"
        exit 1
    fi
}

# Package management functions
pkg_install() {
    local pkg="$1"
    case $(detect_pkg_manager) in
        apt)
            sudo apt install -y "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        *)
            echo "Error: No supported package manager found."
            exit 1
            ;;
    esac
}

pkg_remove() {
    local pkg="$1"
    case $(detect_pkg_manager) in
        apt)
            sudo apt remove -y "$pkg"
            ;;
        dnf)
            sudo dnf remove -y "$pkg"
            ;;
        pacman)
            sudo pacman -R --noconfirm "$pkg"
            ;;
        *)
            echo "Error: No supported package manager found."
            exit 1
            ;;
    esac
}

pkg_update() {
    case $(detect_pkg_manager) in
        apt)
            sudo apt update
            ;;
        dnf)
            sudo dnf check-update
            ;;
        pacman)
            sudo pacman -Sy
            ;;
        *)
            echo "Error: No supported package manager found."
            exit 1
            ;;
    esac
}

pkg_search() {
    local pkg="$1"
    case $(detect_pkg_manager) in
        apt)
            apt search "$pkg"
            ;;
        dnf)
            dnf search "$pkg"
            ;;
        pacman)
            pacman -Ss "$pkg"
            ;;
        *)
            echo "Error: No supported package manager found."
            exit 1
            ;;
    esac
}

# Service management functions
service_cmd() {
    local svc="$1"
    local action="$2"
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl "$action" "$svc"
    elif command -v rc-service >/dev/null 2>&1; then
        sudo rc-service "$svc" "$action"
    else
        echo "Error: Neither systemd nor OpenRC found."
        exit 1
    fi
}

service_list() {
    if command -v systemctl >/dev/null 2>&1; then
        # List systemd services with status, using original clean logic
        systemctl list-units --type=service --all --no-pager --no-legend | \
            awk '$1 !~ /^●$/ && $1 != "" {if ($2 == "not-found") print $1, "not-found"; else if ($3 == "active" && $4 == "running") print $1, "running"; else if ($3 == "active" && $4 == "exited") print $1, "exited"; else print $1, "stopped"}' | \
            column -t
    elif command -v rc-service >/dev/null 2>&1; then
        # List OpenRC services with status
        for svc in $(rc-service -l); do
            status=$(rc-service "$svc" status 2>/dev/null | grep -o 'started\|stopped\|crashed' || echo "unknown")
            echo "$svc $status"
        done | column -t
    else
        echo "Error: Neither systemd nor OpenRC found."
        exit 1
    fi
}

# Main logic
case "$1" in
    pkg)
        case "$2" in
            install)
                pkg_install "$3"
                ;;
            remove)
                pkg_remove "$3"
                ;;
            update)
                pkg_update
                ;;
            search)
                pkg_search "$3"
                ;;
            *)
                echo "Usage: svc pkg {install|remove|update|search} [package]"
                exit 1
                ;;
        esac
        ;;
    start|stop|restart|enable|disable)
        service_cmd "$2" "$1"
        ;;
    list)
        service_list
        ;;
    *)
        echo "Usage: svc {start|stop|restart|enable|disable} <service> | svc list | svc pkg {install|remove|update|search} [package]"
        exit 1
        ;;
esac
