#!/bin/bash

if [ "`which nmcli`" ]; then
if [ $(systemctl is-active NetworkManager) == "inactive" ] ; then
echo "inactive"
fi 
fi 
