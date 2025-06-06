#!/bin/bash
# shellcheck disable=all
#
# Output one or more lines of information about
#   - wireless LAN
#   - ethernet controller
#   - display controller
#   - VGA compatible controller
#   - CPU
#   - is running in virtualbox vm
# device.
#
# This command can be used e.g. with programs and scripts that
# make decisions based on certain hardware,
# or finding information about certain hardware.

Usage() {
    test -n "$1" && echo "Error: $1." >&2

    cat <<EOF >&2
Usage: $progname option
where
   --wireless
   --wifi         shows info about the wireless LAN device
   --ethernet     shows info about the ethernet controller
   --display      shows info about the display controller
   --nvidia-gpuid shows the id (4 hex numbers, lowercase) of the installed Nvidia card
   --vga          shows info about the VGA compatible controller and 3D controller
   --graphics     same as both --vga and --display
   --cpu          shows the name of the CPU type
   --vm           if running in VM, echoes the name of the VM (virtualbox, qemu, vmware)
   --virtualbox   echoes "yes" is running in VirtualBox VM, otherwise "no"
EOF
}

NvidiaGpuId() {
    local -r NVIDIA="10de"
    lspci -vnn | grep -P 'VGA|Display|3D' | grep "\[$NVIDIA:" | sed "s|.*\[$NVIDIA:\([0-9a-f]*\).*|\1|"
}
PCI_info() {
    # Many search strings may be given - show all results.
    local result
    for str in "$@" ; do
        result="$(lspci | grep "$str" | sed 's|^.*'"$str"'||')"
        if [ -n "$result" ] ; then
            echo "$result"
        fi
    done
}
CPU_info() {
    # lscpu | grep "^Vendor ID:" | awk '{print $3}'
    grep -m1 -w "^vendor_id" /proc/cpuinfo | awk '{print $3}'
}

InVirtualBox() {
    if [ "$(InVm)" = "virtualbox" ] ; then
        echo yes
    else
        echo no
    fi
    #test -n "$(lspci | grep "VirtualBox Graphics Adapter")" && echo yes || echo no
}

InVm() {
    local vmname="$(systemd-detect-virt --vm)"
    case "$vmname" in
        oracle)
            echo virtualbox ;;
        qemu | kvm | vmware)
            echo $vmname ;;
    esac
    return

    # old implementation:
    case "$(lspci -vnn)" in
        *" QEMU "*)   echo qemu ;;
        *VirtualBox*) echo virtualbox ;;
        *VMware*)     echo vmware ;;        # this should be the last here!
    esac
}

EthernetShow() {
    local name="$1"
    local value="$2"
    printf "%-15s : %s\n" "$name" "$value"
}
Ethernet() {
    local devstring="Ethernet controller"
    local data=$(lspci -vnn | sed -n "/$devstring/,/^$/p")

    local card=$(  echo "$data" | grep -w "$devstring")
    local id=$(    echo "$card" | sed 's|.*\[\([0-9a-f:]*\)\].*|\1|')
    local driver=$(echo "$data" | grep 'Kernel driver in use' | awk '{print $NF}')

    EthernetShow "card id"       "$id"
    EthernetShow "card info"     "$card"
    EthernetShow "driver in use" "$driver"
}

Options() {
    opts="$(/bin/getopt -o="$SO" --longoptions "$LO,$LO2" --name "$progname" -- "$@")" || {
        Usage
        return 1
    }
    eval set -- "$opts"

    while true ; do
        case "$1" in
            --cpu)                 CPU_info ;;
            --display)             PCI_info " Display controller: " ;;
            --ethernet)            Ethernet ;;
            --graphics)            $FUNCNAME --vga ; $FUNCNAME --display ;;
            --nvidia-gpuid)        NvidiaGpuId ;;
            --vga)                 PCI_info " VGA compatible controller: " " 3D controller: " ;;
            --virtualbox)          InVirtualBox ;;
            --vm)                  InVm ;;
            --wifi | --wireless)   PCI_info " Network controller: " ;;

            --help | -h)           Usage; return 0 ;;

            --dump-options)        echo "${SO//?/-& }--${LO//,/ --} --${LO2//,/ --}"
                                   ## - LO may *not* be empty
                                   ## - SO handling requires 'patsub_replacement' enabled by 'shopt'
                                   ;;

            --)                    shift; break ;;
            *)                     Usage "unsupported option '$1'"
                                   return 1
                                   ;;
        esac
        shift
    done
}

Main()
{
    local -r progname="${0##*/}"
    local -r LO="cpu,display,ethernet,graphics,help,nvidia-gpuid,vga,virtualbox,vm,wifi,wireless"
    local -r LO2="dump-options"
    local -r SO="h"
    local opts
    
    test -n "$1" || { Usage "option missing" ; return 1 ; }

    Options "$@"
}

Main "$@"
