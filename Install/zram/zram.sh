#!/bin/sh
### BEGIN INIT INFO
# Provides: zram
# Required-Start: $local_fs
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Increased Performance In Linux With zRam (Virtual Swap Compressed in RAM)
# Description: Adapted from scripts at https://github.com/mystilleef/FedoraZram and http://crunchbanglinux.org/forums/topic/15344/zram-a-good-idea/
# Included as part of antix-goodies package by anticapitalista <antiX@operamail.com>
# Amended by SamK to correctly allocate swap area per cpu on single and multiple cpu systems
# Copy this script (as root) from /usr/local/bin to /etc/init.d and then #update-rc.d zram defaults
# After booting verify the module is loaded with: lsmod | grep zram
# Requires
# id, echo, grep, lsmod, mkswap, modprobe, nproc, rmmod, sed, seq, sleep, swapoff, swapon,
### END INIT INFO

	

# When this script is not started with root privileges
if [ $(id -u) -ne 0 ]; then
   echo "Re-run with root privileges via sudo"
   echo ""
   exit 1
fi
	

# Detect the number of CPUs
CPU_COUNT=$(nproc --all)


start() {
   # Cumulative size of zram swapspace expressed as a percentage of available memory
   # Option, a value specified in /etc/default/zram overrides a value specified below
   # Examples
   #   PERCENTAGE=30
   #   PERCENTAGE=10
   # Default, PERCENTAGE=25
   PERCENTAGE=25
   # When a configuration file is present
   [ -f /etc/default/zram ] && . /etc/default/zram

   # Maximise the amount of available memory
   echo 3 > /proc/sys/vm/drop_caches
   
   # Detect the amount of available memory in kB
   MEM_AVAILABLE=$(grep MemFree /proc/meminfo | sed 's/[^0-9]\+//g')
   
   # Apportion the available memory in bytes equally between the number of cpus
   MEM_PER_CPU=$(($MEM_AVAILABLE/$CPU_COUNT*$PERCENTAGE/100*1000))
   
   # When loading the kernel module
   if modprobe zram num_devices=$CPU_COUNT >/dev/null 2>&1; then
      
      # Report success
      echo "Loading zram kernel module succeeded"
      
      else
      # Report error and exit
      echo "Loading zram kernel module failed"
      exit 1
   fi
      
   # Pause to allow required zram files to be created
   until [ -f /sys/block/zram0/disksize ] && [ -e /dev/zram0 ]
   do
      sleep 1
   done
    
   # Perform for each CPU
   for NUMBER in $(seq 0 $CPU_COUNT)
   do
      # When a corresponding zram disksize file is available
      if [ -f /sys/block/zram$NUMBER/disksize ]; then
      
         # Allocate a size of swap area for the corresponding zram device
         echo $MEM_PER_CPU > /sys/block/zram$NUMBER/disksize
      fi
   done
   
   # Pause to allow time for the swap area size to written to each file
   sleep 2
   
   # Perform for each CPU
   for NUMBER in $(seq 0 $CPU_COUNT)
   do
      # When a corresponding zram device is available
      if [ -e /dev/zram$NUMBER ]; then

         # Create and label a zram swap area
         mkswap --label SWAP_ZRAM$NUMBER /dev/zram$NUMBER
      
         # Activate the zram swap area and assign its priority of use
         swapon --priority 100 /dev/zram$NUMBER
      fi
   done
}


stop() {
   # Perform for each CPU
   for NUMBER in $(seq 0 $CPU_COUNT)
   do
      # When a corresponding zram swapspace is present
      if [ "$(grep /dev/zram$NUMBER /proc/swaps)" != "" ]; then
      
         # When switching off the corresponding swapspace
         if swapoff /dev/zram$NUMBER >/dev/null 2>&1; then

            # Report success
            echo "Removing zram$NUMBER swapspace succeeded"
        
            else
            # Report error
            echo "Removing zram$NUMBER swapspace failed"
         fi
      fi
   done
   
   # Pause to allow time for each zram swapspace to switch off
   sleep 2

   # When unloading the zram kernel module
   if rmmod zram >/dev/null 2>&1; then
   
      # Report success
      echo "Unloading zram kernel module succeeded"
      
      else
      # Report error and exit
      echo "Unloading zram kernel module failed"
      exit 1
   fi
}


case $1 in
   start)     start
              ;;
   stop)      stop
              ;;
   restart)   # When the zram kernel module is currently loaded
              if [ "$(lsmod | grep zram)" != "" ]; then
                 stop
                 sleep 2
                 start

                 else
                 # Report error
                 echo "Restart failed because the zram kernel module is not currently loaded"
              fi
              ;;
   *)         # Otherwise
              echo "Usage: $0 {start|stop|restart}"
esac


exit
