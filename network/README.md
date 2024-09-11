#### Disable Root Login via SSH
- Open the SSH configuration file in a text editor:
  ```bash
  sudo nano /etc/ssh/sshd_config
  ```
- Look for the line `#PermitRootLogin prohibit-password`. Uncomment it and change it to:
  ```bash
  PermitRootLogin no
  ```
- This disables root login via SSH, which is a common security best practice.

#### Restrict SSH Access to Specific IP Addresses
- If you have a specific IP address or range of addresses that should have SSH access, add the following rule to UFW:
  ```bash
  sudo ufw allow from <trusted-ip> to any port 22
  ```
- Replace `<trusted-ip>` with the IP address or range that you want to allow SSH access.

#### Use Key-Based Authentication (Optional but Recommended)
- Generate an SSH key pair on your client machine (if you don’t have one already):
  ```bash
  ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
  ```
- Copy the public key to your server:
  ```bash
  ssh-copy-id user@server_ip
  ```
- Ensure that `PasswordAuthentication` is disabled in `/etc/ssh/sshd_config`:
  ```bash
  PasswordAuthentication no
  ```
- Restart the SSH service to apply changes:
  ```bash
  sudo systemctl restart sshd
  ```

###  **Disabling SSH**
If you're not using SSH, it's a good security practice to disable it to minimize your system's attack surface.

#### **Steps to Disable SSH:**
1. **Disable and Stop the SSH Service:**
   - You can disable the SSH service so that it doesn't start on boot:
     ```bash
     sudo systemctl disable sshd
     ```
   - Stop the SSH service immediately:
     ```bash
     sudo systemctl stop sshd
     ```
2. **Verify that SSH is Disabled:**
   - After stopping and disabling the SSH service, verify that it's no longer listening on port `22`:
     ```bash
     sudo ss -tunlp | grep 22
     ```
   - There should be no output if SSH is fully disabled.


---

  
**Disabling Unnecessary Services**:
   - Your system is still using LLMNR and mDNS on various interfaces, which may not be necessary, especially if your primary use case is connecting through VPNs.
   - **Recommendation**: You can disable LLMNR and mDNS if they are not needed:
     - Edit `/etc/systemd/resolved.conf`:
       ```ini
       LLMNR=no
       MulticastDNS=no
       ```
     - Restart the `systemd-resolved` service:
       ```bash
       sudo systemctl restart systemd-resolved
       ```
       
---


#### Check Current DNS Servers
- Run the following command to see the current DNS servers in use:
  ```bash
  resolvectl status
  ```
- This command will show the DNS servers for each network interface. If the VPN interface (e.g., `tun0` or `ppp0`) is using DNS servers provided by ExpressVPN, it will be listed here.


### Revised UFW Commands:

```bash
if [[ "$jdownloader_flag" == "true" ]]; then
    echo "Configuring UFW rules for JDownloader2..."

    # Allow JDownloader ports on the VPN interface (tun0) for incoming traffic
    ufw allow in on tun0 to any port 9665 proto tcp
    ufw allow in on tun0 to any port 9666 proto tcp

    # Deny access to these ports from any other interface for incoming traffic
    ufw deny in on enp2s0 to any port 9665 proto tcp
    ufw deny in on enp2s0 to any port 9666 proto tcp

    # Optionally deny outgoing traffic to these ports from any other interface (if needed)
    # ufw deny out on enp2s0 to any port 9665 proto tcp
    # ufw deny out on enp2s0 to any port 9666 proto tcp
fi
```

### Explanation:

1. **Allow Rules**:
   - `ufw allow in on tun0 to any port 9665 proto tcp`: Allows incoming traffic on port `9665/tcp` through the `tun0` interface (VPN).
   - `ufw allow in on tun0 to any port 9666 proto tcp`: Allows incoming traffic on port `9666/tcp` through the `tun0` interface (VPN).

2. **Deny Rules**:
   - `ufw deny in on enp2s0 to any port 9665 proto tcp`: Denies incoming traffic on port `9665/tcp` on the `enp2s0` interface (local network interface).
   - `ufw deny in on enp2s0 to any port 9666 proto tcp`: Denies incoming traffic on port `9666/tcp` on the `enp2s0` interface (local network interface).


---


**Test JDownloader Connectivity**:
   - Start a download in JDownloader and verify that the traffic is routed through the VPN interface (`tun0`).
   - Monitor the traffic using `iftop` or `tcpdump` to ensure that JDownloader is only communicating through `tun0`.

