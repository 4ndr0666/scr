#!/bin/bash
# shellcheck disable=all

VPN_SERVERS=(
  "smart"
  "hk2"
  "hk1"
  "usda"
  "usny"
  "usla2"
  "uswd"
  "usse"
  "usph"
  "usnj1"
  "usla1"
  "ussf"
  "usmi"
  "usmi2"
  "usla3"
  "usnj3"
  "usat"
  "usde"
  "uslp"
  "usho"
  "usal"
  "sgju"
  "sgcb"
  "inuk"
  "insi"
  "ausy"
  "aume"
  "auwo"
  "aubr"
  "aupe"
  "auad"
  "cato2"
  "cato"
  "camo"
  "defr3"
  "defr1"
  "denu"
  "mx"
  "ukdo"
  "uklo"
  "ukel"
  "ukmi"
  "nlam"
  "nlro"
  "nlth"
  "esma"
  "esba2"
  "ie"
  "frpa2"
  "frma"
  "itco"
)

random_server() {
  SERVER=${VPN_SERVERS[$RANDOM % ${#VPN_SERVERS[@]}]}
  expressvpn connect $SERVER
}

while true; do
  random_server
done

