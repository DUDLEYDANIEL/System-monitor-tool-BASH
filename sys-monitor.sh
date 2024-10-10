#!/bin/bash

# Variables
LOGFILE=/var/log/sys-monitor.log
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=80
THRESHOLD_NET=1000 # 1000 KBps\
EMAIL=example@mail.com #feel free to use your mail for alert
# Function to check CPU usage
function check_cpu() {
    # Read the first line from /proc/stat (aggregate CPU data)
    # $2, $3, $4, $5, $6, $7, $8 --> user, nice, system, idle, iowait, irq, softirq
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


    # checking the cpu usage threshold
    if (( $(echo "$CPU_USAGE > $THRESHOLD_CPU" | bc -l) )); then
        send_alert "CPU usage is high: $CPU_USAGE%"
    else
        echo "CPU usage is normal: $CPU_USAGE%"
    fi
}

check_mem(){
      #getting the values of the total memory and free memory
      mem_stats=($(vmstat -s| grep -E 'total memory|free memory' | awk '{print $1}'))
      
      tot_mem=${mem_stats[0]}
      free_mem=${mem_stats[1]}

      used_mem=$((tot_mem-free_mem))

      MEM_USAGE=($(echo "scale=2; 100*$used_mem/$tot_mem" | bc))


      if (( $(echo MEM_USAGE > $THRESHOLD_MEM | bc -l) )); then
        send_alert "Memory usage is high : $MEM_USAGE%"
      else
        echo "Memory usage is normal : $MEM_USAGE%"
      fi
    }

function check_disk() {
  # This function can be written also based on the /proc/diskstats file
  # For common purpose I will write using the df utility
  DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

  # Compare with threshold
  if (( DISK_USAGE > THRESHOLD_DISK )); then
      send_alert "Disk usage is high: $DISK_USAGE%"
  else
      echo "Disk usage is normal: $DISK_USAGE%"
  fi
}

function check_net() {
  # This function can be written also based on the /proc/net/dev file
  INTERFACE="eth0"

  net_stats=($(grep "INTERFACE" /proc/net/dev | tr -s " "| cut -d " " -f 3,11))

  rx_bytes=${net_stats[0]}
  tx_bytes=${net_stats[1]}

  #convert the bytes into kbps
  rx_kbps=$((rx_bytes / 1024))
  tx_kbps=$((tx_bytes / 1024))

  

  if (( rx_kbps > THRESHOLD_NET || tx_kbps > THRESHOLD_NET )); then
      send_alert "Network usage is high: $rx_kbps kB/s and $tx_kbps kB/s"
  else
      echo "Network usage is normal: $rx_kbps kB/s and $tx_kbps kB/s"
  fi  


}

function log_metrics(){
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP CPU:$CPU_USAGE MEM:$MEM_USAGE Disk:$DISK_USAGE NET:$rx_kbps kB/s and $tx_kbps kB/s" >> $LOGFILE
}

function send_alert(){
  SUBJECT="System Alert: $1"
  echo "subject : $SUBJECT" | sendmail $EMAIL
}
# Test BlockNetwork usage is normal: 0 kB/s and 0 kB/s
#
function monitor(){
echo "Monitoring started"
check_cpu
check_mem
check_disk
check_net
log_metrics
}

monitor
