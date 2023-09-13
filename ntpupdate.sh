#!/bin/bash

#Set time  sync and exit
sudo screenfetch -D gnu;
print_good "Will sync time shortly";
sleep 5;
sudo service ntp stop;
sudo service ntp start;
sudo ntpq -p;
echo $(date);
sleep 5;
exit 1;
