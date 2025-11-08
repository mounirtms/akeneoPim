#!/bin/bash

# Script to kill PHP processes consuming high CPU for extended periods

# Log file
LOG_FILE="/home/pim/public_html/var/cpu_monitor.log"

# Maximum CPU percentage allowed
MAX_CPU=80

# Maximum time (in minutes) a process can run at high CPU
MAX_TIME=5

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Log function
log_message() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

log_message "Starting CPU monitoring..."

# Get PHP processes with high CPU usage
HIGH_CPU_PROCESSES=$(ps -eo pid,pcpu,time,comm | awk -v max_cpu="$MAX_CPU" '$2 > max_cpu && $4 ~ /php/ {print $1":"$2":"$3}')

if [ -n "$HIGH_CPU_PROCESSES" ]; then
    log_message "Found high CPU processes:"
    echo "$HIGH_CPU_PROCESSES" | while IFS=: read -r pid cpu time; do
        # Extract minutes from time format (e.g., 00:05:30 -> 5 minutes)
        if [[ $time =~ ^[0-9]+:[0-9]+:[0-9]+ ]]; then
            # Format is HH:MM:SS
            hours=$(echo "$time" | cut -d: -f1)
            minutes=$(echo "$time" | cut -d: -f2)
            total_minutes=$((hours * 60 + minutes))
        elif [[ $time =~ ^[0-9]+:[0-9]+ ]]; then
            # Format is MM:SS
            minutes=$(echo "$time" | cut -d: -f1)
            total_minutes=$minutes
        else
            # Just seconds
            total_minutes=0
        fi
        
        log_message "Process PID: $pid, CPU: $cpu%, Time: $time ($total_minutes minutes)"
        
        # Kill processes running longer than MAX_TIME at high CPU
        if [ "$total_minutes" -gt "$MAX_TIME" ]; then
            log_message "Killing process $pid (running $total_minutes minutes at ${cpu}% CPU)"
            kill -9 "$pid" 2>/dev/null || log_message "Failed to kill process $pid"
        fi
    done
else
    log_message "No high CPU PHP processes found."
fi

log_message "CPU monitoring completed."