**Simulate VPN Disconnection**:
   - Temporarily disconnect the VPN and ensure JDownloader pauses or stops downloading.


### Key Settings to Review and Adjust

1. **Preferred IP Version (InternetConnectionSettings: Preferred IP Version)**:
   - **Current Setting**: `SYSTEM`
   - **Recommendation**: This setting determines which IP version (IPv4 or IPv6) JDownloader prefers to use. The `SYSTEM` setting means it will use whatever the system prefers. If your VPN uses IPv4 only, you might want to set this explicitly to `IPV4_ONLY` to prevent IPv6 leaks. 
     - **Action**: If you are certain your VPN supports IPv6 securely, you can leave it as is. Otherwise, set it to `IPV4_ONLY`.

2. **Proxy Settings (InternetConnectionSettings: Proxy Vole Autodetection)**:
   - **Current Setting**: Unchecked
   - **Recommendation**: If you use a proxy with your VPN, ensure that this is correctly configured. Since it’s unchecked and if you are not using a proxy, this is fine.
     - **Action**: Leave it unchecked if no proxy is used. Ensure that JDownloader is directly routing through the VPN interface (`tun0`).

3. **Custom Proxy List (InternetConnectionSettings: Custom Proxy List)**:
   - **Current Setting**: Appears to be empty (`null`).
   - **Recommendation**: If you are not using a proxy, this should remain empty. If you use a SOCKS or HTTP proxy provided by the VPN, add it here.
     - **Action**: Confirm that this remains empty if you are not using any proxies.

4. **Connection Timeouts (InternetConnectionSettings: Http Read Timeout, Http Connect Timeout)**:
   - **Current Setting**: 
     - **Http Read Timeout**: `60000` ms (60 seconds)
     - **Http Connect Timeout**: `20000` ms (20 seconds)
   - **Recommendation**: These timeouts seem reasonable for general use. They determine how long JDownloader waits before timing out a connection or read operation.
     - **Action**: No changes needed unless you experience timeouts that interrupt downloads.

5. **Reconnect Settings**:
   - **Reconnect: Auto Reconnect**:
     - **Current Setting**: Checked
     - **Recommendation**: Ensure that if the VPN disconnects, JDownloader pauses or stops downloading to prevent traffic from leaking through your regular connection.
     - **Action**: Test and ensure that if the VPN drops, JDownloader’s traffic stops until the VPN reconnects.

6. **Router IP Check**:
   - **Current Setting**: `SYSTEM` (or using external service for IP checks)
   - **Recommendation**: JDownloader may check your public IP to determine if it has changed (e.g., after a reconnect). Ensure that this check is only performed through the VPN.
     - **Action**: Ensure that the IP checks only occur over the VPN.

7. **Device Connect Ports**:
   - **Current Setting**: `[80,10101]`
   - **Recommendation**: These are the ports used by JDownloader for device connections. Ensure that these ports are not exposed externally if not necessary.
     - **Action**: If these are used for internal network communication only, restrict access to them via your firewall.

### Steps to Verify Configuration

1. **Test JDownloader with VPN**:
   - Start a download in JDownloader with the VPN connected and monitor the traffic on `tun0` using a tool like `iftop` or `tcpdump`:
     ```bash
     sudo iftop -i tun0
     ```
   - Verify that all download traffic is passing through the VPN interface.

2. **Check for DNS Leaks**:
   - While the VPN is active and JDownloader is downloading, visit a DNS leak test website (e.g., dnsleaktest.com) to verify that DNS requests are only routed through the VPN's DNS server.

3. **Simulate VPN Disconnection**:
   - Temporarily disconnect the VPN and check if JDownloader continues downloading. Ideally, downloads should pause or stop to prevent any traffic from leaking.

4. **Inspect Logs**:
   - Review JDownloader's logs (if available) to ensure there are no errors or warnings regarding connection settings or VPN usage.

### Adjustments Based on Results

- **If traffic leaks or continues when the VPN disconnects**: Consider setting JDownloader to bind explicitly to the `tun0` interface using a custom routing or proxy setup.
- **If DNS leaks are detected**: Ensure that all DNS queries are routed through the VPN's DNS server by configuring DNS settings in JDownloader or enforcing system-level DNS settings through the VPN.


