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
# --- // ONLINE_ARCH_PKG_ARCHIVE:
https://archive.archlinux.org/packages/$(A-Z)

# --- // LDCONFIG_NOT_SYMLINK:
```bash
# Determine where `libexample.so.4` should link, typically `libexample.so.4.x.x`
ls -l /usr/lib/libcurl.so.*

# Create the Symbolic Link
sudo ln -sf /usr/lib/libexample.so.4.7.0 /usr/lib/libexample.so.4

# Update the Dynamic Linker Cache
sudo ldconfig
```

# --- // MAGIC_LITTLE_SNIPPETS:
# First, define an array such as duplicates: 

```bash
duplicates=(
    "dav1d" "db5.3" "dbus" "device-mapper" "dhclient" 
    "ding-libs" "wlogout"
)
```
# Now these little guys work with the array in two  
# batches, looping through the array.

```bash
# --- // Batch 1 removal of array: 

for pkg in "${duplicates[@]:0:20}"; do
    sudo pacman -Rns --noconfirm $pkg
done

# Reinstall the removed packages
for pkg in "${duplicates[@]:0:20}"; do
    sudo pacman -S --noconfirm $pkg
done
```

```bash
# --- // Batch 2 removal of array.
for pkg in "${duplicates[@]:20:40}"; do
    sudo pacman -Rns --noconfirm $pkg
done

# Reinstall the removed packages
for pkg in "${duplicates[@]:20:40}"; do
    sudo pacman -S --noconfirm $pkg
done
```
# Write the script once with 'Batch 1'
# and run it. Then once again with
# 'Batch 2' and voila! Duplicates in 
# the database resolved!
