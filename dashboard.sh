#!/bin/bash

# dashboard.sh - A system resource monitoring dashboard

# Refresh interval in seconds
REFRESH_INTERVAL=5

# Function to display the top 10 CPU and Memory consuming applications
show_top_apps() {
    echo "Top 10 CPU Consuming Applications:"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 11
    echo ""
    echo "Top 10 Memory Consuming Applications:"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 11
    echo ""
}

# Function to display network statistics
show_network() {
    echo "Network Monitoring:"
    # Number of concurrent connections to the server (assuming server is listening on any port)
    CONN_COUNT=$(ss -s | grep "TCP:" | awk '{print $2}')
    echo "Number of concurrent TCP connections: $CONN_COUNT"

    # Packet drops from /proc/net/dev
    RX_DROP=$(grep "bytes" /proc/net/dev | awk '{print $4}')
    TX_DROP=$(grep "bytes" /proc/net/dev | awk '{print $12}')
    echo "Packet Drops - RX: $RX_DROP, TX: $TX_DROP"

    # Number of MB in and out
    IFACES=$(ls /sys/class/net | grep -v lo)
    for IFACE in $IFACES; do
        RX_BYTES=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
        TX_BYTES=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
        RX_MB=$(echo "scale=2; $RX_BYTES / 1048576" | bc)
        TX_MB=$(echo "scale=2; $TX_BYTES / 1048576" | bc)
        echo "$IFACE: Received: ${RX_MB}MB, Transmitted: ${TX_MB}MB"
    done
    echo ""
}

# Function to display disk usage
show_disk() {
    echo "Disk Usage:"
    df -h | awk 'NR==1 || $5+0 > 0' | while read line; do
        USAGE=$(echo $line | awk '{print $5}' | tr -d '%')
        if [ "$USAGE" -ge 80 ] && [ NR != 1 ]; then
            echo -e "\e[31m$line\e[0m"  # Highlight in red
        else
            echo "$line"
        fi
    done
    echo ""
}

# Function to display system load and CPU usage
show_system_load() {
    echo "System Load:"
    LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    echo "Load Average (1, 5, 15 minutes): $LOAD_AVG"

    # CPU usage breakdown
    CPU_LINE=$(top -bn1 | grep "Cpu(s)")
    USR=$(echo $CPU_LINE | awk -F',' '{print $1}' | awk '{print $2}')
    SYS=$(echo $CPU_LINE | awk -F',' '{print $3}' | awk '{print $2}')
    IDLE=$(echo $CPU_LINE | awk -F',' '{print $4}' | awk '{print $2}')
    IOWAIT=$(echo $CPU_LINE | awk -F',' '{print $5}' | awk '{print $2}')
    echo "CPU Usage:"
    echo "  User: $USR%"
    echo "  System: $SYS%"
    echo "  Idle: $IDLE%"
    echo "  I/O Wait: $IOWAIT%"
    echo ""
}

# Function to display memory usage
show_memory() {
    echo "Memory Usage:"
    free -h
    echo ""
}

# Function to display process monitoring
show_processes() {
    echo "Process Monitoring:"
    ACTIVE_PROCESSES=$(ps aux | wc -l)
    echo "Number of active processes: $ACTIVE_PROCESSES"

    echo ""
    echo "Top 5 Processes by CPU Usage:"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6
    echo ""
    echo "Top 5 Processes by Memory Usage:"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 6
    echo ""
}

# Function to display service monitoring
show_services() {
    echo "Service Monitoring:"
    SERVICES=("sshd" "nginx" "apache2" "iptables")
    for SERVICE in "${SERVICES[@]}"; do
        if systemctl list-units --type=service | grep -q "$SERVICE"; then
            STATUS=$(systemctl is-active $SERVICE 2>/dev/null)
            echo "$SERVICE: $STATUS"
        else
            echo "$SERVICE: Not installed"
        fi
    done
    echo ""
}

# Function to display all dashboard sections
show_full_dashboard() {
    clear
    echo "System Monitoring Dashboard - $(date)"
    echo "--------------------------------------"
    show_top_apps
    show_network
    show_disk
    show_system_load
    show_memory
    show_processes
    show_services
}

# Function to display selected sections based on flags
show_selected_dashboard() {
    clear
    echo "System Monitoring Dashboard - $(date)"
    echo "--------------------------------------"
    for arg in "$@"; do
        case $arg in
            -top)
                show_top_apps
                ;;
            -network)
                show_network
                ;;
            -disk)
                show_disk
                ;;
            -load)
                show_system_load
                ;;
            -memory)
                show_memory
                ;;
            -process)
                show_processes
                ;;
            -services)
                show_services
                ;;
            *)
                echo "Unknown option: $arg"
                ;;
        esac
    done
}

# Parse command-line arguments
if [ $# -eq 0 ]; then
    SELECTED=false
else
    SELECTED=true
    SELECTED_ARGS=("$@")
fi

# Main loop
while true; do
    if [ "$SELECTED" = false ]; then
        show_full_dashboard
    else
        show_selected_dashboard "${SELECTED_ARGS[@]}"
    fi
    sleep $REFRESH_INTERVAL
done

