#!/bin/bash

# === // QUICK-SECURE.SH // ======== ||
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Symbols for visual feedback
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}

# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}

# Logging function
log() {
    echo "$(date): $1" >> /var/log/r8169_module_script.log
}

# --- Auto escalate:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Print ASCII art in green
echo -e "${GREEN}"
cat << "EOF"
#  ________        .__        __                                                                   .__
#  \_____  \  __ __|__| ____ |  | __           ______ ____   ____  __ _________   ____        _____|  |__
#   /  / \  \|  |  \  |/ ___\|  |/ /  ______  /  ___// __ \_/ ___\|  |  \_  __ \_/ __ \      /  ___/  |  \
#  /   \_/.  \  |  /  \  \___|    <  /_____/  \___ \\  ___/\  \___|  |  /|  | \/\  ___/      \___ \|   Y  \
#  \_____\ \_/____/|__|\___  >__|_ \         /____  >\___  >\___  >____/ |__|    \___  > /\ /____  >___|  /
#         \__>             \/     \/              \/     \/     \/                   \/  \/      \/     \/
EOF
echo -e "${NC}"

# --- Display disabled lines as options:
if [[ $1 = "-c" ]]; then
  echo ""
  prominent "$SUCCESS === // ENANBLED ACTIONS // === $SUCCESS"
  cat $0 | grep ^[A-Z]
  echo ""
  prominent "$FAILURE === // DISABLED ACTIONS // === $FAILURE"
  grep ^#[Aa-Zz] $0
  exit
fi

if [[ $1 = "-u" ]]; then
  echo ""
  cat $0 | sed 's/^[ \t]*//;s/[ \t]*$//' | grep '.' | grep -v ^#
  bug "Something broke"
  log "Something broke"
  exit 1
fi

# --- Env variables:
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/local/bin:/opt/local/sbin"
PASS_EXP="60" #used to set password expire in days
PASS_WARN="14" #used to set password warning in days
PASS_CHANG="1" #used to set how often you can change password in days
SELINUX=`grep ^SELINUX= /etc/selinux/config 2>/dev/null | awk -F'=' '{ print $2 }'`

# --- Disclaimer:
prominent "$INFO $EXPLOSION $EXPLOSION $EXPLOSION auto-escalating to root."

cat << 'DISC'
   === // ALWAYS REVIEW A SCRIPT BEFORE DEPLOYMENT // ===

-  quick-secure -c | Review disabled actions

-  quick-secure -u | Review enabled actions

-  quick-secure -f | Proceed with noconfirm
DISC

# --- Confirmation:
if [[ $1 != "-f" ]]; then
  prominent "$INFO Initiate fully automated deployment on target `hostname` (y/N)? "
  read ANSWER
  if [[ $ANSWER != "y" ]]; then
    echo ""
    exit
  fi

  if [[ $ANSWER = "n" ]] || [[ $ANSWER = "" ]]; then
    echo ""
    exit
  fi

  echo ""
fi

# --- Set audit group variable:
if [[ `grep -i ^audit /etc/group` != "" ]]; then
  AUDIT=`grep -i ^audit /etc/group | awk -F":" '{ print $1 }' | head -n 1`
else
  AUDIT="root"
fi

  prominent "$INFO Audit group is set to '$AUDIT' $EXPLOSION"
  echo ""


# --- Temp disable selinux:
if [[ `getenforce 2>/dev/null` = "Enforcing" ]]; then
  setenforce 0
fi

if [[ -f /etc/sysconfig/selinux ]]; then
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  echo "SELINUX=disabled" > /etc/sysconfig/selinux
  echo "SELINUXTYPE=targeted" >> /etc/sysconfig/selinux
  chmod -f 0640 /etc/sysconfig/selinux
fi

# --- Cron Job -------- ||
if [[ -f /etc/cron.allow ]]; then
  if [[ `grep root /etc/cron.allow 2>/dev/null` != "root" ]]; then
    echo "root" > /etc/cron.allow
    rm -f /etc/at.deny
  else
    prominent "$FAILURE qroot is already in /etc/cron.allow"
    echo ""
  fi
fi

if [[ -f /etc/cron.allow ]]; then
  if [[ ! -f /etc/at.allow ]]; then
    touch /etc/at.allow
  fi
fi

if [[ `grep root /etc/at.allow 2>/dev/null` != "root" ]]; then
  echo "root" > /etc/at.allow
  rm -f /etc/at.deny
else
  prominent "$FAILURE root is already in /etc/at.allow"
  echo ""
