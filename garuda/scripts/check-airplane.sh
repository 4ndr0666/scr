#!/bin/bash
if [[ $(nmcli networking) == "disabled" ]] ; then
echo "enabled"
elif [[ $(connmanctl state | awk '/OfflineMode/ { print $NF }') == "True" ]] ; then
echo "enabled"
else
echo "disabled"
fi
