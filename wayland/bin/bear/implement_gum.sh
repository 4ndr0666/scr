#!/bin/bash
cat <<"EOF"
  ____       _   _                  _                 _ 
 / ___|     | | | |_   _ _ __  _ __| | __ _ _ __   __| |
| |  _ _____| |_| | | | | '_ \| '__| |/ _` | '_ \ / _` |
| |_| |_____|  _  | |_| | |_) | |  | | (_| | | | | (_| |
 \____|     |_| |_|\__, | .__/|_|  |_|\__,_|_| |_|\__,_|
                   |___/|_|                             
EOF
if [[ $1 = "enable" ]] 
then
echo
echo
echo "This script will implement G-Hyprland which is an optional feature"
echo "provided by garuda linux hyprland edition"
echo "Through this implementation users would be able to change some "
echo "visual stuffs like window gaps, waybar themes, wallpapers(animated,"
echo "slideshow,session static), etc..etc"
echo
read -rp "Do you want to implement it ? [y/n] " opt1
if [[ $opt1 == "y" || $opt1 == "Y" ]]
then
clear
    cat <<"EOF"
             _________  ________   ___   ___   ________  ___   __    _______      __  __   ______   __  __   ______                           
            /________/\/_______/\ /___/\/__/\ /_______/\/__/\ /__/\ /______/\    /_/\/_/\ /_____/\ /_/\/_/\ /_____/\                          
            \__.::.__\/\::: _  \ \\::.\ \\ \ \\__.::._\/\::\_\\  \ \\::::__\/__  \ \ \ \ \\:::_ \ \\:\ \:\ \\:::_ \ \                         
               \::\ \   \::(_)  \ \\:: \/_) \ \  \::\ \  \:. `-\  \ \\:\ /____/\  \:\_\ \ \\:\ \ \ \\:\ \:\ \\:(_) ) )_                       
                \::\ \   \:: __  \ \\:. __  ( (  _\::\ \__\:. _    \ \\:\\_  _\/   \::::_\/ \:\ \ \ \\:\ \:\ \\: __ `\ \                      
                 \::\ \   \:.\ \  \ \\: \ )  \ \/__\::\__/\\. \`-\  \ \\:\_\ \ \     \::\ \  \:\_\ \ \\:\_\:\ \\ \ `\ \ \                     
                  \__\/    \__\/\__\/ \__\/\__\/\________\/ \__\/ \__\/ \_____\/      \__\/   \_____\/ \_____\/ \_\/ \_\/                     
 ___   ___   __  __   ______   ______       _________  ______       ___   ___   __  __   ______   ______   ______        __    __    __       
/__/\ /__/\ /_/\/_/\ /_____/\ /_____/\     /________/\/_____/\     /__/\ /__/\ /_/\/_/\ /_____/\ /_____/\ /_____/\      /__/\ /__/\ /__/\     
\::\ \\  \ \\ \ \ \ \\:::_ \ \\::::_\/_    \__.::.__\/\:::_ \ \    \::\ \\  \ \\ \ \ \ \\:::_ \ \\::::_\/_\:::_ \ \     \.:\ \\.:\ \\.:\ \    
 \::\/_\ .\ \\:\_\ \ \\:(_) \ \\:\/___/\      \::\ \   \:\ \ \ \    \::\/_\ .\ \\:\_\ \ \\:(_) \ \\:\/___/\\:(_) ) )_    \::\ \\::\ \\::\ \   
  \:: ___::\ \\::::_\/ \: ___\/ \::___\/_      \::\ \   \:\ \ \ \    \:: ___::\ \\::::_\/ \: ___\/ \::___\/_\: __ `\ \    \__\/_\__\/_\__\/_  
   \: \ \\::\ \ \::\ \  \ \ \    \:\____/\      \::\ \   \:\_\ \ \    \: \ \\::\ \ \::\ \  \ \ \    \:\____/\\ \ `\ \ \     /__/\ /__/\ /__/\ 
    \__\/ \::\/  \__\/   \_\/     \_____\/       \__\/    \_____\/     \__\/ \::\/  \__\/   \_\/     \_____\/ \_\/ \_\/     \__\/ \__\/ \__\/ 
                                                                                                                                              
EOF
    echo "Thanks for giving a shot!!"
    if [[ ! -d "$HOME/.config/gum_implementation/" ]]
    then 
        mkdir "$HOME/.config/gum_implementation/"
    fi
    echo "Insatalling required packages.. " 
    sudo pacman -Sy gum wpaperd swww wlsunset nwg-dock-hyprland
    echo "backing up your old folders"
    mkdir "$HOME/.config/gum_implementation/backups/"
    cp -r "$HOME/.config/hypr/"* "$HOME/.config/gum_implementation/backups/"
    echo "copying files..."
    cp -r "/etc/skel/.config/gum_implementation/gum_files/"* "$HOME/.config/hypr/"

    echo "Adjusting monitor..."
    hyprctl monitors > /tmp/monitor
    var=$(sed -n '1{p;q}' /tmp/monitor | awk '{ print $2 }')
    var1=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $1 }')
    var2=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $3 }')
    var3=$(sed -n '10{p;q}' /tmp/monitor | awk '{ print $2 }')
    var4="$var, $var1, $var2, $var3"
    var5=${var1%%x*}
    sed -i "/monitor=/c\monitor= $var4" .config/hypr/settings/monitor.conf
    sed -i "/\"width\":/c\    \"width\":$var5," .config/waybar/config
    sed -i "s/USER/$USER/" .config/waybar/style.css
    sed -i "s|exec-once = .local/bin/mon.sh|#exec-once = .local/bin/mon.sh|" $HOME/.config/hypr/hyprland.conf
    sed -i "s|exec-once = garuda-welcome|#exec-once = garuda-welcome|" $HOME/.config/hypr/hyprland.conf

    echo "Setting keyboard layout"
    localectl > /tmp/garuda-locale.txt
    cat /tmp/garuda-locale.txt | grep Keymap > /tmp/keymap.txt
    cat /tmp/garuda-locale.txt | grep Layout > /tmp/layout.txt
    locale=$(cat /tmp/keymap.txt | awk '{ print $3 }')
    variant=$(cat /tmp/layout.txt | awk '{ print $3 }')
    sed -i "/kb_layout =/c\kb_layout = $layout" .config/hypr/settings/manual_settings.conf
    if [ "$variant" != "$layout" ]
    then
        sed -i "/kb_layout =/c\kb_layout = $variant" .config/hypr/settings/manual_settings.conf
    fi

    echo "All done, you can run the script through 'Mod+s' shortcut key"
    echo "you can go back to your older config whenever you like "
    echo "through same keybindings whenever you want ;-) "
    read -rp "please restart you PC" opt2
else 
    echo "User selected not to implement"
    sleep 3
fi
elif [[ $1 = "disable" ]] 
then
    echo "Are you sure you want to leave G-Hyprland script ?"
    echo "If you did any changes to your G-Hyprland scripts"
    echo "then it won't be backed up !!"
    read -rp "Remove G-Hyprland implementation ? [y/n] : " opt3 
    if [[ $opt3 == "y" || $opt3 == "Y" ]]
    then
    echo "backing up..."
    cp -r "$HOME/.config/gum_implementation/backups/"*  "$HOME/.config/hypr/"
    echo "cleaning up" 
    rm -r "$HOME/.config/hypr/brain/" "$HOME/.config/hypr/settings" "$HOME/.config/gum_implementation/backups/"
    read -rp "All done, please restart your machine "
    else 
        echo "user selected not to backup "
        sleep 3
    fi
fi
