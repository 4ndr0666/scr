#!/bin/zsh
# shellcheck disable=all

# Check aria2 service status
echo "Checking aria2 service status..."
sudo systemctl status aria2

# Verify aria2 is listening on localhost:6800
echo "Verifying aria2 is listening on localhost:6800..."
ss -tulpn | grep 6800

# Test RPC Interface with getVersion
echo "Testing RPC Interface with getVersion..."
VERSION_RESPONSE=$(curl -s -d '{"jsonrpc":"2.0","method":"aria2.getVersion","id":"test"}' -H 'Content-Type: application/json' http://localhost:6800/jsonrpc)

echo "RPC Response:"
echo "$VERSION_RESPONSE"

# Check if RPC response contains "aria2 version"
if echo "$VERSION_RESPONSE" | grep -q "aria2 version"; then
    echo "RPC getVersion successful."
else
    echo "RPC getVersion failed. Check aria2.conf and service status."
    exit 1
fi

# Add a test download via RPC
echo "Adding a test download via RPC..."
DOWNLOAD_RESPONSE=$(curl -s -d '{"jsonrpc":"2.0","method":"aria2.addUri","id":"add_test","params":["token:4utotroph666", ["http://ipv4.download.thinkbroadband.com/5MB.zip"]]}' -H 'Content-Type: application/json' http://localhost:6800/jsonrpc)

echo "RPC Add Download Response:"
echo "$DOWNLOAD_RESPONSE"

# Check if download was added successfully
if echo "$DOWNLOAD_RESPONSE" | grep -q "result"; then
    echo "Test download added successfully."
else
    echo "Failed to add test download. Check aria2.conf and service status."
    exit 1
fi

# Verify the download
echo "Verifying the download in /sto2/Downloads/..."
ls -lh /sto2/Downloads/

# Display the last 10 lines of aria2.log
echo "Displaying the last 10 lines of aria2.log..."
if [[ -f "/home/andro/.config/aria2/aria2.log" ]]; then
    tail -n 10 /home/andro/.config/aria2/aria2.log
else
    echo "aria2.log does not exist. Check aria2.conf and service status."
fi