---


#### **Steps to Disable mDNS:**
1. **Edit `resolved.conf`:**
   - You've already set `MulticastDNS=no` in `/etc/systemd/resolved.conf`. This is the correct setting to disable mDNS in `systemd-resolved`.
   - Ensure `LLMNR` is also set to `no` to avoid potential issues with local network discovery:
     ```ini
     [Resolve]
     LLMNR=no
     MulticastDNS=no
     DNSSEC=yes
     DNSOverTLS=yes
     DNSStubListener=no
     ```
2. **Restart `systemd-resolved`:**
   - After making these changes, restart the `systemd-resolved` service:
     ```bash
     sudo systemctl restart systemd-resolved
     ```
3. **Check for mDNS Activity:**
   - To verify that mDNS is disabled and not listening on port `5355`, check the active services again:
     ```bash
     sudo ss -tunlp | grep 5355
     ```
   - If no results are returned, mDNS is correctly disabled.


---


- **Check DNS Configuration:**
  - Run `resolvectl status` to ensure that DNSSEC and DNSOverTLS are correctly configured and that the system is using your desired DNS servers.

### Analysis and Next Steps

Based on the provided `resolvectl status` output and your current network configuration:

1. **LLMNR Enabled**:
   - LLMNR is still enabled globally (`+LLMNR`) and on both `enp2s0` (Ethernet) and `tun0` (VPN).
   - This suggests that your network setup or ExpressVPN's configuration may rely on LLMNR for DNS resolution, especially given the issues you encountered when disabling it.

2. **DNS over TLS (DoT) and DNSSEC**:
   - Both DNS over TLS (`+DNSOverTLS`) and DNSSEC (`DNSSEC=yes/supported`) are enabled and working, which is good for securing DNS queries.

3. **ExpressVPN Managing `/etc/resolv.conf`**:
   - Since ExpressVPN manages `/etc/resolv.conf` via a symlink, it's likely controlling the DNS settings, which might also explain the reliance on LLMNR.

4. **`/etc/hosts` Configuration**:
   - The `/etc/hosts` file is standard, mapping `localhost` and your machine's hostname (`theworkpc`). No issues here, but it won't impact DNS settings or the LLMNR situation.

### Reintroducing `dnsmasq` for Local DNS Caching

`dnsmasq` can be a valuable tool for managing DNS locally, reducing reliance on LLMNR, and improving network performance by caching DNS queries.

#### **Steps to Reintroduce `dnsmasq` and Adjust DNS Configuration**:

1. **Install and Configure `dnsmasq`**:
   - Install `dnsmasq`:
     ```bash
     sudo pacman -S dnsmasq
     ```
   - Configure `dnsmasq` to act as a DNS cache and forwarder. Edit `/etc/dnsmasq.conf` to include the following:
     ```ini
     listen-address=127.0.0.1
     bind-interfaces
     server=1.1.1.1
     server=9.9.9.9
     server=8.8.8.8
     ```
   - These `server` entries point to reliable DNS providers (Cloudflare, Quad9, Google). Adjust as needed.

2. **Update `/etc/resolv.conf`**:
   - Since ExpressVPN manages `/etc/resolv.conf`, you’ll need to configure it to point to `dnsmasq` for local DNS resolution.
   - Edit or override the `resolv.conf` settings:
     ```bash
     sudo ln -sf /run/dnsmasq/resolv.conf /etc/resolv.conf
     echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
     ```

3. **Adjust `systemd-resolved` Settings**:
   - Disable LLMNR and ensure `dnsmasq` is used for DNS resolution:
     ```ini
     [Resolve]
     LLMNR=no
     MulticastDNS=no
     DNSSEC=yes
     DNSOverTLS=yes
     DNSStubListener=no
     ```
   - Restart `systemd-resolved`:
     ```bash
     sudo systemctl restart systemd-resolved
     ```

4. **Restart `dnsmasq`**:
   - Start and enable `dnsmasq`:
     ```bash
     sudo systemctl enable dnsmasq
     sudo systemctl start dnsmasq
     ```

5. **Test Connectivity**:
   - Check the DNS settings again with:
     ```bash
     resolvectl status
     ```
   - Verify internet connectivity and DNS resolution. If everything works correctly, `dnsmasq` should be handling DNS queries locally, potentially eliminating the need for LLMNR.

