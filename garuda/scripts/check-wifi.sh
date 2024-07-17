#!/bin/bash
if [[ $(connmanctl technologies | grep -A1 wifi | awk '/Powered/ { print $NF }') == "True" ]] ; then 
echo "enabled"
elif [[ $(rfkill list | grep -A1 wifi | awk '/Soft blocked/ { print $NF }') == "no" ]] ; then
echo "enabled"
elif [[ $(nmcli radio wifi) == "enabled" ]] ; then
echo "enabled"
else
echo "disabled"
fi


