#!/bin/bash

# Unified service management wrapper for systemd and OpenRC

# Function to detect init system
detect_init_system() {
    if command -v systemctl >/dev/null 2>&1 && pgrep systemd >/dev/null; then
        echo "systemd"
    elif command -v rc-service >/dev/null 2>&1; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 {start|stop|restart|enable|disable|status|list} [service]"
    echo "Commands:"
    echo "  start   - Start a service"
    echo "  stop    - Stop a service"
    echo "  restart - Restart a service"
    echo "  enable  - Enable a service to start at boot"
    echo "  disable - Disable a service from starting at boot"
    echo "  status  - Check the status of a service"
    echo "  list    - List all services and their status"
    exit 1
}

# Check for sufficient arguments
if [ $# -lt 1 ]; then
    usage
fi

COMMAND="$1"
SERVICE="$2"
INIT_SYSTEM=$(detect_init_system)

# Exit if init system is not supported
if [ "$INIT_SYSTEM" = "unknown" ]; then
    echo "Error: Unsupported init system. Only systemd and OpenRC are supported."
    exit 1
fi

# Map unified commands to init-specific commands
case "$INIT_SYSTEM" in
    systemd)
        case "$COMMAND" in
            start)
                [ -z "$SERVICE" ] && usage
                systemctl start "$SERVICE"
                ;;
            stop)
                [ -z "$SERVICE" ] && usage
                systemctl stop "$SERVICE"
                ;;
            restart)
                [ -z "$SERVICE" ] && usage
                systemctl restart "$SERVICE"
                ;;
            enable)
                [ -z "$SERVICE" ] && usage
                systemctl enable "$SERVICE"
                ;;
            disable)
                [ -z "$SERVICE" ] && usage
                systemctl disable "$SERVICE"
                ;;
            status)
                [ -z "$SERVICE" ] && usage
                systemctl status "$SERVICE"
                ;;
            list)
                if [ -n "$SERVICE" ]; then
                    echo "Error: 'list' command does not take a service argument."
                    usage
                fi
                systemctl list-units --type=service --all --no-pager --no-legend | \
                    awk '$1 !~ /^●$/ && $1 != "" {if ($2 == "not-found") print $1, "not-found"; else if ($3 == "active" && $4 == "running") print $1, "running"; else if ($3 == "active" && $4 == "exited") print $1, "exited"; else print $1, "stopped"}' | \
                    column -t
                ;;
            *)
                usage
                ;;
        esac
        ;;
    openrc)
        case "$COMMAND" in
            start)
                [ -z "$SERVICE" ] && usage
                rc-service "$SERVICE" start
                ;;
            stop)
                [ -z "$SERVICE" ] && usage
                rc-service "$SERVICE" stop
                ;;
            restart)
                [ -z "$SERVICE" ] && usage
                rc-service "$SERVICE" restart
                ;;
            enable)
                [ -z "$SERVICE" ] && usage
                rc-update add "$SERVICE" default
                ;;
            disable)
                [ -z "$SERVICE" ] && usage
                rc-update del "$SERVICE" default
                ;;
            status)
                [ -z "$SERVICE" ] && usage
                rc-service "$SERVICE" status
                ;;
            list)
                if [ -n "$SERVICE" ]; then
                    echo "Error: 'list' command does not take a service argument."
                    usage
                fi
                for svc in $(rc-service -l); do
                    status=$(rc-service "$svc" status | grep -q "started" && echo "running" || echo "stopped")
                    echo "$svc $status"
                done | column -t
                ;;
            *)
                usage
                ;;
        esac
        ;;
esac

# Check command execution status
if [ $? -eq 0 ]; then
    if [ "$COMMAND" != "list" ] && [ "$COMMAND" != "status" ]; then
        echo "$COMMAND on $SERVICE ($INIT_SYSTEM) completed successfully."
    fi
else
    echo "Error: Failed to execute $COMMAND on $SERVICE ($INIT_SYSTEM)."
    exit 1
fi