6. **Monitor the System**:
   - After implementing these changes, monitor the system for any connection issues. If the system remains stable with LLMNR disabled, then the issue has likely been resolved.

### Conclusion:
- **dnsmasq** should help manage DNS more effectively, potentially allowing you to disable LLMNR without losing network connectivity.
- This setup provides more control over your DNS configuration while still leveraging ExpressVPN's DNS settings.


---


It looks like you've made significant progress in configuring your DNS settings. Here's a breakdown of the current status and next steps:

### Current Status

1. **Global Settings**:
   - **LLMNR and mDNS**: Both are disabled globally (`-LLMNR -mDNS`), which is what we aimed for.
   - **DNS over TLS (DoT) and DNSSEC**: Both are enabled (`+DNSOverTLS DNSSEC=yes/supported`), which ensures that your DNS queries are encrypted and validated.

2. **`resolv.conf` Mode**:
   - The `resolv.conf mode` is shown as `missing`, which indicates that the system is currently not using or cannot find a `/etc/resolv.conf` file. This is likely due to the changes we made with ExpressVPN handling the DNS configuration. This might need addressing if you notice any connectivity issues.

3. **Link-Specific Settings**:
   - **Link 2 (enp2s0)**: This is your Ethernet connection, using DNS server `192.168.1.1`, which seems to be your local network's DNS server (likely your router).
   - **Link 15 (tun0)**: This is your VPN connection, but currently, it has no DNS scopes (`none`) set. This might imply that DNS queries aren't being routed over the VPN, which could lead to potential DNS leaks.

### Next Steps

#### 1. **Addressing the `resolv.conf` Issue**:
   - Since `resolv.conf` is `missing`, it's essential to ensure that the system correctly resolves DNS queries. The lack of a valid `resolv.conf` file might lead to DNS resolution issues.
   - Given that ExpressVPN manages DNS, we could try to link or create the `/etc/resolv.conf` file to ensure it points to the proper DNS resolver:
     ```bash
     sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
     ```

   - Alternatively, you can let ExpressVPN handle `/etc/resolv.conf` as it usually does by re-enabling the symlink ExpressVPN uses. Ensure it is correctly pointing to their configuration:
     ```bash
     sudo ln -sf /path/to/expressvpn/resolv.conf /etc/resolv.conf
     ```
     (Replace `/path/to/expressvpn/resolv.conf` with the actual path ExpressVPN uses.)

#### 2. **Ensure DNS Queries Are Routed Through VPN**:
   - For privacy, DNS queries should be routed through the VPN interface (`tun0`). The fact that `tun0` has `none` under `Current Scopes` may indicate that DNS queries aren't going through the VPN.
   - We should ensure that `tun0` is handling DNS queries:
     - Reconfigure ExpressVPN to ensure DNS queries are routed through the VPN.
     - Alternatively, you can manually set DNS servers for `tun0` if needed, but this might conflict with ExpressVPN's configuration.

   - To manually add DNS for `tun0`, you might use:
     ```bash
     sudo resolvectl dns tun0 100.64.100.1  # Assuming this is ExpressVPN's DNS server
     ```

#### 3. **Test DNS Resolution**:
   - Once these steps are complete, test DNS resolution again:
     ```bash
     resolvectl query example.com
     ```
   - Ensure that the queries are being routed through `tun0` by checking the output.

#### 4. **Verify No DNS Leaks**:
   - You can use an online DNS leak test tool to ensure that all DNS queries are correctly routed through the VPN without leaking through your ISP.

### Conclusion

These steps should address the issues with `resolv.conf` and ensure that DNS queries are securely routed through the VPN. Would you like to proceed with these steps, or do you need additional information or support?



---


Your latest `resolvectl status` output shows the following:

### Current Status

1. **Global Settings**:
   - **LLMNR and mDNS**: Both are disabled globally, which is good for minimizing unnecessary local network traffic and potential exposure.
   - **DNS over TLS (DoT) and DNSSEC**: Both are enabled, ensuring that your DNS queries are encrypted and validated.
   - **resolv.conf mode: uplink**: This indicates that your DNS configuration is being managed upstream, likely by ExpressVPN or your network setup.

2. **Link 2 (enp2s0)**:
   - This is your Ethernet connection. It's using your local DNS server (`192.168.1.1`), which is likely your router.
   - DNS over TLS and DNSSEC are both enabled, which means that even local queries are secured.

