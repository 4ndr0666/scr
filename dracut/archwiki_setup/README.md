# Archwiki Dracut Setup

As the command to figure out the kernel version is somewhat complex, it will not work by itself in a pacman hook. So create a script anywhere on your system. For this example it will be created in /usr/local/bin/. The script will also copy the new vmlinuz kernel file to /boot/, since the kernel packages do not place files in /boot/ anymore. Place this in `/usr/local/bin/dracut-install.sh`:

**File**: dracut-install.sh

```bash
#!/usr/bin/env bash

args=('--force' '--no-hostonly-cmdline')

while read -r line; do
	if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
		read -r pkgbase < "/${line}"
		kver="${line#'usr/lib/modules/'}"
		kver="${kver%'/pkgbase'}"

		install -Dm0644 "/${line%'/pkgbase'}/vmlinuz" "/boot/vmlinuz-${pkgbase}"
		dracut "${args[@]}" --hostonly "/boot/initramfs-${pkgbase}.img" --kver "$kver"
		dracut "${args[@]}" --add-confdir rescue  "/boot/initramfs-${pkgbase}-fallback.img" --kver "$kver"
	fi
done
```

Place this script here: `/usr/local/bin/dracut-remove.sh`

**File**: dracut-remove.sh

```bash
#!/usr/bin/env bash

while read -r line; do
	if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
		read -r pkgbase < "/${line}"
		rm -f "/boot/vmlinuz-${pkgbase}" "/boot/initramfs-${pkgbase}.img" "/boot/initramfs-${pkgbase}-fallback.img"
	fi
done
```

---

## The next step is creating pacman hooks:

Place this script here `/etc/pacman.d/hooks/90-dracut-install.hook`:

**File**: 90-dracut-install.hook

```bash
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Updating linux initcpios (with dracut!)...
When = PostTransaction
Exec = /usr/local/bin/dracut-install.sh
Depends = dracut
NeedsTargets
```

Place this script here: `/etc/pacman.d/hooks/60-dracut-remove.hook`:

**File**: 60-dracut-remove.hook

```bash
[Trigger]
Type = Path
Operation = Remove
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Removing linux initcpios...
When = PreTransaction
Exec = /usr/local/bin/dracut-remove.sh
NeedsTargets
```

* *You should stop mkinitcpio from creating and removing initramfs images as well, either by removing mkinitcpio or with the following commands*:

```bash
ln -sf /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook
ln -sf /dev/null /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
```
