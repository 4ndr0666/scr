#!/bin/bash
sudo find . -type l -exec sh -c 'file -b "$1" | grep -q "^broken"' sh {} \; -print
