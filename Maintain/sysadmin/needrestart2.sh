#!/bin/bash

last_chboot()                 { date -r /boot +%s; }
last_chboot_hr()              { date -r /boot +'%F %T'; }
last_reboot()                 { date -r /proc +%s; }
last_reboot_hr()              { date -r /proc +'%F %T'; }
upgraded_boot()               { (( $(last_chboot) > $(last_reboot) )); }
upgraded_boot_hr()            { upgraded_boot && echo "yes" || echo "no"; }
currently_booted_image()      { grep -Po 'BOOT_IMAGE=/@\K\S+' /proc/cmdline; }
currently_running_kernel()    { uname -r; }
currently_installed_kernel()  { file $(currently_booted_image) | grep -Po 'version \K\S+'; }
currently_installed_kernels() { file /boot/vmlinuz* | grep -Po 'version \K\S+' | paste -sd ' '; }
upgraded_running_kernel()     { [[ $(currently_running_kernel) != $(currently_installed_kernel) ]]; }
upgraded_running_kernel_hr()  { upgraded_running_kernel && echo "yes" || echo "no"; }
upls2() {
    local updatesAUR=$(paru -Qua)
    local updates=$(checkupdates)

    # output RESULT
    if [ -n "$updates" ] || [ -n "$updatesAUR" ]; then
		echo "Repo packages"
		echo "-------------"
		{
		     echo "$updates"
		} | column -t -N Name,Current,"->",New
        echo " "
        if [ -n "$updatesAUR" ]; then
            echo " "
            echo "AUR Packages"
            echo "------------"
            {
                echo "$updatesAUR"
            } | column -t -N Name,Current,"->",New
        fi

 	#check for core system packages
	RUN_KERNEL=$(cat /proc/version | sed 's|.*(\([^@]*\)@archlinux).*|\1|')
	CHKLINE="amd-ucode\|intel-ucode\|btrfs-progs\|cryptsetup\|nvidia*\|mesa\|systemd*\|*wayland*\|xf86-video-*\|xorg-server*\|xorg-fonts*"
	CHKLINE+="\|""${RUN_KERNEL}"

	echo " "
	echo $updates | grep -q ${CHKLINE} && echo "Reboot will be recommended due to the upgrade of core system package(s)." || echo "No reboot recommended after this update."
    else
        echo "No pending updates..."
    fi
}

# NOTE: $1=pid $6=pathname $7="(deleted)"
awk_uniq_del_paths_simple() { # unused, no command / user name, only pathname and list of pids
  awk '$6 && $7 {pathpids[$6]=(pathpids[$6] " " $1)} END {for (pp in pathpids) print pp " " pathpids[pp]}';
}
awk_uniq_del_paths() {
  awk ' $6 && $7 {pathpids[$6][$1]=""}
        END {
          for (path in pathpids) for (pid in pathpids[path]) {
            if (getline uid < ("/proc/" pid "/loginuid")) {
              ("id -nu " uid) | getline user
              getline comm < ("/proc/" pid "/comm")
              print pid " " comm " " uid " " user " " path
            }
          }
        }
      '
}
upgraded_mapped_executables() {
  trap "$(shopt -p nullglob)" RETURN; shopt -s nullglob
  local p
  for p in /proc/{1..9}*; do
    sed -En '/^\S+ +..x. .*[^]]$/ {s/^\S+/'"${p:6}"'/;p}' "$p/maps" 2>&-
  done | awk_uniq_del_paths
}
upgraded_mapped_executables_hr() {
  echo # just to simplify printing function names and results
  upgraded_mapped_executables | column -t -N'pid,comm,uid,user,path' -R1,3
}

return 0 2>&- # exit if sourced

for fn in currently_{booted_image,running_kernel,installed_kernel{,s}} last_{ch,re}boot_hr upgraded_{boot,running_kernel,mapped_executables}_hr; do
  printf '%-32s : ' "$fn"; $fn
done
upls2