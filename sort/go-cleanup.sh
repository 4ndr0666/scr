#!/bin/bash

# Set GOPATH environment variable to $XDG_DATA_HOME/go
export GOPATH="$XDG_DATA_HOME/go"

# Clean up the go cache
go clean -cache

# Remove unused dependencies
go mod tidy

# Remove any test files
go clean -testcache

# Harden go security
go env -w GOMODCACHE="$XDG_CACHE_HOME/go"

# Remove any junk files
rm -rf "$GOPATH"/src/*
rm -rf "$GOPATH"/pkg/*

# Add cron job to run this script every week
(crontab -l 2>/dev/null; echo "0 0 * * 0 $HOME/go-cleanup.sh") | crontab -

