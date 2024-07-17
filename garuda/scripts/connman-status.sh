#!/bin/bash

if [ "`which connmanctl`" ]; then
if [ $(systemctl is-active connman) == "inactive" ] ; then
echo "inactive"
fi 
fi
