#!/bin/bash

if [[ $(connmanctl technologies | grep -A1 bluetooth | awk '/Powered/ { print $NF }') == "True" ]] ; then
echo "enabled"
elif [[ $(bluetoothctl show | grep 'Powered' | cut -d ' ' -f2) == "yes" ]] ; then
echo "enabled"
elif [[ $(rfkill list | grep -A1 bluetooth | awk '/Soft blocked/ { print $NF }') == "no" ]] ; then
echo "enabled"
else
echo "disabled"
fi


