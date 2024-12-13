# Dracut

In general, it is superior to mkinitcpio in it’s ability to autodetect needed modules and for most use cases will work without any further configuration.

**Regenerating the initrds**
You can regenerate the initrds with the command `sudo dracut-rebuild`

**Customizing dracut**
Dracut is configured via drop-in conf files in the `/etc/dracut.conf.d`

**Making the initramfs smaller**
For example, if you wanted to limit the size of your initrd, you could add a file named `smaller.conf` with the contents of:

```bash
hostonly_mode=strict
```

**Adding a dracut module**
Another common item might be to add a module manually. While most modules will be automatically configured, there may be times you want to add a module.

For example, if you wanted to forcibly add support for mdraid, you could use a file with the contents of:

```bash
add_dracutmodules+=" mdraid "
```

It is worth noting that this is not generally needed as dracut will automatically detect when mdraid support is needed.

**Removing a module**
If you want to ensure that a module doesn’t get added to the initramfs image, you can do so like this:

```bash
omit_dracutmodules+=" i18n "
```

This would remove i18n support from the initrd. This is another way to reduce the size if you don’t need support for internationalization.

**Early KMS loading**
If you need early KMS loading for nvidia that can be done with a this content:

```bash
force_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
```

For Intel:

```bash
force_drivers+=" i915 "
```

For modern AMD:

```bash
force_drivers+=" amdgpu "
```

**Making dracut less verbose**
Edit config file located at `/etc/dracut.conf.d/dracut.conf` and set DRACUT_QUIET to DRACUT_QUIET="true"

This will enable dracut’s quiet mode, which will suppress most output.

**Disable the generation of the fallback initrd**
Edit config file located at `/etc/dracut.conf.d/dracut.conf` and set NO_DRACUT_FALLBACK to NO_DRACUT_FALLBACK="true"

This will stop future fallback initrds from being generated.

Please note that this will not remove any existing fallback initrds that already exist. When using kernel-install-for-dracut (systemd-boot), this will change automatically as new kernel updates happen. For eos-dracut (grub), you will need to remove them manually.

**Update (rebuild) kernel boot images**
When using default systemd-boot and dracut:

```bash
sudo reinstall-kernels
```

When using Grub and dracut:

```bash
sudo dracut-rebuild
```

**Converting to dracut from mkinitcpio**
If you would like to convert an existing system to dracut, the process is very simple. You can use the following commands depending on if you are using systemd-boot or grub.

**systemd-boot with kernel-install**
If you use systemd-boot, this process is fairly simple

```bash
sudo pacman -S kernel-install-for-dracut
```

If you receive an error about the package `mkinitcpio-openswap`, uninstall it with `sudo pacman -R mkinitcpio-openswap` and run the command again.

If you have any LUKS encrypted file systems, you must create a dracut drop-in config for that. Create the file `/etc/dracut.conf.d/encryption.conf` with the following content:

```bash
install_items+=" /etc/crypttab "
```

If you have an encrypted swap partition, you must also add a line that looks like this to the encryption.conf file created above:

```bash
add_device+=" /dev/disk/by-uuid/ad44a367-09ec-4f74-bf66-f284438280db "
```

However, be sure to replace ad44a367-09ec-4f74-bf66-f284438280db with the UUID for your swap luks partition.

Last run `sudo reinstall-kernels` and reboot

**grub (or any other bootloader)**
For any other bootloader, this process should be followed.

```bash
sudo pacman -S dracut

sudo pacman -S eos-dracut

sudo pacman -Rc mkinitcpio
```

If you have any LUKS encrypted file systems you must create a dracut drop-in config for that. Create the file `/etc/dracut.conf.d/encryption.conf` with the following content:

```bash
install_items+=" /etc/crypttab /crypto_keyfile.bin "
```

If you have an encrypted swap partition, you must also add a line that looks like this to the encryption.conf file created above:

```bash
add_device+=" /dev/disk/by-uuid/ad44a367-09ec-4f74-bf66-f284438280db "
```

However, be sure to replace ad44a367-09ec-4f74-bf66-f284438280db with the UUID for your swap LUKS partition.

```bash
sudo dracut-rebuild
```
