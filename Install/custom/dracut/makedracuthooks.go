package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	hookDir           = "/etc/pacman.d/hooks"
	scriptDir         = "/usr/local/bin"
	hookFileRemoval   = "60-mkinitcpio-removal.hook"
	hookFileInstall   = "90-mkinitcpio-install.hook"
	scriptRegenerate  = "dracut-regenerate.sh"
	scriptCleanup     = "dracut-cleanup.sh"
)

// errorExit logs the error message and exits the program
func errorExit(msg string) {
	log.Fatalf("Error: %s\n", msg)
}

// autoEscalate checks for root access and reruns the script with sudo if needed
func autoEscalate() {
	if os.Geteuid() != 0 {
		cmd := exec.Command("sudo", os.Args[0])
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			errorExit("Failed to rerun script with sudo")
		}
		os.Exit(0)
	}
}

func ensureDirectories() {
	// Create necessary directories
	fmt.Println("Ensuring necessary directories exist...")
	if err := os.MkdirAll(hookDir, 0755); err != nil {
		errorExit("Failed to create hook directory")
	}
	if err := os.MkdirAll(scriptDir, 0755); err != nil {
		errorExit("Failed to create script directory")
	}
}

func createHookFiles() {
	fmt.Println("Creating hook files...")

	removalHookContent := `
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Regenerating initramfs with dracut...
When = PostTransaction
Exec = /usr/local/bin/dracut-regenerate.sh
Depends = dracut
NeedsTargets
`
	installHookContent := `
[Trigger]
Type = Path
Operation = Remove
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Cleaning up old initramfs images...
When = PreTransaction
Exec = /usr/local/bin/dracut-cleanup.sh
NeedsTargets
`

	// Create removal hook file
	err := os.WriteFile(filepath.Join(hookDir, hookFileRemoval), []byte(removalHookContent), 0644)
	if err != nil {
		errorExit("Failed to create " + hookFileRemoval)
	}

	// Create install hook file
	err = os.WriteFile(filepath.Join(hookDir, hookFileInstall), []byte(installHookContent), 0644)
	if err != nil {
		errorExit("Failed to create " + hookFileInstall)
	}
}

func createDracutScripts() {
	fmt.Println("Creating dracut scripts...")

	regenerateScript := `
#!/bin/bash
rm -f /boot/initramfs-*.img || { echo "Failed to remove old initramfs images"; exit 1; }
dracut --force --regenerate-all || { echo "Dracut failed to regenerate initramfs"; exit 1; }

current_kernel=$(uname -r)
ln -sf /boot/initramfs-${current_kernel}.img /boot/initramfs-linux.img || { echo "Failed to create initramfs symlink"; exit 1; }
ln -sf /boot/vmlinuz-${current_kernel} /boot/vmlinuz-linux || { echo "Failed to create vmlinuz symlink"; exit 1; }

grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to update GRUB configuration"; exit 1; }
grub-set-default 0 || { echo "Failed to set GRUB default entry"; exit 1; }

echo "Initramfs regenerated and GRUB updated."
`

	cleanupScript := `
#!/bin/bash
installed_kernels=$(ls /usr/lib/modules) || { echo "Failed to list installed kernels"; exit 1; }

for img in /boot/initramfs-*.img; do
    kernel_version=$(basename "$img" | sed 's/initramfs-//;s/.img//')
    if ! [[ $installed_kernels =~ $kernel_version ]]; then
        rm -f "$img" || { echo "Failed to remove old initramfs image $img"; exit 1; }
    fi
done

for img in /boot/efi/initramfs-*.img; do
    kernel_version=$(basename "$img" | sed 's/initramfs-//;s/.img//')
    if ! [[ $installed_kernels =~ $kernel_version ]]; then
        rm -f "$img" || { echo "Failed to remove old EFI initramfs image $img"; exit 1; }
    fi
done
echo "Old initramfs images cleaned up."
`

	// Create the dracut-regenerate.sh script
	err := os.WriteFile(filepath.Join(scriptDir, scriptRegenerate), []byte(regenerateScript), 0755)
	if err != nil {
		errorExit("Failed to create " + scriptRegenerate)
	}

	// Create the dracut-cleanup.sh script
	err = os.WriteFile(filepath.Join(scriptDir, scriptCleanup), []byte(cleanupScript), 0755)
	if err != nil {
		errorExit("Failed to create " + scriptCleanup)
	}
}

func disableMkinitcpioHooks() {
	fmt.Println("Disabling default mkinitcpio hooks...")
	os.Symlink("/dev/null", filepath.Join(hookDir, "90-mkinitcpio-install.hook"))
	os.Symlink("/dev/null", filepath.Join(hookDir, "60-mkinitcpio-remove.hook"))
}

func main() {
	// Ensure the script runs with root privileges
	autoEscalate()

	fmt.Println("💀WARNING💀 - you are now operating as root...")

	// Perform the tasks
	ensureDirectories()
	createHookFiles()
	createDracutScripts()
	disableMkinitcpioHooks()

	fmt.Println("Installation complete. Dracut is now configured to manage initramfs images automatically.")
}