3. **Link 15 (tun0)**:
   - This is your VPN connection. However, it still shows `Current Scopes: none`, meaning that DNS queries are not being routed through the VPN. This could lead to potential DNS leaks, where your DNS queries might not be as secure as expected.

### Next Steps

#### 1. **Ensure DNS Queries Are Routed Through VPN (`tun0`)**:
   - We need to make sure that DNS queries are correctly routed through the VPN interface to avoid DNS leaks. This can be done by configuring your VPN client or by manually setting DNS servers for the `tun0` interface.

##### **Option A: Reconfigure ExpressVPN to Handle DNS Properly**:
   - Ensure that ExpressVPN is configured to route DNS queries through the VPN. This typically involves:
     - Verifying ExpressVPN's configuration files.
     - Ensuring that ExpressVPN is not only routing traffic through the VPN but also handling DNS queries through the `tun0` interface.

##### **Option B: Manually Set DNS for `tun0`**:
   - If ExpressVPN does not automatically route DNS queries through `tun0`, you can manually configure DNS for the VPN interface:
     ```bash
     sudo resolvectl dns tun0 100.64.100.1
     ```
   - This command sets the DNS server for `tun0` to `100.64.100.1`, which is the DNS server typically provided by ExpressVPN.

   - You can also set the DNS domain for `tun0`:
     ```bash
     sudo resolvectl domain tun0 expressvpn
     ```

#### 2. **Verify DNS Routing**:
   - After configuring the DNS settings, check that DNS queries are correctly routed through the VPN:
     ```bash
     resolvectl status
     resolvectl query example.com
     ```
   - Ensure that the `tun0` interface is handling DNS queries and that your queries are not leaking outside the VPN.

#### 3. **Check for DNS Leaks**:
   - Use an online DNS leak test tool to confirm that your DNS queries are securely routed through the VPN without leaking through your ISP.

### Conclusion

These steps should help ensure that your DNS queries are securely routed through the VPN, preventing any potential DNS leaks and ensuring that your DNS settings are fully secured.

Would you like to proceed with these steps, or do you need further clarification or assistance with any of the configurations?



---


Your `resolvectl status` now shows that both your `enp2s0` (Ethernet) and `tun0` (VPN) interfaces have proper DNS configurations. Here's what it means:

### Summary of Current Status

1. **Global Settings**:
   - **LLMNR and mDNS**: Disabled globally, which is good for reducing unnecessary local traffic and minimizing exposure.
   - **DNS over TLS (DoT) and DNSSEC**: Both are enabled globally, ensuring that your DNS queries are encrypted and validated.

2. **Link 2 (enp2s0)**:
   - **DNS Server**: 192.168.1.1 (your local router).
   - **DNS Domain**: `lan` (your local network domain).
   - **DNS over TLS**: Enabled.
   - **DNSSEC**: Enabled.

3. **Link 15 (tun0)**:
   - **DNS Server**: 100.64.100.1 (ExpressVPN's DNS server).
   - **DNS Domain**: `expressvpn` (your VPN domain).
   - **DNS over TLS**: Enabled.
   - **DNSSEC**: Enabled.

### DNS Query Result

Running `resolvectl query google.com` should show a successful DNS resolution through the `tun0` interface, confirming that your DNS queries are routed through the VPN's DNS server.

### What This Means

- **DNS Routing**: Your DNS queries are now correctly routed through the VPN (`tun0`), which is what we aimed for. This setup should prevent DNS leaks, ensuring that all your internet traffic, including DNS queries, is securely routed through the VPN.
- **Security**: With DNSSEC and DNS over TLS enabled, your DNS queries are both encrypted and validated, adding an extra layer of security.

### Next Steps

1. **Check for DNS Leaks**: Use an online DNS leak test tool to verify that all DNS queries are indeed being routed through the VPN and that no queries are leaking through your local ISP.
2. **Monitor Connectivity**: Keep an eye on your network connectivity and DNS resolution to ensure everything remains stable.
3. **Review Any Applications**: If you have specific applications (like JDownloader), you should verify that they are also routing their DNS queries through the VPN by checking their network traffic.

### Conclusion

Your DNS configuration looks correct and secure now. If everything is functioning as expected, you've successfully ensured that your system is secure from DNS leaks and is using the appropriate VPN DNS server.

Is there anything else you'd like to check or configure?


