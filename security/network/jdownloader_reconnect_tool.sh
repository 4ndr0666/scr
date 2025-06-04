#!/bin/bash
# shellcheck disable=all

# List of VPN servers to cycle through
VPN_SERVERS=(
  "smart" "hk2" "hk1" "usda" "usny" "usla2" "uswd" "usse" "usph" "usnj1"
  "usla1" "ussf" "usmi" "usmi2" "usla3" "usnj3" "usat" "usde" "uslp"
  "usho" "usal" "usch" "ussl1" "usta1" "usnj2" "usla5" "ussm" "sgju"
  "sgcb" "sgmb" "inuk" "insi" "ausy" "aume" "auwo" "aubr" "aupe" "auad"
  "ausy2" "jpto" "jpsh" "jpyo" "jpos" "cato2" "cato" "camo" "cava" "kr2"
  "ph" "my" "defr3" "defr1" "denu" "lk" "pk" "kz" "mx" "th" "id" "ukdo"
  "uklo" "ukel" "ukmi" "ukwe" "nz" "tw3" "vn" "mo" "nlam" "nlro" "nlth"
  "kh" "mn" "la" "esma" "esba2" "esba" "mm" "ie" "np" "frpa2" "frma"
  "frpa1" "frst" "fral" "gu" "uz" "bd" "bt" "bnbr" "xv" "itco" "itmi"
  "itna" "br2" "br" "pa" "cl" "ar" "bo" "cr" "co" "ve" "ec" "gt" "pe"
  "uy" "bs" "do" "jm" "pr" "bm" "tt" "ky" "cu" "hn" "se" "se2" "ch"
  "ch2" "ro" "im" "tr" "is" "no" "dk" "be" "fi" "gr" "pt" "at" "am"
  "pl" "lt" "lv" "ee" "cz" "ad" "me" "ba" "lu" "hu" "bg" "by" "ua" "mt"
  "li" "cy" "al" "si" "sk" "mc" "je" "mk" "md" "rs" "ge" "gh" "lb"
  "ma" "za" "il" "eg" "dz" "ke"
)

# Function to select a random VPN server
random_server() {
  SERVER=${VPN_SERVERS[$RANDOM % ${#VPN_SERVERS[@]}]}
  echo "Attempting to connect to $SERVER"
  expressvpn disconnect
  
  # Check if the disconnect was successful
  if [ $? -eq 0 ]; then
    echo "Disconnected successfully from previous VPN"
  else
    echo "Failed to disconnect from previous VPN"
  fi
  
  expressvpn refresh
  
  # Check if the refresh was successful
  if [ $? -eq 0 ]; then
    echo "VPN refreshed successfully"
  else
    echo "Failed to refresh VPN"
  fi
  
  expressvpn connect $SERVER
  
  # Check if the connection was successful
  if [ $? -eq 0 ]; then
    echo "Connected successfully to $SERVER"
  else
    echo "Failed to connect to $SERVER"
  fi
}

# Infinite loop to keep reconnecting
while true; do
  random_server
  # Sleep for a few seconds to avoid rapid reconnections
  sleep 60
done
