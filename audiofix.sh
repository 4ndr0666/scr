#!/bin/bash

# Step 1: Kill processes using the audio device
echo "Killing processes using the audio device..."
sudo fuser -k /dev/snd/*

# Step 2: Reload ALSA Modules
echo "Reloading ALSA modules..."
sudo modprobe -r snd_hda_intel && sudo modprobe snd_hda_intel
if [ $? -eq 0 ]; then
    echo "ALSA modules reloaded successfully."
else
    echo "Failed to reload ALSA modules. Module in use."
fi

# Step 3: Restart PulseAudio
echo "Restarting PulseAudio..."
pulseaudio -k && pulseaudio --start

# Step 4: Test Audio
echo "Testing audio..."
speaker-test -c 2 -l 1
read -p "Did you hear the sound? (y/n): " sound_works
if [ "$sound_works" == "y" ]; then
    echo "Sound is working. Exiting..."
    exit 0
fi

# Step 5: Check alsamixer settings (Manual Step)
echo "Please check your alsamixer settings to make sure audio is not muted."
echo "Press F6 to select your sound card and make sure channels are not muted."
read -p "Press enter to continue..."

# Step 6: Blacklist unnecessary modules
echo "Blacklisting unnecessary modules..."
echo "blacklist snd_hda_codec_realtek" | sudo tee -a /etc/modprobe.d/blacklist.conf

# Step 7: Update initial ramdisk
echo "Updating initial ramdisk..."
sudo mkinitcpio -P

# Step 8: Reboot system (Manual Step)
echo "Please reboot your system to apply changes."
echo "After rebooting, run 'speaker-test -c 2' to test the sound."
read -p "Press enter to finish..."

# End of script
