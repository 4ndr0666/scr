# Aliases

alias highlight='highlight --out-format=ansi'
alias showpath='echo $PATH | tr ":" "\n"'
alias rsync='rsync -avrPlU --progress'
alias grub-mkconfig='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias grepc='grep --color=always'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias lessc='less -R'
alias ip='ip -color=auto'
alias c='clear; echo; echo; seq 1 $(tput cols) | sort -R | spark | lolcat; echo; echo'
alias hw='sudo hwinfo --short'
alias lsblk='lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT'
alias lsblkh='lsblk.sh'
alias psa='ps auxf | less'
alias free='free -mt'
alias jctl='journalctl -p 3 -xb'
alias mapit="ifconfig -a | grep -Po '\b(?!255)(?:\d{1,3}\.){3}(?!255)\d{1,3}\b' | xargs nmap -A -p0-"
alias ports='netstat -tulanp'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'
alias netspeed='ifstat -t -S -w'
alias iotop='sudo iotop -o'
alias netwatch='sudo nethogs'
alias addlbin='export PATH=/home/andro/.local/bin:$PATH'
alias whatkernel="ls /usr/lib/modules"
alias dir5='du -cksh * | sort -hr | head -5'
alias dir10='du -cksh * | sort -hr | head -10'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias z='zathura'
alias lf='lfub'
alias untar='sudo -S tar -xvf '
alias watch='watch '
alias top10='print -l ${(o)history%% *} | uniq -c | sort -nr | head -n 10'
alias pacdiff='sudo -H DIFFPROG=meld pacdiff'
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias p='ps -f'
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias myip='curl icanhazip.com'
alias update-grub2='sudo grub-install && sudo grub-mkconfig -o /boot/grub/grub.cfg'

alias mkplaylist="ls -d */ > mpv_playlist.txt"
alias lb='ls | bat'
alias l1='lsd -1'
alias lr='ls -snew'
alias ls='exa -hlx --no-filesize --no-time --no-permissions --color=always --group-directories-first --icons=always'
alias la="lsd -aFlL --permission=rwx --color=always --group-dirs=first --icon=always"
alias ll='exa -xXDa --color=always  --icons=always'
alias l.='exa -ax --sort=modified --color-scale-mode=gradient --color=always --group-directories-first --icons | grep "^\."'
alias lt='tree -L 2 scr'
alias lta='ls -ltrha'

alias chown='sudo chown --preserve-root'
alias chmod='sudo chmod --preserve-root'
alias chgrp='sudo chgrp --preserve-root'
alias chgpg='sudo chown -R $USER:$USER ~/.gnupg && sudo chmod 700 ~/.gnupg && sudo chmod 600 ~/.gnupg/private-keys-v1.d/*'
alias lock='sudo chattr +i '
alias unlock='sudo chattr -i '
alias chlocal='sudo chown -R $USER:$USER ~/.config ~/.local && echo "Ownership of ~/.config and ~/.local changed to $USER."'
alias chnpm='sudo chown -R 1000:1000 /home/andro/.npm'

alias xd='ls /usr/share/xsessions'
alias xdw="ls /usr/share/wayland-sessions"
alias xfix='echo "DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority xterm"'
alias xi='sudo xbps-install'
alias xr='sudo xbps-remove -R'
alias xq='xbps-query'
alias xmerge='xrdb -merge ~/.Xresources'

alias tolightdm="sudo pacman -S lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings --noconfirm --needed ; sudo systemctl enable lightdm.service -f ; echo 'Lightdm is active - reboot now'"
alias tosddm="sudo pacman -S sddm --noconfirm --needed ; sudo systemctl enable sddm.service -f ; echo 'Sddm is active - reboot now'"
alias toly="sudo pacman -S ly --noconfirm --needed ; sudo systemctl enable ly.service -f ; echo 'Ly is active - reboot now'"
alias togdm="sudo pacman -S gdm --noconfirm --needed ; sudo systemctl enable gdm.service -f ; echo 'Gdm is active - reboot now'"
alias tolxdm="sudo pacman -S lxdm --noconfirm --needed ; sudo systemctl enable lxdm.service -f ; echo 'Lxdm is active - reboot now'"

