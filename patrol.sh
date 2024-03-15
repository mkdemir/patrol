#!/bin/bash

# Author: mkdemir

clear
VERSION="1.0.1"
os_version=$(cat /etc/*release | grep PRETTY_NAME | cut -d'"' -f2)
host=$(hostname)
ip=$(hostname -I | awk '{print $1}')

##########################
# FUNCTIONS
##########################

# DESCRIPTION: Clean up background processes and log the action
cleanup_processes() {

    # Check if the file ends with `]` character
    last_character=$(tail -c 2 "$LOG_JSON_FILE_NAME")

    if [ "$last_character" != "]" ]; then
        # If `]` character is not present at the end of the file, append it
        sed -i '$ s/,$//' "$LOG_JSON_FILE_NAME"
        echo "]" >> "$LOG_JSON_FILE_NAME"
    fi
    # Remove the trailing comma and add the closing bracket to the JSON log file
    echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [WARNING] Cleaning up background processes."
    # Kill all background processes
    kill $(jobs -p) &>/dev/null
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [WARNING] Background processes cleaned up."
}

# DESCRIPTION: Handle errors, log them, clean up background processes, and exit the script
# PARAMETERS:
#   $1: The error message to log
# RETURNS:
#   None
handle_error() {
    local error_message="$1"
    local error_log_file="patrol-error.log"
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   $error_message" >> "$error_log_file"
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   An error occurred. Please check $error_log_file for more details."
    cleanup_processes
    exit 1
}

# DESCRIPTION: Check if a file exists at the specified path, and log its information
# PARAMETERS:
#   $1: The file path to check
# RETURNS:
#   None
check_file() {
    if [ -f "$1" ]; then
        size="$(du -h $1)"
        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    File Info: $size"
    else
        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    File does not exist: $1"
        touch "$1"
        if [ -f "$LOG_JSON_FILE_NAME" ]; then
            echo "[" > "$LOG_JSON_FILE_NAME"
        fi
    fi
}

# DESCRIPTION: Compress a file if its size exceeds a certain threshold
# PARAMETERS:
#   $1: The file name to compress
#   $2: The compressed file name prefix
#   $3: The maximum compressed file count
# RETURNS:
#   None
compress_file() {
    file_size=$(du -b "$1" | cut -f1)

    # If the log file size exceeds 500 MB, compress the file
    if [ $file_size -gt 524288000 ]; then
        if [ -n "$(ls -A ${2}_*.tar.gz 2>/dev/null)" ]; then
            num_compressed_files=$(ls -A ${2}_*.tar.gz | wc -l)
            if [ "$num_compressed_files" -gt "$3" ]; then
                files_to_delete=$(ls -t ${2}_*.tar.gz | tail -n +$((MAX_COMPRESSED_FILES + 1)))
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Removing old compressed files: $files_to_delete"
                rm -f $files_to_delete || handle_error "Error occurred while removing old compressed files."
            fi
        else
            echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [DEBUG]   No compressed files found."
        fi

        archive_file="${2}_$(date +"%Y-%m-%d-%H-%M-%S").tar.gz"
        tar -czf "$archive_file" "$1" || handle_error "Error occurred while compressing file."
        > $1 || handle_error "Error occurred while truncating file."

        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Created Archive: $archive_file"
    fi
}

##########################
# MAIN SCRIPT
##########################

# Inform the user about the script's operation
echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Script started."
echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Information: Script Version: $VERSION - Hostname: $(hostname) - IP: $ip - OS Version: $os_version"

# Check if 'tar' is installed
if ! command -v tar &> /dev/null; then
    handle_error "'tar' is not installed. Attempting to install."

    # Check the distribution type
    if [ -f /etc/os-release ]; then
        # Get the distribution ID
        distro_id=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

        # Install 'tar' based on the distribution type
        case "$distro_id" in
            debian|ubuntu)
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Installing 'tar' using apt..."
                sudo apt update && sudo apt install tar -y || handle_error "Failed to install 'tar' using apt."
                ;;
            centos|fedora|rhel)
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Installing 'tar' using yum..."
                sudo yum install tar -y || handle_error "Failed to install 'tar' using yum."
                ;;
            opensuse)
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Installing 'tar' using zypper..."
                sudo zypper install tar -y || handle_error "Failed to install 'tar' using zypper."
                ;;
            arch)
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Installing 'tar' using pacman..."
                sudo pacman -Sy tar --noconfirm || handle_error "Failed to install 'tar' using pacman."
                ;;
            *)
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   Unsupported distribution: $distro_id"
                exit 1
                ;;
        esac
        # Check if installation was successful
        if [ $? -eq 0 ]; then
            echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    'tar' installation successful."
        else
            echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   Failed to install 'tar'."
            exit 1
        fi
    else
        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   Unable to determine distribution type."
        exit 1
    fi
fi

##########################
# PARAMETER PROCESSING
##########################

# Define threshold values
RAM_THRESHOLD=90
CPU_THRESHOLD=90

######################################################################################################
## RESET_THRESHOLD
#
# RESET_THRESHOLD=85
# Check and validate user input for threshold values
# 
# if [ "$RAM_THRESHOLD" -lt 0 ] || [ "$RAM_THRESHOLD" -gt 100 ] || [ "$CPU_THRESHOLD" -lt 0 ] || [ "$CPU_THRESHOLD" -gt 100 ] || [ "$RESET_THRESHOLD" -lt 0 ] || [ "$RESET_THRESHOLD" -gt 100 ]; then
# 
######################################################################################################

if [ "$RAM_THRESHOLD" -lt 0 ] || [ "$RAM_THRESHOLD" -gt 100 ] || [ "$CPU_THRESHOLD" -lt 0 ] || [ "$CPU_THRESHOLD" -gt 100 ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [ERROR]   Threshold values must be between 0 and 100."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
        case $key in
        -ram)
            RAM_THRESHOLD="$2"
            shift 2
            ;;
        -cpu)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        # -reset)
        #     RESET_THRESHOLD="$2"
        #     shift 2
        #     ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Json File
LOG_JSON_FILE_NAME="patrol-outjson.json"

# Log file
LOG_FILE_NAME="patrol-output.log"

# Compressed log file
COMPRESSED_LOG_FILE_NAME="patrol-archive"
COMPRESSED_LOG_JSON_FILE_NAME="patrol-archivejson"

# Maximum number of compressed files
MAX_COMPRESSED_FILES=3
MAX_COMPRESSED_FILES=$((MAX_COMPRESSED_FILES - 1))

# Trap the EXIT signal and call cleanup_processes function
trap 'cleanup_processes' EXIT

# Variable to keep track of whether writing to the file should be stopped
STOP_WRITING=false

while true; do
    check_file "$LOG_JSON_FILE_NAME"
    check_file "$LOG_FILE_NAME"

    # Example usage:
    compress_file "$LOG_FILE_NAME" "$COMPRESSED_LOG_FILE_NAME" "$MAX_COMPRESSED_FILES"
    compress_file "$LOG_JSON_FILE_NAME" "$COMPRESSED_LOG_JSON_FILE_NAME" "$MAX_COMPRESSED_FILES"

    if [ ! -s "$LOG_JSON_FILE_NAME" ]; then
        echo "[" > "$LOG_JSON_FILE_NAME"
    fi

    # Get system usage
    cpu_percent=$(top -bn1 | awk '/Cpu\(s\)/ {print int(100 - $8)}')
    ram_percent=$(free | awk '/Mem:/ {print int($3/$2 * 100.0)}')

    # ==========================================================================================================================================
    ## RESET_THRESHOLD
    # # Check if RAM and CPU usage are below or equal to the reset threshold
    # if [ "$ram_percent" -le "$RESET_THRESHOLD" ] && [ "$cpu_percent" -le "$RESET_THRESHOLD" ]; then
    #     echo "[INFO]    $(date +"%Y-%m-%d %H:%M:%S") - Writing to log file has stopped (CPU Percent: $cpu_percent RAM Percent: $ram_percent)."
    #     STOP_WRITING=true
    # else
    #     echo "[INFO]    $(date +"%Y-%m-%d %H:%M:%S") - Writing to log file has started (CPU Percent: $cpu_percent RAM Percent: $ram_percent)."
    #     STOP_WRITING=false
    # fi
    # ==========================================================================================================================================

    # Check threshold values and whether writing should be stopped
    if [ "$ram_percent" -ge "$RAM_THRESHOLD" ] || [ "$cpu_percent" -ge "$CPU_THRESHOLD" ]; then
        STOP_WRITING=false
        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Writing to log file has started (CPU Percent: $cpu_percent RAM Percent: $ram_percent)."
        if [ "$STOP_WRITING" = false ]; then

            # Get top 15 processes for RAM usage
            #ram_top_processes=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem,%cpu | head -n 11)
            ram_top_processes=$(ps -e -o pid,ppid,user,uid,%cpu,%mem,vsize,rss,tty,stat,start,time,cmd --sort=-%mem,%cpu | head -n 16)
            {
                echo "========================================================================================="
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] - [Script Version: $VERSION] - [Hostname: $(hostname)] - [IP: $ip] - RAM Usage: $ram_percent%"
                echo "$ram_top_processes"
            } >> "$LOG_FILE_NAME"

            # Get top 15 processes for CPU usage
            # cpu_top_processes=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu,%mem | head -n 11)
            cpu_top_processes=$(ps -e -o pid,ppid,user,uid,%cpu,%mem,vsize,rss,tty,stat,start,time,cmd --sort=-%cpu,%mem | head -n 16)
            {
                echo "========================================================================================="
                echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] - [Script Version: $VERSION] - [Hostname: $(hostname)] - [IP: $ip] - CPU Usage: $cpu_percent%"
                echo "$cpu_top_processes"
            } >> "$LOG_FILE_NAME"

            echo -e "\n" >> "$LOG_FILE_NAME"
            #log_file_size=$(du -h "$LOG_FILE_NAME")
            #echo -e "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [DEBUG]   File Size: $log_file_size"

            # Write process list to JSON file
            # =========================================================================================
            # pid,ppid,user,uid,%cpu,%mem,vsize,rss,tty,stat,start,time,cmd (raw)
            # LOG_JSON_FILE_NAME="processes.json"; echo "{" > "$LOG_JSON_FILE_NAME"; ps -e -o pid,ppid,user,uid,%cpu,%mem,vsize,rss,tty,stat,start,time,cmd --sort=-%mem,%cpu | head -n 16 | while read -r line; do pid=$(echo "$line" | awk '{print $1}'); ppid=$(echo "$line" | awk '{print $2}'); user=$(echo "$line" | awk '{print $3}'); uid=$(echo "$line" | awk '{print $4}'); cpu=$(echo "$line" | awk '{print $5}'); mem=$(echo "$line" | awk '{print $6}'); vsize=$(echo "$line" | awk '{print $7}'); rss=$(echo "$line" | awk '{print $8}'); tty=$(echo "$line" | awk '{print $9}'); stat=$(echo "$line" | awk '{print $10}'); start=$(echo "$line" | awk '{print $11}'); time=$(echo "$line" | awk '{print $12}'); cmd=$(echo "$line" | awk '{$1=""; $2=""; $3=""; $4="";$5="";$6="";$7="";$8="";$9="";$10="";$11="";$12=""; print $0}' | sed 's/^\s*//'); echo "  \"$pid\": {\"PPID\": \"$ppid\", \"User\": \"$user\", \"UID\": \"$uid\", \"%CPU\": \"$cpu\", \"%MEM\": \"$mem\", \"VSize\": \"$vsize\", \"RSS\": \"$rss\", \"TTY\": \"$tty\", \"State\": \"$stat\", \"Start\": \"$start\", \"Time\": \"$time\", \"CMD\": \"$cmd\"}," >> "$LOG_JSON_FILE_NAME"; done; sed -i '$ s/.$//' "$LOG_JSON_FILE_NAME"; echo "}" >> "$LOG_JSON_FILE_NAME"; echo "Process list successfully written to $LOG_JSON_FILE_NAME."
            #echo "[" >> "$LOG_JSON_FILE_NAME"

            #sed -i '$ s/]$//' "$LOG_JSON_FILE_NAME"
            #sed -i 's/},\s*{/\},\{/g' "$LOG_JSON_FILE_NAME"

            if [[ $(tail -c 2 "$LOG_JSON_FILE_NAME") == "]" ]]; then
                sed -i '$ s/]$//' "$LOG_JSON_FILE_NAME"
                sed -i '/^\s*$/d' "$LOG_JSON_FILE_NAME"
                # sed -i 's/,$//' "$LOG_JSON_FILE_NAME"
                # sed -i 's/$/,/' "$LOG_JSON_FILE_NAME"
                sed -i '/^\[/! s/,$//' "$LOG_JSON_FILE_NAME"
                sed -i '/^\[/! s/$/,/' "$LOG_JSON_FILE_NAME"

            fi

            ps -e -o pid,ppid,user,uid,%cpu,%mem,vsize,rss,tty,stat,cmd --sort=-%mem,%cpu | head -n 16 | tail -n +2 | while read -r line; do
                pid=$(echo "$line" | awk '{print $1}')
                ppid=$(echo "$line" | awk '{print $2}')
                user=$(echo "$line" | awk '{print $3}')
                uid=$(echo "$line" | awk '{print $4}')
                cpu=$(echo "$line" | awk '{print $5}')
                mem=$(echo "$line" | awk '{print $6}')
                vsize=$(echo "$line" | awk '{print $7}')
                rss=$(echo "$line" | awk '{print $8}')
                tty=$(echo "$line" | awk '{print $9}')
                stat=$(echo "$line" | awk '{print $10}')
                cmd=$(echo "$line" | awk '{$1=""; $2=""; $3=""; $4="";$5="";$6="";$7="";$8="";$9="";$10=""; print $0}' | sed 's/^\s*//')
                date=$(date +"%Y-%m-%d %H:%M:%S.%3N")
                

                echo "{\"Date\": \"$date\", \"HOSTNAME\": \"$host\", \"IP\": \"$ip\", \"OS\": \"$os_version\", \"PID\": \"$pid\", \"PPID\": \"$ppid\", \"User\": \"$user\", \"UID\": \"$uid\", \"CPU\": \"$cpu\", \"MEM\": \"$mem\", \"VSize\": \"$vsize\", \"RSS\": \"$rss\", \"TTY\": \"$tty\", \"State\": \"$stat\", \"CMD\": \"$cmd\"}," >> "$LOG_JSON_FILE_NAME"
            done
            sed -i '$ s/,$//' "$LOG_JSON_FILE_NAME"
            echo "]" >> "$LOG_JSON_FILE_NAME"
            echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Process list successfully written to $LOG_JSON_FILE_NAME."
            #json_file_size=$(du -h "$LOG_JSON_FILE_NAME")
            
            #echo -e "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [DEBUG]   JSON File Size: $json_file_size"
            # =========================================================================================
            fi
    else
        STOP_WRITING=true
        echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [INFO]    Writing to log file has stopped (CPU Percent: $cpu_percent RAM Percent: $ram_percent)."
    fi

    # Debug messages
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [DEBUG]   RAM Usage: $ram_percent%"
    echo "[$(date +"%Y-%m-%d %H:%M:%S.%3N")] $(hostname) [DEBUG]   CPU Usage: $cpu_percent%"

    # Wait
    sleep 60 # Wait for 60 second
done
