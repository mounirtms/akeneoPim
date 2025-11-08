#!/bin/bash

# Advanced CPU monitoring and process management script

# Configuration
LOG_FILE="/home/pim/public_html/var/cpu_monitor.log"
MAX_CPU=70
MAX_TIME_MINUTES=3
NOTIFY_EMAIL="admin@technostationery.com"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "=== CPU Monitor Started ==="

# Function to kill high CPU processes
kill_high_cpu_processes() {
    # Get processes consuming more than MAX_CPU% for more than MAX_TIME_MINUTES
    ps -eo pid,pcpu,etime,comm,user,cmd --no-headers | while read -r pid cpu time comm user cmd; do
        # Skip if not a PHP process or not our user
        if [[ "$comm" != *"php"* ]] || [[ "$user" != "technad+"* ]]; then
            continue
        fi
        
        # Convert CPU to integer for comparison (remove decimal point)
        cpu_int=$(echo "$cpu" | sed 's/\..*//')
        
        # Check if CPU usage exceeds threshold
        if [ "$cpu_int" -gt "$MAX_CPU" ]; then
            # Parse time format to minutes
            total_minutes=0
            if [[ $time == *-* ]]; then
                # Format: days-HH:MM:SS
                days=$(echo "$time" | cut -d- -f1)
                time_part=$(echo "$time" | cut -d- -f2)
                hours=$(echo "$time_part" | cut -d: -f1)
                minutes=$(echo "$time_part" | cut -d: -f2)
                total_minutes=$((days * 1440 + hours * 60 + minutes))
            elif [[ $time == *:*:* ]]; then
                # Format: HH:MM:SS
                hours=$(echo "$time" | cut -d: -f1)
                minutes=$(echo "$time" | cut -d: -f2)
                total_minutes=$((hours * 60 + minutes))
            elif [[ $time == *:* ]]; then
                # Format: MM:SS
                minutes=$(echo "$time" | cut -d: -f1)
                total_minutes=$minutes
            else
                # Just seconds or other format
                total_minutes=0
            fi
            
            # Kill if running too long at high CPU
            if [ "$total_minutes" -ge "$MAX_TIME_MINUTES" ]; then
                log_message "Killing PID $pid (CPU: $cpu%, Time: $time, Cmd: $cmd)"
                kill -9 "$pid" 2>/dev/null && log_message "Successfully killed PID $pid" || log_message "Failed to kill PID $pid"
                
                # Optional: Send notification
                # echo "Killed high CPU process: PID $pid, CPU $cpu%, Time $time" | mail -s "High CPU Process Killed" "$NOTIFY_EMAIL"
            else
                log_message "Monitoring PID $pid (CPU: $cpu%, Time: $time, Cmd: $cmd)"
            fi
        fi
    done
}

# Function to optimize system
optimize_system() {
    # Clear system cache
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || log_message "Could not clear system cache"
    
    # Optimize MySQL (if script exists)
    if [ -f "/home/pim/public_html/bin/console" ]; then
        cd /home/pim/public_html
        php bin/console pimcore:mysql-tools --mode=optimize --env=prod >> "$LOG_FILE" 2>&1 &
    fi
}

# Main execution
log_message "Checking for high CPU processes..."
kill_high_cpu_processes

log_message "Performing system optimization..."
optimize_system

log_message "=== CPU Monitor Completed ==="