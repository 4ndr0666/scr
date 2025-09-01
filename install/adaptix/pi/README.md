## Adaptix C2 — Raspberry Pi (ARMv7) Installation Guide

### Clone Repository

```bash
git clone https://github.com/Adaptix-Framework/AdaptixC2.git
cd AdaptixC2
```

### Preinstall Dependencies

**On Debian/Kali (ARMv7):**

```bash
sudo apt update
sudo apt install -y mingw-w64 make gcc g++ g++-mingw-w64 \
  build-essential cmake libssl-dev qt6-base-dev \
  qt6-websockets-dev qt6-declarative-dev
```

This matches the original dependencies noted for Linux environments. ([Adaptix Framework][1])

### Install Go (ARMv7-compatible)

The official documentation uses the **linux‑amd64** binary which fails on ARM—causing `Exec format error`. Use the `linux‑armv6l` archive instead; it runs correctly on ARMv7.

```bash
# Remove any incorrect install
sudo rm -rf /usr/local/go /usr/local/bin/go

# Download and install Go 1.24.4 for ARMv6l (ARMv7-compatible)
wget https://go.dev/dl/go1.24.4.linux-armv6l.tar.gz -O /tmp/go1.24.4.linux-armv6l.tar.gz
sudo tar -C /usr/local -xzf /tmp/go1.24.4.linux-armv6l.tar.gz

# Create symlink for convenience
sudo ln -s /usr/local/go/bin/go /usr/local/bin/go

# Verify installation
go version
```

Set `GOOS=linux`, `GOARCH=arm`, and `GOARM=7` when building. ([Adaptix Framework][1])

### Build AdaptixServer & Extenders

```bash
export GOOS=linux GOARCH=arm GOARM=7
make server
make extenders
```

All compiled outputs go to the `dist` directory. ([Adaptix Framework][1])

### Build AdaptixClient (ARM-compatible)

```bash
make client
```

On success, `AdaptixClient` appears in `dist`. ([Adaptix Framework][1])

---

## Start the AdaptixServer

Use a configuration profile or command-line flags:

```bash
./adaptixserver -profile profile.json
```

Sample `profile.json` template (ARM or any architecture):

```json
{
  "Teamserver": {
    "interface": "0.0.0.0",
    "port": 4321,
    "endpoint": "/endpoint",
    "password": "pass",
    "cert": "server.rsa.crt",
    "key": "server.rsa.key",
    "extenders": [
      "extenders/listener_beacon_http/config.json",
      "extenders/listener_beacon_smb/config.json",
      "extenders/listener_beacon_tcp/config.json",
      "extenders/agent_beacon/config.json",
      "extenders/listener_gopher_tcp/config.json",
      "extenders/agent_gopher/config.json"
    ],
    "access_token_live_hours": 12,
    "refresh_token_live_hours": 168
  },
  "ServerResponse": {
    "status": 404,
    "headers": {
      "Content-Type": "text/html; charset=UTF-8",
      "Server": "AdaptixC2",
      "Adaptix Version": "v0.8"
    },
    "page": "404page.html"
  },
  "EventCallback": {
    "Telegram": {
      "token": "",
      "chats_id": []
    },
    "new_agent_message": "New agent: %type% (%id%)\\n\\n%user% @ %computer% ...",
    "new_cred_message": "New secret [%type%]:\\n\\n%username% : %password% ...",
    "new_download_message":"File saved: %path% [%size%] from %computer% (%user%)"
  }
}
```

This aligns with the original “Starting” documentation. ([Adaptix Framework][2])

Generate SSL cert:

```bash
openssl req -x509 -nodes -newkey rsa:2048 -keyout server.rsa.key -out server.rsa.crt -days 3650
```

---

## Start AdaptixClient

Run the GUI executable:

```bash
./dist/AdaptixClient
```

It will create `~/.adaptix` for local database storage. Follow the login prompts using the server address, port, and profile. ([Adaptix Framework][2], [Adaptix Framework][3])

---

## Notes

* **Go version consistency**: The server and extenders must use the same Go version—ARM v6l arch for ARMv7. ([Adaptix Framework][1])
* **Profile-based configuration** ensures repeatable deployments.
* **ARM Compatibility**: The linux-armv6l Go binary works on ARMv7 (`armv7l` model).
* **Outputs**: Build artifacts appear in `dist/`.

---

## Summary Table

| Step                   | Purpose                        |
| ---------------------- | ------------------------------ |
| Preinstall deps        | Prepare build environment      |
| Install Go (ARM)       | Fix exec-format error on ARMv7 |
| Build server/extenders | Compile for ARM                |
| Build client           | Produce Qt-based GUI on ARM    |
| Start server           | Launch with proper config      |
| Start client           | GUI connection from ARM system |

This README reflects original documentation structure with ARM-specific corrections for Raspberry Pi installs.

[1]: https://adaptix-framework.gitbook.io/adaptix-framework/adaptix-c2/getting-starting/installation?utm_source=chatgpt.com "Installation | Adaptix Framework"
[2]: https://adaptix-framework.gitbook.io/adaptix-framework/adaptix-c2/getting-starting/starting?utm_source=chatgpt.com "Starting | Adaptix Framework"
[3]: https://adaptix-framework.gitbook.io/adaptix-framework/blogs?utm_source=chatgpt.com "Blogs | Adaptix Framework"
