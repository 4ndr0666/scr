#!/usr/bin/env bash
# setup_wayfire_ipc.sh
# Author: 4ndr0666
#
# [=== ECOSYSTEM PROVISIONING SCRIPT ===]
# 1) Acquire python-wayfire dependency.
# 2) Idempotently deploy (and re-sync) wayfire_socket.py via heredoc.
# 3) Enforce secure ownership and permissions.
#
# Golden-Unit audit notes (see accompanying narration):
#   - dependency_acquisition: EAFP — gate directly on the install command's
#     own exit status instead of a manual `$?` capture one line later.
#   - ipc_plugin_verification: removed by explicit instruction. This script
#     now only builds and installs the socket client; it does not validate
#     that the Wayfire IPC plugin or wayfire.ini config are in place. A
#     missing plugin/config will surface at WayfireSocket.connect() time
#     instead of at install time.
#   - directory_provisioning: mkdir -p is already idempotent; the prior
#     existence guard was inert ceremony, removed.
#   - heredoc_deployment: now hash-compares embedded content against any
#     existing deployment and re-syncs on drift (was frozen-at-first-run);
#     write is atomic (temp file + mv) so an interrupted write never leaves
#     a partial file mistaken for a complete deployment.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$HOME/.config/wayfire/ipc-scripts"
TARGET_FILE="$SCRIPT_DIR/wayfire_socket.py"

log_info()  { printf '[INFO] %s\n' "$*"; }
log_ok()    { printf '[OK]   %s\n' "$*"; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

### (1) Dependency Acquisition: python-wayfire
log_info "Checking dependencies for python-wayfire..."
if pacman -Qs python-wayfire > /dev/null; then
    log_ok "python-wayfire is installed."
else
    log_info "python-wayfire not detected. Attempting installation..."
    if sudo pacman -S --needed --noconfirm python-wayfire; then
        log_ok "python-wayfire installed."
    else
        log_error "Failed to install python-wayfire. Aborting."
        exit 1
    fi
fi

### (2) Provision Directory
# mkdir -p is already idempotent; no existence pre-check needed (EAFP).
mkdir -p "$SCRIPT_DIR"

### (3) Idempotent, Self-Syncing Heredoc Deployment
# Renders canonical content to a temp file, then redeploys only if the
# target is missing or its content has drifted from canonical (hash compare).
# This keeps every machine that ran this script at any point converging on
# the current embedded source, rather than freezing at first-run content.
deploy_wayfire_socket() {
    local tmp_file
    tmp_file="$(mktemp "${SCRIPT_DIR}/.wayfire_socket.py.XXXXXX")"

    cat << 'EOF' > "$tmp_file"
#!/usr/bin/env python3
"""
WAYFIRE_SOCKET.PY
Implements WayfireSocket: a JSON-based protocol client over a Wayfire IPC
UNIX domain socket. Newline-delimited JSON framing in both directions.
"""

import socket
import json


DEFAULT_SOCKET_PATH = "/tmp/wayfire-wayland-1.socket"


class WayfireSocket:
    def __init__(self, socket_path=DEFAULT_SOCKET_PATH, timeout=5):
        self.socket_path = socket_path
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        try:
            self.sock.connect(self.socket_path)
        except OSError as e:
            raise RuntimeError(
                f"Failed to connect to Wayfire IPC socket {socket_path}: {e}"
            ) from e
        self._read_buffer = b""

    def _readline(self):
        while b"\n" not in self._read_buffer:
            chunk = self.sock.recv(1024)
            if not chunk:
                raise RuntimeError("Connection closed by Wayfire IPC server")
            self._read_buffer += chunk
        line, self._read_buffer = self._read_buffer.split(b"\n", 1)
        return line.decode("utf-8")

    def read_next_event(self):
        line = self._readline()
        return json.loads(line)

    def send_command(self, command, **kwargs):
        msg = {"command": command}
        msg.update(kwargs)
        payload = (json.dumps(msg) + "\n").encode("utf-8")
        total_sent = 0
        while total_sent < len(payload):
            sent = self.sock.send(payload[total_sent:])
            if sent == 0:
                raise RuntimeError("Socket connection broken")
            total_sent += sent
        if command != "watch":
            return self._read_response()
        return None

    def _read_response(self):
        line = self._readline()
        return json.loads(line)

    def watch(self, events):
        return self.send_command("watch", events=events)

    def get_output(self, output_id):
        return self.send_command("get_output", output_id=output_id)

    def get_tiling_layout(self, wset, wsx, wsy):
        return self.send_command("get_tiling_layout", wset=wset, wsx=wsx, wsy=wsy)

    def set_tiling_layout(self, wset, wsx, wsy, layout):
        return self.send_command(
            "set_tiling_layout", wset=wset, wsx=wsx, wsy=wsy, layout=layout
        )

    def close(self):
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        finally:
            self.sock.close()


if __name__ == "__main__":
    wf_sock = WayfireSocket()
    try:
        print("Connected to Wayfire IPC socket.")
        wf_sock.watch(["view-mapped"])
        event = wf_sock.read_next_event()
        print("Got event:", event)
    finally:
        wf_sock.close()
EOF

    if [[ -f "$TARGET_FILE" ]] && cmp -s "$tmp_file" "$TARGET_FILE"; then
        log_ok "wayfire_socket.py is already current. No redeploy needed."
        rm -f "$tmp_file"
        return 0
    fi

    if [[ -f "$TARGET_FILE" ]]; then
        log_info "wayfire_socket.py content has drifted from canonical. Re-syncing..."
    else
        log_info "Deploying wayfire_socket.py..."
    fi

    mv -f "$tmp_file" "$TARGET_FILE"
    log_ok "wayfire_socket.py deployed."
}

deploy_wayfire_socket

### (4) Permission Enforcement
log_info "Setting secure permissions..."
chmod +x "$TARGET_FILE"
chown "$USER":"$USER" "$TARGET_FILE"

log_ok "Ecosystem verification complete."
log_info "Target Directory: $SCRIPT_DIR"
exit 0
