#!/bin/bash

[ ! -f /usr/lib/bemenu/bemenu-renderer-curses.so ] && sudo pacman -S bemenu-ncurses
export BEMENU_BACKEND=curses

choice=""
active_langs=(en_US en_GB)
if [ -d /mnt/bin ]; then
    locale_gen_file="/mnt/etc/locale.gen"
else
    locale_gen_file="/etc/locale.gen"
fi

langs=$(fgrep .UTF-8 $locale_gen_file | fgrep -v "# " | sed -e 's/#//g;s/\.UTF-8//g' | awk '{print $1}' | grep -Ev "(en_US|en_GB)")
langs="Done ${langs}"

while [[ $choice != "Done" ]]; do
    choice=$(echo $langs | bemenu -i -p "Languages added: ${active_langs[*]}. Add new > ")
    if [ $choice != "Done" ]; then
        active_langs+=($choice)
        for l in ${active_langs[*]}; do
            to_del=($l)
            langs=("${langs[*]/$to_del}")
        done
    fi
done

for i in ${!active_langs[*]}; do
    sed -i "s/#${active_langs[$i]}\.UTF-8 UTF-8/${active_langs[$i]}\.UTF-8 UTF-8/g" $locale_gen_file
done

main_lang=""

while [ -z $main_lang ]; do
    main_lang=$(echo ${active_langs[*]} |bemenu -i -p "Choose your default language > ")
done

if [ -d /mnt/bin ]; then
    arch-chroot /mnt locale-gen
    arch-chroot /mnt echo "LANG=${main_lang}.UTF-8" > /etc/locale.conf
else
    locale-gen
    echo "LANG=${main_lang}.UTF-8" > /etc/locale.conf
fi


##Alternative small script to do the job
#!/bin/bash
#
#echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment
#echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
#echo "LANG=en_US.UTF-8" | sudo tee -a /etc/locale.conf
#sudo locale-gen en_US.UTF-8
