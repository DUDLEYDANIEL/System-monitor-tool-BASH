#!/bin/bash

# Set CPU usage threshold (example: 80%)
THRESHOLD_CPU=80

# Function to check CPU usage
function check_cpu() {
    # Read the first line from /proc/stat (aggregate CPU data)
    cpu_stats=($(awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat))

    # Calculate the total time and the idle time
    idle1=${cpu_stats[3]}
    total1=0
    for value in "${cpu_stats[@]}"; do
        total1=$((total1 + value))
    done

    # Sleep for a short time to get another reading
    sleep 1

    # Read the CPU stats again after the delay
    cpu_stats=($(awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat))

    idle2=${cpu_stats[3]}
    total2=0
    for value in "${cpu_stats[@]}"; do
        total2=$((total2 + value))
    done

    # Calculate the differences between two readings
    total_diff=$((total2 - total1))
    idle_diff=$((idle2 - idle1))


    # error handling
    if [ "$total_diff" -eq 0 ]; then
        echo "Error: Total CPU time difference is zero. Skipping CPU usage calculation."
        return
    fi

    # Calculate the CPU usage percentage
    CPU_USAGE=$(echo "scale=2; 100 * ($total_diff - $idle_diff) / $total_diff" | bc)


    # Use bc to compare floating-point numbers
    if (( $(echo "$CPU_USAGE > $THRESHOLD_CPU" | bc -l) )); then
        send_alert "CPU usage is high: $CPU_USAGE%"
    else
        echo "CPU usage is normal: $CPU_USAGE%"
    fi
}

# Dummy send_alert function for testing
function send_alert() {
    echo "$1"
}

# Test Block
echo "Monitoring started"
check_cpu