alias btrfsfs='sudo btrfs filesystem df /'
alias btrfsli='sudo btrfs su li / -t'

alias snapcroot="sudo snapper -c root create-config /"
alias snapchome="sudo snapper -c home create-config /home"
alias snapli="sudo snapper list"
alias snapcr="sudo snapper -c root create"
alias snapch="sudo snapper -c home create"

alias fninstall="yay -S --needed --cleanafter --cleanmenu --devel --noconfirm --rebuild --refresh --sudoloop --sysupgrade --overwrite='*' --disable-download-timeout --pgpfetch=false --removemake --redownload --batchinstall=false --answerclean=yes --answerdiff=no --answeredit=no"
alias fnupdate='yay -Syyu --noconfirm --disable-download-timeout --removemake --rebuild --pgpfetch=false --bottomup --overwrite="*"'
alias fnremove='yay -Rddn --noconfirm'
alias pacmansigoff="read -p 'Are you sure you want to disable PGP signature verification? (yes/no): ' answer && if [[ \$answer == 'yes' ]]; then if sudo cp --preserve=all -f /etc/pacman.conf /etc/pacman.conf.backup; then sudo sed -i '/^SigLevel/ s/Required/Never/' /etc/pacman.conf && echo 'PGP signature verification bypassed.'; else echo 'Failed to create backup. Aborting.'; fi; else echo 'Operation canceled.'; fi"
alias pacmansigon="if [ -f /etc/pacman.conf.backup ]; then if sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf; then sudo rm /etc/pacman.conf.backup && echo 'PGP signature verification restored.'; else echo 'Failed to restore the original pacman.conf. Aborting.'; fi; else echo 'Backup file not found. Cannot restore.'; fi"

alias g='git'
alias gstat='git status'
alias gstash='git stash --all'
alias gclear='git stash clear'
alias greset="git reset --hard"
alias gfs='git-lfs'
alias grc="git rm -f --cached . && git commit -m 'Removed cached and committed'"

alias gpush='git add . && git commit -m "$*" && git pull --rebase && git push'

alias gcomp='git diff-index --quiet HEAD -- || { git add --all && git commit -m "Auto-commit: $(git status --porcelain | grep "^A" | wc -l) added, $(git status --porcelain | grep "^ M" | wc -l) modified, $(git status --porcelain | grep "^D" | wc -l) deleted" && git pull --rebase && git push; }'

alias fixkeyboard='sudo localectl set-x11-keymap us'
alias listusers='cut -d: -f1 /etc/passwd | sort'
alias setlocales='sudo localectl set-locale LANG=en_US.UTF-8'
alias microcode='grep . /sys/devices/system/cpu/vulnerabilities/*'
alias audio="pactl info | grep 'Server Name'"

alias retry='until !!; do :; done'

alias bupskel='sudo cp -Rf /etc/skel /var/recover/skel-backup-$(date +"%Y.%m.%d-%H.%M.%S") && echo "Backup of skel made."'
alias restoreskel='sudo cp -Rf /var/recover/skel-backup-*/. $HOME/ && echo "Restored from latest backup."'

alias restartnetwork='sudo systemctl restart NetworkManager'
alias restartnetwork2='sudo ip link set down enp2s0 && sudo ip link set up enp2s0'

alias ssha='eval $(ssh-agent) && ssh-add'
alias sshid='xclip -sel clip < ~/.ssh/id_ed25519.pub'

alias restartntp='sudo systemctl stop ntpd.service && sudo pacman -Syu ntp'
alias fixntp='sudo ntpd -qg && sleep 10 && sudo hwclock -w'

alias paste='wl-paste'

alias tobash="sudo chsh $USER -s /bin/bash && echo 'Now log out.'"
alias tozsh="sudo chsh $USER -s /bin/zsh && echo 'Now log out.'"
alias tofish="sudo chsh $USER -s /bin/fish && echo 'Now log out.'"

alias help-bk='bk -h'

alias magic='sudo /usr/local/bin/magic.sh'
