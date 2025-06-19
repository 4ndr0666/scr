#!/bin/bash
# shellcheck disable=all

# Function to check internet speed using speedtest-cli
check_internet_speed() {
    echo "Checking internet speed..."
    download_speed=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - --bytes --no-upload | grep "Download" | awk '{print $2}')
    echo "Download speed: $download_speed Mbps"
    echo $download_speed
}

# Function to check CPU performance
check_cpu_performance() {
    echo "Checking CPU performance..."
    cpu_cores=$(nproc)
    cpu_speed=$(lscpu | grep "MHz" | awk '{print $3}')
    echo "CPU cores: $cpu_cores"
    echo "CPU speed: $cpu_speed MHz"
    echo $cpu_cores $cpu_speed
}

# Function to check available memory
check_memory() {
    echo "Checking available memory..."
    total_memory=$(free -m | grep "Mem:" | awk '{print $2}')
    available_memory=$(free -m | grep "Mem:" | awk '{print $7}')
    echo "Total memory: $total_memory MB"
    echo "Available memory: $available_memory MB"
    echo $total_memory $available_memory
}

# Function to scan open ports
scan_ports() {
    echo "Scanning open ports..."
    open_ports=$(nmap -p- --open localhost | grep ^[0-9] | awk '{print $1}' | cut -d'/' -f1)
    echo "Open ports: $open_ports"
    echo $open_ports
}

# Gather system parameters
internet_speed=$(check_internet_speed)
cpu_cores_speed=$(check_cpu_performance)
memory_info=$(check_memory)
open_ports=$(scan_ports)

# Parse gathered parameters
internet_speed=$(echo $internet_speed | awk '{print int($1)}')
cpu_cores=$(echo $cpu_cores_speed | awk '{print int($1)}')
cpu_speed=$(echo $cpu_cores_speed | awk '{print int($2)}')
available_memory=$(echo $memory_info | awk '{print int($2)}')

# Determine optimal chunks value
if [[ $internet_speed -ge 100 && $cpu_cores -ge 4 && $available_memory -ge 4000 ]]; then
    chunks=8
elif [[ $internet_speed -ge 50 && $cpu_cores -ge 2 && $available_memory -ge 2000 ]]; then
    chunks=6
elif [[ $internet_speed -ge 20 && $cpu_cores -ge 2 && $available_memory -ge 1000 ]]; then
    chunks=4
else
    chunks=2
fi

# Display the recommended value
echo "Recommended max amount of chunks per download: $chunks"
