# --- // CREATE_PKGLIST_HOOK: 

```bash
[Trigger]
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
When = PostTransaction
Exec = /bin/sh -c '/usr/bin/pacman -Qqe > /etc/pkglist.txt'
```

# --- // REINSTALL_ALL_PKGS:

```bash
pacman -Qqn | pacman -S -
```

# --- // REINSTALL_BASE_PKG:

```bash
pacstrap -K /mnt base linux linux-firmware
```

# --- // SWITCH_ROOT_USER:
```bash 
su -
```


