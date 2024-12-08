EXPRESSVPN(1)                                 General Commands Manual                                 EXPRESSVPN(1)

NAME
       expressvpn - A command line interface to the ExpressVPN service

SYNOPSIS
       expressvpn command [args]

DESCRIPTION
       The expressvpn command provides a command line interface to the ExpressVPN.

COMMANDS
       expressvpn activate
              Activates  ExpressVPN  account.  You  can  find  your  ExpressVPN  activation code at https://www.ex‐
              pressvpn.com/subscriptions/.

       expressvpn connect
              Connects to the most recently connected location, or to Smart Location if there is no  recently  con‐
              nected location.

       expressvpn connect smart
              Connects to Smart Location, designed to deliver reliable speeds based on your location.

       expressvpn connect COUNTRY
              Connects  to  the  top-recommended location in the specified country. For example: expressvpn connect
              "Germany"

       expressvpn connect ALIAS
              Connects to the specified location. For example: expressvpn connect usla

       expressvpn connect LOCATION
              Connects to the specified location. For example: expressvpn connect "Germany - Frankfurt - 1"

       expressvpn disconnect
              Disconnects current VPN connection.

       expressvpn list
              Prints all available VPN servers locations.

       expressvpn list recommended
              Prints all recommended VPN servers locations.

       expressvpn list recent
              Prints last 3 recently connected VPN servers locations.

       expressvpn status
              Prints out the current status of the ExpressVPN daemon.

       expressvpn autoconnect [true | false]
              Auto connect to last used location on system start.

       expressvpn protocol [PROTOCOL]
              Changes preferred protocol. PROTOCOL is one  of  'auto',  'lightway_udp',  'lightway_tcp',  'udp'  or
              'tcp'. If no protocol is provided, prints current preferred protocol.

       expressvpn refresh
              Refreshes VPN server locations and account information. This is done automatically every 3 hours.

       expressvpn logout
              Logout ExpressVPN account by deactivating and removing preferences.

       expressvpn diagnostics
              Prints connection diagnostics.

       expressvpn preferences
              Prints current preferences.

       expressvpn preferences set PREFERENCE VALUE
              Sets PREFERENCE to a VALUE.

       expressvpn help
              Shows a list of commands or help for one command.

OPTIONS
       --help, -h
              Shows a list of commands or help for one command.

       --version
              Prints the version.

RECONNECT
       ExpressVPN will attempt to automatically reconnect to VPN if the connection is interrupted.

NETWORK LOCK AND LEAK PROTECTION
       ExpressVPN  supports  various  preferences  for ensuring your Internet traffic and private information don't
       leak both whilst connected and during reconnection (should the VPN connection be disrupted).

       The preferences are described below. Each can be set using expressvpn preferences set.

       Note that all of the preferences except ipv6_protection require iptables(8) to be installed. If  iptables(8)
       isn't available then these preferences will be unavailable.

   NETWORK LOCK
       Once connected, firewall rules will be put in place to prevent IP traffic from leaving the device except via
       the VPN tunnel. These rules prevent leaks during reconnection. If reconnection fails terminally then the ap‐
       plication  will  leave  the firewall rules up to protect you from leaks. This will mean your network will be
       disabled.

       To determine if ExpressVPN is blocking your internet traffic, run expressvpn  status.  If  your  network  is
       blocked then you can unblock it either by running expressvpn disconnect or expressvpn connect.

       There are three possible network_lock modes: off, strict and default.

       off    Network Lock is disabled.

       strict All traffic will be blocked if ExpressVPN disconnects unexpectedly.

       default
              Blocks  all  internet  traffic,  but  allow traffic to local (private) IP address ranges (10.0.0.0/8,
              172.16.0.0/12, 192.168.0.0/16). This is useful, for example, for communicating with printers on  your
              local network. This is the default mode.

   IPV6 LEAK PROTECTION
       Disables  ipv6  in  the kernel to prevent IPv6 addresses leaking out, e.g. via WebRTC. Since ExpressVPN only
       supports an IPv4 tunnel, enabling this setting should have no impact on your system. IPv6 Leak protection is
       enabled by default.

       To disable IPv6 Leak protection
              expressvpn preferences set ipv6_protection false

       To enable IPv6 Leak protection again
              expressvpn preferences set ipv6_protection true

   ADVANCED PROTECTION
       Uses DNS filtering to prevent any part of this device from communicating with domains listed on  our  block‐
       lists  of  ads, trackers, malicious sites, and adult content. This protects you from any apps on your device
       (or any websites you visit) attempting to share your activity with these unwanted third parties.  We  update
       our blocklists regularly with each new app version.

       Advanced  protection features are only active when the VPN is connected and the protocol is set to Automatic
       or Lightway.

       •   To learn more, visit https://www.expressvpn.com/features/advanced-protection

       •   To enable advanced protection features:

       •   'expressvpn preferences set block_all true' to block ads, trackers, malicious and adult sites

       •   'expressvpn preferences set block_ads true' to block ads

       •   'expressvpn preferences set block_trackers true' to block trackers

       •   'expressvpn preferences set block_malicious true' to block malicious sites

       •   'expressvpn preferences set block_adult true' to block adult sites

EXAMPLES
       To activate ExpressVPN account
              expressvpn activate

       To connect to smart location or last connected location
              expressvpn connect

       To connect to a country
              expressvpn connect "Germany"

       To connect to a specific location
              expressvpn connect "Germany - Frankfurt - 1"

       To check current connection status
              expressvpn status

FOR GRAPHICAL INTERFACE
       Control ExpressVPN with our browser extension, which protects your whole device.

       •   For Chrome, run expressvpn install-chrome-extension.

       •   For Firefox, run expressvpn install-firefox-extension.

SUPPORTED PROTOCOLS
       auto: Automatic (recommended)
              ExpressVPN will automatically pick the protocol most appropriate for your network.

       lightway_udp: Lightway - UDP
              ExpressVPN's next-generation protocol, optimized for speed, security, and reliability.

       lightway_tcp: Lightway - TCP
              May be slower than Lightway - UDP but connects better on certain networks.

       udp: OpenVPN - UDP
              Good combination of speed and security, but may not work on all networks.

       tcp: OpenVPN - TCP
              Likely to function on all types of networks, but might be slower than OpenVPN - UDP.

   ADVANCED PROTOCOL OPTIONS
       The Lightway encryption cipher may affect VPN connection speeds.

       auto (recommended)
              ExpressVPN will automatically pick the cipher most appropriate for your  device:  expressvpn  prefer‐
              ences set lightway_cipher auto

       aes    expressvpn preferences set lightway_cipher aes

       chacha20
              expressvpn preferences set lightway_cipher chacha20

RESOURCES
       •   ExpressVPN https://www.expressvpn.com/

       •   ExpressVPN Setup Guide https://www.expressvpn.com/support/vpn-setup/app-for-linux

       •   ExpressVPN Support https://www.expressvpn.com/support

       •   ExpressVPN Support E-mail support@expressvpn.com

ACKNOWLEDGEMENTS
       ExpressVPN  is  made  possible  by  the OpenVPN open source project and other open source softwares. See the
       COPYRIGHT file distributed with the application for full acknowledgements.

COPYRIGHT
       Copyright (C) 2009-2024 ExpressVPN. All rights reserved.

ExpressVPN                                           July 2024                                        EXPRESSVPN(1)