fi

if [[ `cat /etc/at.deny 2>/dev/null` = "" ]]; then
  rm -f /etc/at.deny
fi

if [[ `cat /etc/cron.deny 2>/dev/null` = "" ]]; then
  rm -f /etc/cron.deny
fi

chmod -f 0700 /etc/cron.monthly/*
chmod -f 0700 /etc/cron.weekly/*
chmod -f 0700 /etc/cron.daily/*
chmod -f 0700 /etc/cron.hourly/*
chmod -f 0700 /etc/cron.d/*
chmod -f 0400 /etc/cron.allow
chmod -f 0400 /etc/cron.deny
chmod -f 0400 /etc/crontab
chmod -f 0400 /etc/at.allow
chmod -f 0400 /etc/at.deny
chmod -f 0700 /etc/cron.daily
chmod -f 0700 /etc/cron.weekly
chmod -f 0700 /etc/cron.monthly
chmod -f 0700 /etc/cron.hourly
chmod -f 0700 /var/spool/cron
chmod -f 0600 /var/spool/cron/*
chmod -f 0700 /var/spool/at
chmod -f 0600 /var/spool/at/*
chmod -f 0400 /etc/anacrontab


# === // Perms and Ownership // ======== ||
chmod -f 1777 /tmp
chown -f root:root /var/crash
chown -f root:root /var/cache/mod_proxy
chown -f root:root /var/lib/dav
chown -f root:root /usr/bin/lockfile
chown -f rpcuser:rpcuser /var/lib/nfs/statd
chown -f adm:adm /var/adm
chmod -f 0600 /var/crash
chown -f root:root /bin/mail
chmod -f 0700 /sbin/reboot
chmod -f 0700 /sbin/shutdown
chmod -f 0600 /etc/ssh/ssh*config
chown -f root:root /root
chmod -f 0700 /root
chmod -f 0500 /usr/bin/ypcat
chmod -f 0700 /usr/sbin/usernetctl
chmod -f 0700 /usr/bin/rlogin
chmod -f 0700 /usr/bin/rcp
chmod -f 0640 /etc/pam.d/system-auth*
chmod -f 0640 /etc/login.defs
chmod -f 0750 /etc/security
chmod -f 0600 /etc/audit/audit.rules
chown -f root:root /etc/audit/audit.rules
chmod -f 0600 /etc/audit/auditd.conf
chown -f root:root /etc/audit/auditd.conf
chmod -f 0600 /etc/auditd.conf
chmod -f 0744 /etc/rc.d/init.d/auditd
chown -f root /sbin/auditctl
chmod -f 0750 /sbin/auditctl
chown -f root /sbin/auditd
chmod -f 0750 /sbin/auditd
chmod -f 0750 /sbin/ausearch
chown -f root /sbin/ausearch
chown -f root /sbin/aureport
chmod -f 0750 /sbin/aureport
chown -f root /sbin/autrace
chmod -f 0750 /sbin/autrace
chown -f root /sbin/audispd
chmod -f 0750 /sbin/audispd
chmod -f 0444 /etc/bashrc
chmod -f 0444 /etc/csh.cshrc
chmod -f 0444 /etc/csh.login
chmod -f 0600 /etc/cups/client.conf
chmod -f 0600 /etc/cups/cupsd.conf
chown -f root:sys /etc/cups/client.conf
chown -f root:sys /etc/cups/cupsd.conf
chmod -f 0600 /etc/grub.conf
chown -f root:root /etc/grub.conf
chmod -f 0600 /boot/grub2/grub.cfg
chown -f root:root /boot/grub2/grub.cfg
chmod -f 0600 /boot/grub/grub.cfg
chown -f root:root /boot/grub/grub.cfg
chmod -f 0444 /etc/hosts
chown -f root:root /etc/hosts
chmod -f 0600 /etc/inittab
chown -f root:root /etc/inittab
chmod -f 0444 /etc/mail/sendmail.cf
chown -f root:bin /etc/mail/sendmail.cf
chmod -f 0600 /etc/ntp.conf
chmod -f 0640 /etc/security/access.conf
chmod -f 0600 /etc/security/console.perms
chmod -f 0600 /etc/security/console.perms.d/50-default.perms
chmod -f 0600 /etc/security/limits
chmod -f 0444 /etc/services
chmod -f 0444 /etc/shells
chmod -f 0644 /etc/skel/.*
chmod -f 0600 /etc/skel/.bashrc
chmod -f 0600 /etc/skel/.bash_profile
chmod -f 0600 /etc/skel/.bash_logout
chmod -f 0440 /etc/sudoers
chown -f root:root /etc/sudoers
chmod -f 0600 /etc/sysctl.conf
chown -f root:root /etc/sysctl.conf
chown -f root:root /etc/sysctl.d/*
chmod -f 0700 /etc/sysctl.d
chmod -f 0600 /etc/sysctl.d/*
chmod -f 0600 /etc/syslog.conf
chmod -f 0600 /var/yp/binding
chown -f root:$AUDIT /var/log
chown -Rf root:$AUDIT /var/log/*
chmod -Rf 0640 /var/log/*
chmod -Rf 0640 /var/log/audit/*
chmod -f 0755 /var/log
chmod -f 0750 /var/log/syslog /var/log/audit
chmod -f 0600 /var/log/lastlog*
chmod -f 0600 /var/log/cron*
chmod -f 0600 /var/log/btmp
chmod -f 0660 /var/log/wtmp
chmod -f 0444 /etc/profile
chmod -f 0700 /etc/rc.d/rc.local
chmod -f 0400 /etc/securetty
chmod -f 0700 /etc/rc.local
chmod -f 0750 /usr/bin/wall
chown -f root:tty /usr/bin/wall
chown -f root:users /mnt
chown -f root:users /media
chmod -f 0644 /etc/.login
chmod -f 0644 /etc/profile.d/*
chown -f root /etc/security/environ
chown -f root /etc/xinetd.d
chown -f root /etc/xinetd.d/*
chmod -f 0750 /etc/xinetd.d
chmod -f 0640 /etc/xinetd.d/*
chmod -f 0640 /etc/selinux/config
chmod -f 0750 /usr/bin/chfn
chmod -f 0750 /usr/bin/chsh
chmod -f 0750 /usr/bin/write
chmod -f 0750 /sbin/mount.nfs
chmod -f 0750 /sbin/mount.nfs4
chmod -f 0700 /usr/bin/ldd #0400 FOR SOME SYSTEMS
chmod -f 0700 /bin/traceroute
chown -f root:root /bin/traceroute
chmod -f 0700 /usr/bin/traceroute6*
chown -f root:root /usr/bin/traceroute6
chmod -f 0700 /bin/tcptraceroute
chmod -f 0700 /sbin/iptunnel
chmod -f 0700 /usr/bin/tracpath*
chmod -f 0644 /dev/audio
chown -f root:root /dev/audio
chmod -f 0644 /etc/environment
chown -f root:root /etc/environment
chmod -f 0600 /etc/modprobe.conf
chown -f root:root /etc/modprobe.conf
chown -f root:root /etc/modprobe.d
chown -f root:root /etc/modprobe.d/*
chmod -f 0700 /etc/modprobe.d
chmod -f 0600 /etc/modprobe.d/*
chmod -f o-w /selinux/*
#umask 077 /etc/*
chmod -f 0755 /etc
chmod -f 0644 /usr/share/man/man1/*
chmod -Rf 0644 /usr/share/man/man5
chmod -Rf 0644 /usr/share/man/man1
chmod -f 0600 /etc/yum.repos.d/*
chmod -f 0640 /etc/fstab
chmod -f 0755 /var/cache/man
chmod -f 0755 /etc/init.d/atd
chmod -f 0750 /etc/ppp/peers
chmod -f 0755 /bin/ntfs-3g
chmod -f 0750 /usr/sbin/pppd
chmod -f 0750 /etc/chatscripts
chmod -f 0750 /usr/local/share/ca-certificates


# --- ClamAV permissions and ownership:
if [[ -d /usr/local/share/clamav ]]; then
  passwd -l clamav 2>/dev/null
  usermod -s /sbin/nologin clamav 2>/dev/null
  chmod -f 0755 /usr/local/share/clamav
  chown -f root:clamav /usr/local/share/clamav
  chown -f root:clamav /usr/local/share/clamav/*.cvd
  chmod -f 0664 /usr/local/share/clamav/*.cvd
  mkdir -p /var/log/clamav
  chown -f root:$AUDIT /var/log/clamav
  chmod -f 0640 /var/log/clamav
fi
if [[ -d /var/clamav ]]; then
  passwd -l clamav 2>/dev/null
  usermod -s /sbin/nologin clamav 2>/dev/null
  chmod -f 0755 /var/clamav
  chown -f root:clamav /var/clamav
  chown -f root:clamav /var/clamav/*.cvd
  chmod -f 0664 /var/clamav/*.cvd
  mkdir -p /var/log/clamav
  chown -f root:$AUDIT /var/log/clamav
  chmod -f 0640 /var/log/clamav
fi


# --- DISA STIG file ownsership:
chmod -f 0755 /bin/csh
chmod -f 0755 /bin/jsh
chmod -f 0755 /bin/ksh
chmod -f 0755 /bin/rsh
chmod -f 0755 /bin/sh
chmod -f 0640 /dev/kmem
chown -f root:sys /dev/kmem
chmod -f 0640 /dev/mem
chown -f root:sys /dev/mem
chmod -f 0666 /dev/null
chown -f root:sys /dev/null
chmod -f 0755 /etc/csh
chmod -f 0755 /etc/jsh
chmod -f 0755 /etc/ksh
chmod -f 0755 /etc/rsh
chmod -f 0755 /etc/sh
chmod -f 0644 /etc/aliases
chown -f root:root /etc/aliases
chmod -f 0640 /etc/exports
chown -f root:root /etc/exports
chmod -f 0640 /etc/ftpusers
chown -f root:root /etc/ftpusers
chmod -f 0664 /etc/host.lpd
chmod -f 0440 /etc/inetd.conf
chown -f root:root /etc/inetd.conf
chmod -f 0644 /etc/mail/aliases
chown -f root:root /etc/mail/aliases
chmod -f 0644 /etc/passwd
chown -f root:root /etc/passwd
chmod -f 0400 /etc/shadow
chown -f root:root /etc/shadow
chmod -f 0600 /etc/uucp/L.cmds
chown -f uucp:uucp /etc/uucp/L.cmds
chmod -f 0600 /etc/uucp/L.sys
chown -f uucp:uucp /etc/uucp/L.sys
chmod -f 0600 /etc/uucp/Permissions
chown -f uucp:uucp /etc/uucp/Permissions
chmod -f 0600 /etc/uucp/remote.unknown
chown -f root:root /etc/uucp/remote.unknown
chmod -f 0600 /etc/uucp/remote.systems
chmod -f 0600 /etc/uccp/Systems
chown -f uucp:uucp /etc/uccp/Systems
chmod -f 0755 /sbin/csh
chmod -f 0755 /sbin/jsh
chmod -f 0755 /sbin/ksh
chmod -f 0755 /sbin/rsh
chmod -f 0755 /sbin/sh
chmod -f 0755 /usr/bin/csh
chmod -f 0755 /usr/bin/jsh
chmod -f 0755 /usr/bin/ksh
chmod -f 0755 /usr/bin/rsh
chmod -f 0755 /usr/bin/sh
chmod -f 1777 /var/mail
chmod -f 1777 /var/spool/uucppublic

# --- Set all files in ``.ssh`` to ``600``:
chmod 700 ~/.ssh && chmod 600 ~/.ssh/*

# --- Remove security related packages:
if [[ -f /bin/yay ]]; then
  for pkg in vsftpd telnet-server rdate tcpdump vnc-server tigervnc-server wireshark wireless-tools telnetd rdate vnc4server vino bind9-host libbind9-90; do
    yay -Rdd $pkg 2>/dev/null
  done
fi

# --- Account management and cleanup:
if [[ $(which userdel 2>/dev/null) != "" ]]; then
  for user in games news gopher tcpdump shutdown halt sync ftp operator lp uucp irc gnats pcap netdump; do
    userdel -f $user 2>/dev/null
  done
fi

# --- Disable fingerprint in PAM and authconfig:
if [[ $(which authconfig 2>/dev/null) != "" ]]; then
  authconfig --disablefingerprint --update
fi


# --- Start-up chkconfig levels set:
if [[ -f /sbin/chkconfig ]]; then
  /sbin/chkconfig --level 12345 auditd on 2>/dev/null
  /sbin/chkconfig isdn off 2>/dev/null
  /sbin/chkconfig bluetooth off 2>/dev/null
  /sbin/chkconfig haldaemon off 2>/dev/null #NEEDED ON FOR RHEL6 GUI
fi

# --- // Enable mount points nodev, noexec and nosuid by default: // -------- ||
/boot
sed -i "s/\( \/boot.*`grep " \/boot " /etc/fstab | awk '{print $4}'`\)/\1,nodev,n
oexec,nosuid/" /etc/fstab

/dev/shm
sed -i "s/\( \/dev\/shm.*`grep " \/dev\/shm " /etc/fstab | awk '{print $4}'`\)/\1
,nodev,noexec,nosuid/" /etc/fstab

/var
sed -i "s/\( \/var\/log.*`grep " \/var " /etc/fstab | awk '{print $4}'`\)/\1,node
v,noexec,nosuid/" /etc/fstab

/var/log
sed -i "s/\( \/var\/log.*`grep " \/var\/log " /etc/fstab | awk '{print $4}'`\)/\1
,nodev,noexec,nosuid/" /etc/fstab

/tmp
sed -i "s/\( \/tmp.*`grep " \/tmp " /etc/fstab | awk '{print $4}'`\)/\1,nodev,noe
xec,nosuid/" /etc/fstab

/home
sed -i "s/\( \/home.*`grep " \/home " /etc/fstab | awk '{print $4}'`\)/\1,nodev,n
osuid/" /etc/fstab

# --- Misc settings and permissions:
chmod -Rf o-w /usr/local/src/*
rm -f /etc/security/console.perms

# ---Remove .pacnew files:
nohup pacdiff > /dev/null 2>&1 &

# --- Set background image permissions:
if [[ -d /usr/share/backgrounds ]]; then
  chmod -f 0444 /usr/share/backgrounds/default*
  chmod -f 0444 /usr/share/backgrounds/images/default*
fi

if [[ $SELINUX = enforcing || $SELINUX = permissive ]]; then
  setenforce 1
fi

# --- Permit ssh login from root:
rootLogin='PermitRootLogin'
sshConfig='/etc/ssh/sshd_config'

if [[ -f ${sshConfig?} ]]; then
  if grep -q ${rootLogin?} ${sshConfig?}; then
    sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/g' ${sshConfig?}
  else
    echo -e '\tPermitRootLogin no' >> ${sshConfig?}
  fi
  systemctl restart sshd.service
fi

# --- Chmod 700 home dirs:
if [[ -d /home ]]; then
  for x in `find /home -maxdepth 1 -mindepth 1 -type d`; do chmod -f 0700 $x; done
fi

if [[ -d /export/home ]]; then
  for x in `find /export/home -maxdepth 1 -mindepth 1 -type d`; do chmod -f 0700 $x; done
fi

# --- Kernel parameters:
if [[ $(which sysctl 2>/dev/null) != "" ]]; then
  # --- Turn on ASLR Conservative Randomization:
  sysctl -w kernel.randomize_va_space=1
  # --- Hide Kernel Pointers:
  sysctl -w kernel.kptr_restrict=1
  # --- Allow reboot/poweroff, remount read-only, sync command:
  sysctl -w kernel.sysrq=176
  # --- Restrict PTRACE for debugging:
  sysctl -w kernel.yama.ptrace_scope=1
  # --- Hard and Soft Link Protection:
  sysctl -w fs.protected_hardlinks=1
  sysctl -w fs.protected_symlinks=1
  # --- Enable TCP SYN Cookie Protection:
  sysctl -w net.ipv4.tcp_syncookies=1
  # --- Disable IP Source Routing:
  sysctl -w net.ipv4.conf.all.accept_source_route=0
  # --- Disable ICMP Redirect Acceptance:
  sysctl -w net.ipv4.conf.all.accept_redirects=0
  sysctl -w net.ipv6.conf.all.accept_redirects=0
  sysctl -w net.ipv4.conf.all.send_redirects=0
  sysctl -w net.ipv6.conf.all.send_redirects=0
  # --- Enable IP Spoofing Protection:
  sysctl -w net.ipv4.conf.all.rp_filter=1
  sysctl -w net.ipv4.conf.default.rp_filter=1
  # --- Enable Ignoring to ICMP Requests:
  sysctl -w net.ipv4.icmp_echo_ignore_all=1
  # --- Enable Ignoring Broadcasts Request:
  sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
  # --- Enable Bad Error Message Protection:
  sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
  # --- Enable Logging of Spoofed Packets, Source Routed Packets, Redirect Packets:
  sysctl -w net.ipv4.conf.all.log_martians=1
  sysctl -w net.ipv4.conf.default.log_martians=1
  # --- Perfer Privacy Addresses:
  sysctl -w net.ipv6.conf.all.use_tempaddr = 2
  sysctl -w net.ipv6.conf.default.use_tempaddr = 2
  sysctl -p
fi

prominent "$SUCCESS SCAN COMPLETED..."

prominent "$EXPLOSION SYSTEM WAS QUICKLY SECURED $EXPLOSION"

exit 0
