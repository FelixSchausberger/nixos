#!/usr/bin/env bash

# System information script for ironbar

# CPU usage calculation
cpu_usage() {
    local prev_total prev_idle total idle usage
    if [ -f /tmp/cpu_usage_prev ]; then
        source /tmp/cpu_usage_prev
    else
        prev_total=0
        prev_idle=0
    fi

    read -r cpu line < /proc/stat
    fields=($line)
    idle=$((${fields[3]} + ${fields[4]}))
    total=0
    for field in "${fields[@]}"; do
        total=$((total + field))
    done

    if [ $prev_total -ne 0 ]; then
        total_diff=$((total - prev_total))
        idle_diff=$((idle - prev_idle))
        usage=$(((1000 * (total_diff - idle_diff) / total_diff + 5) / 10))
    else
        usage=0
    fi

    echo "prev_total=$total" > /tmp/cpu_usage_prev
    echo "prev_idle=$idle" >> /tmp/cpu_usage_prev

    echo "$usage"
}

# Memory usage calculation
memory_usage() {
    local meminfo total available used percent
    meminfo=$(cat /proc/meminfo)
    total=$(echo "$meminfo" | awk '/MemTotal/ { print $2 }')
    available=$(echo "$meminfo" | awk '/MemAvailable/ { print $2 }')
    used=$((total - available))
    percent=$((100 * used / total))
    echo "$percent"
}

# Temperature reading
temperature() {
    local temp_file temp
    temp_file="/sys/class/thermal/thermal_zone0/temp"
    if [ -f "$temp_file" ]; then
        temp=$(cat "$temp_file")
        temp=$((temp / 1000))
        echo "$temp"
    else
        echo "N/A"
    fi
}

# Battery information
battery() {
    local bat_dir capacity status icon
    bat_dir="/sys/class/power_supply/BAT0"
    if [ -d "$bat_dir" ]; then
        capacity=$(cat "$bat_dir/capacity" 2>/dev/null || echo "0")
        status=$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")

        # Battery icons based on capacity and status
        if [ "$status" = "Charging" ]; then
            icon="󰂄"
        elif [ "$capacity" -gt 80 ]; then
            icon="󰁹"
        elif [ "$capacity" -gt 60 ]; then
            icon="󰂀"
        elif [ "$capacity" -gt 40 ]; then
            icon="󰁾"
        elif [ "$capacity" -gt 20 ]; then
            icon="󰁼"
        else
            icon="󰁺"
        fi

        echo "$icon $capacity%"
    else
        echo ""
    fi
}

# Main output
main() {
    local cpu_pct mem_pct temp_val bat_info
    cpu_pct=$(cpu_usage)
    mem_pct=$(memory_usage)
    temp_val=$(temperature)
    bat_info=$(battery)

    # Format: CPU | Memory | Temperature | Battery (if available)
    output="󰍛 ${cpu_pct}% 󰾆 ${mem_pct}%"

    if [ "$temp_val" != "N/A" ]; then
        output="$output 󰔏 ${temp_val}°C"
    fi

    if [ -n "$bat_info" ]; then
        output="$output $bat_info"
    fi

    echo "$output"
}

main
