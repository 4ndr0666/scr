# CODEX.md

Mitigate all of the following conflicts identified by shellcheck:

```shell
In install/wayfire/scripts/brightness line 11:
	LIGHT=$(printf "%.0f\n" `light -G`)
                                ^--------^ SC2046 (warning): Quote this to prevent word splitting.
                                ^--------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	LIGHT=$(printf "%.0f\n" $(light -G))


In install/wayfire/scripts/wofi_powermenu line 39:
		$shutdown)
                ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_powermenu line 41:
			if [[ "$?" == 0 ]]; then
                              ^--^ SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?.


In install/wayfire/scripts/wofi_powermenu line 47:
		$reboot)
                ^-----^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_powermenu line 49:
			if [[ "$?" == 0 ]]; then
                              ^--^ SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?.


In install/wayfire/scripts/wofi_powermenu line 55:
		$lock)
                ^---^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_powermenu line 58:
		$suspend)
                ^------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_powermenu line 60:
			if [[ "$?" == 0 ]]; then
                              ^--^ SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?.


In install/wayfire/scripts/wofi_powermenu line 69:
		$logout)
                ^-----^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_powermenu line 71:
			if [[ "$?" == 0 ]]; then
                              ^--^ SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?.


In install/wayfire/scripts/wofi_powermenu line 80:
if [[ ! `pidof wofi` ]]; then
        ^----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ ! $(pidof wofi) ]]; then


In install/wayfire/scripts/colorpicker line 7:
color=$(grim -g "`slurp -b 00000000 -p`" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:- | tail -n1 | cut -d' ' -f4)
                 ^--------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
color=$(grim -g "$(slurp -b 00000000 -p)" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:- | tail -n1 | cut -d' ' -f4)


In install/wayfire/scripts/colorpicker line 13:
		echo $color | tr -d "\n" | wl-copy
                     ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		echo "$color" | tr -d "\n" | wl-copy


In install/wayfire/scripts/colorpicker line 15:
		convert -size 48x48 xc:"$color" ${image}
                                                ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		convert -size 48x48 xc:"$color" "${image}"


In install/wayfire/scripts/colorpicker line 17:
		notify-send -h string:x-canonical-private-synchronous:sys-notify-picker -u low -i ${image} "$color, copied to clipboard."
                                                                                                  ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		notify-send -h string:x-canonical-private-synchronous:sys-notify-picker -u low -i "${image}" "$color, copied to clipboard."


In install/wayfire/scripts/toggle_waybar.sh line 12:
	 if [ -e "$1" ]; then
         ^-- SC2317 (info): Command appears to be unreachable. Check usage (or ignore if invoked indirectly).
            ^---------^ SC2317 (info): Command appears to be unreachable. Check usage (or ignore if invoked indirectly).


In install/wayfire/scripts/toggle_waybar.sh line 13:
	     return 0
             ^------^ SC2317 (info): Command appears to be unreachable. Check usage (or ignore if invoked indirectly).


In install/wayfire/scripts/toggle_waybar.sh line 15:
	     return 1
             ^------^ SC2317 (info): Command appears to be unreachable. Check usage (or ignore if invoked indirectly).


In install/wayfire/scripts/toggle_waybar.sh line 34:
waybar --bar main-bar --config ${CONFIG} --style ${STYLE} &
                               ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                 ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
waybar --bar main-bar --config "${CONFIG}" --style "${STYLE}" &


In install/wayfire/scripts/rofi_bluetooth line 198:
        mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | grep Device | cut -d ' ' -f 2)
                                                   ^-----------------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
        mapfile -t paired_devices < <(bluetoothctl "$paired_devices_cmd" | grep Device | cut -d ' ' -f 2)


In install/wayfire/scripts/notifications line 9:
if [[ ! `pidof mako` ]]; then
        ^----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ ! $(pidof mako) ]]; then


In install/wayfire/scripts/notifications line 10:
	mako --config ${CONFIG}
                      ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	mako --config "${CONFIG}"


In install/wayfire/scripts/rofi_asroot line 15:
layout=$(cat ${RASI} | grep 'USE_ICON' | cut -d'=' -f2)
             ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
layout=$(cat "${RASI}" | grep 'USE_ICON' | cut -d'=' -f2)


In install/wayfire/scripts/rofi_asroot line 36:
		-theme ${RASI}
                       ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		-theme "${RASI}"


In install/wayfire/scripts/rofi_asroot line 62:
$option_1)
^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_asroot line 65:
$option_2)
^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_asroot line 68:
$option_3)
^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_asroot line 71:
$option_4)
^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_asroot line 74:
$option_5)
^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/wofi_menu line 10:
if [[ ! `pidof wofi` ]]; then
        ^----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ ! $(pidof wofi) ]]; then


In install/wayfire/scripts/wofi_menu line 11:
	wofi --show drun --prompt 'Search Applications' --conf ${CONFIG} --style ${STYLE}
                                                               ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                                                 ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	wofi --show drun --prompt 'Search Applications' --conf "${CONFIG}" --style "${STYLE}"


In install/wayfire/scripts/asroot line 10:
sudo -E -A $1
           ^-- SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
sudo -E -A "$1"

For more information:
  https://www.shellcheck.net/wiki/SC2046 -- Quote this to prevent word splitt...
  https://www.shellcheck.net/wiki/SC2254 -- Quote expansions in case patterns...
  https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...

In install/waybar/crimsom_black/scripts/date line 6:
pointX=$(echo $((($W-$ww)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/waybar/crimsom_black/scripts/date line 7:
pointY=$(echo $((($H-$wh)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/wayfire/scripts/volume line 12:
	echo "`pulsemixer --get-volume | cut -d' ' -f1`"
             ^-- SC2005 (style): Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.
              ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	echo "$(pulsemixer --get-volume | cut -d' ' -f1)"


In install/wayfire/scripts/volume line 36:
	[[ `pulsemixer --get-mute` == 1 ]] && pulsemixer --unmute
           ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	[[ $(pulsemixer --get-mute) == 1 ]] && pulsemixer --unmute


In install/wayfire/scripts/volume line 42:
	[[ `pulsemixer --get-mute` == 1 ]] && pulsemixer --unmute
           ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	[[ $(pulsemixer --get-mute) == 1 ]] && pulsemixer --unmute


In install/wayfire/scripts/volume line 48:
	if [[ `pulsemixer --get-mute` == 0 ]]; then
              ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	if [[ $(pulsemixer --get-mute) == 0 ]]; then


In install/wayfire/scripts/volume line 57:
	ID="`pulsemixer --list-sources | grep 'Default' | cut -d',' -f1 | cut -d' ' -f3`"
            ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	ID="$(pulsemixer --list-sources | grep 'Default' | cut -d',' -f1 | cut -d' ' -f3)"


In install/wayfire/scripts/volume line 58:
	if [[ `pulsemixer --id $ID --get-mute` == 0 ]]; then
              ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                               ^-^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	if [[ $(pulsemixer --id "$ID" --get-mute) == 0 ]]; then


In install/wayfire/scripts/volume line 59:
		pulsemixer --id ${ID} --toggle-mute && ${notify_cmd} -i "$iDIR/microphone-mute.png" "Microphone Switched OFF"
                                ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		pulsemixer --id "${ID}" --toggle-mute && ${notify_cmd} -i "$iDIR/microphone-mute.png" "Microphone Switched OFF"


In install/wayfire/scripts/volume line 61:
		pulsemixer --id ${ID} --toggle-mute && ${notify_cmd} -i "$iDIR/microphone.png" "Microphone Switched ON"
                                ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		pulsemixer --id "${ID}" --toggle-mute && ${notify_cmd} -i "$iDIR/microphone.png" "Microphone Switched ON"


In install/wayfire/scripts/volume line 66:
if [[ -x `which pulsemixer` ]]; then
         ^----------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ -x $(which pulsemixer) ]]; then


In install/wayfire/scripts/volume line 78:
		echo $(get_volume)%
                     ^-----------^ SC2046 (warning): Quote this to prevent word splitting.


In install/wayfire/scripts/rofi_screenshot line 7:
background="`cat $DIR/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;`"
            ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                 ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
background="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/rofi_screenshot line 8:
accent="`cat $DIR/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;`"
        ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
             ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
accent="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/rofi_screenshot line 16:
mesg="Directory :: `xdg-user-dir PICTURES`/Screenshots"
                   ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
mesg="Directory :: $(xdg-user-dir PICTURES)/Screenshots"


In install/wayfire/scripts/rofi_screenshot line 19:
layout=`cat ${RASI} | grep 'USE_ICON' | cut -d'=' -f2`
       ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
            ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
layout=$(cat "${RASI}" | grep 'USE_ICON' | cut -d'=' -f2)


In install/wayfire/scripts/rofi_screenshot line 40:
		-theme ${RASI}
                       ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		-theme "${RASI}"


In install/wayfire/scripts/rofi_screenshot line 49:
time=`date +%Y-%m-%d-%H-%M-%S`
     ^-----------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
time=$(date +%Y-%m-%d-%H-%M-%S)


In install/wayfire/scripts/rofi_screenshot line 50:
geometry=`swaymsg -pt get_outputs | grep 'Current mode:' | cut -d':' -f2 | cut -d'@' -f1 | tr -d ' '`
         ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
geometry=$(swaymsg -pt get_outputs | grep 'Current mode:' | cut -d':' -f2 | cut -d'@' -f1 | tr -d ' ')


In install/wayfire/scripts/rofi_screenshot line 51:
dir="`xdg-user-dir PICTURES`/Screenshots"
     ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
dir="$(xdg-user-dir PICTURES)/Screenshots"


In install/wayfire/scripts/rofi_screenshot line 65:
	viewnior ${dir}/"$file"
                 ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	viewnior "${dir}"/"$file"


In install/wayfire/scripts/rofi_screenshot line 75:
	for sec in `seq $1 -1 1`; do
                   ^-----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                        ^-- SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	for sec in $(seq "$1" -1 1); do


In install/wayfire/scripts/rofi_screenshot line 83:
	cd ${dir} && sleep 0.5 && grim - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && sleep 0.5 && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/rofi_screenshot line 89:
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
                      ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	sleep 1 && cd "${dir}" && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/rofi_screenshot line 95:
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
                      ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	sleep 1 && cd "${dir}" && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/rofi_screenshot line 100:
	cd ${dir} && grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | tee "$file" | wl-copy


In install/wayfire/scripts/rofi_screenshot line 105:
	cd ${dir} && grim -g "$(slurp -b ${background:1}CC -c ${accent:1}ff -s ${accent:1}0D -w 2 && sleep 0.3)" - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                         ^-------------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                              ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                                               ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && grim -g "$(slurp -b "${background:1}"CC -c "${accent:1}"ff -s "${accent:1}"0D -w 2 && sleep 0.3)" - | tee "$file" | wl-copy


In install/wayfire/scripts/rofi_screenshot line 127:
    $option_1)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_screenshot line 130:
    $option_2)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_screenshot line 133:
    $option_3)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_screenshot line 136:
    $option_4)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_screenshot line 139:
    $option_5)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/statusbar line 6:
if [[ ! `pidof waybar` ]]; then
        ^------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ ! $(pidof waybar) ]]; then


In install/wayfire/scripts/statusbar line 7:
	waybar --bar main-bar --log-level error --config ${CONFIG} --style ${STYLE}
                                                         ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                                           ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	waybar --bar main-bar --log-level error --config "${CONFIG}" --style "${STYLE}"


In install/wayfire/scripts/kitty line 20:
	kitty --config "$CONFIG" ${@}
                                 ^--^ SC2068 (error): Double quote array expansions to avoid re-splitting elements.


In install/wayfire/scripts/screenshot line 9:
background="`cat $DIR/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;`"
            ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                 ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
background="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/screenshot line 10:
accent="`cat $DIR/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;`"
        ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
             ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
accent="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/screenshot line 14:
time=`date +%Y-%m-%d-%H-%M-%S`
     ^-----------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
time=$(date +%Y-%m-%d-%H-%M-%S)


In install/wayfire/scripts/screenshot line 16:
dir="`xdg-user-dir PICTURES`/Screenshots"
     ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
dir="$(xdg-user-dir PICTURES)/Screenshots"


In install/wayfire/scripts/screenshot line 24:
	viewnior ${dir}/"$file"
                 ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	viewnior "${dir}"/"$file"


In install/wayfire/scripts/screenshot line 34:
	for sec in `seq $1 -1 1`; do
                   ^-----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                        ^-- SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	for sec in $(seq "$1" -1 1); do


In install/wayfire/scripts/screenshot line 42:
	cd ${dir} && sleep 0.5 && grim - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && sleep 0.5 && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/screenshot line 48:
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
                      ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	sleep 1 && cd "${dir}" && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/screenshot line 54:
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
                      ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	sleep 1 && cd "${dir}" && grim - | tee "$file" | wl-copy


In install/wayfire/scripts/screenshot line 59:
	cd ${dir} && grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | tee "$file" | wl-copy


In install/wayfire/scripts/screenshot line 64:
	cd ${dir} && grim -g "$(slurp -b ${background:1}CC -c ${accent:1}ff -s ${accent:1}0D -w 2 && sleep 0.3)" - | tee "$file" | wl-copy
           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                         ^-------------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                              ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                                               ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	cd "${dir}" && grim -g "$(slurp -b "${background:1}"CC -c "${accent:1}"ff -s "${accent:1}"0D -w 2 && sleep 0.3)" - | tee "$file" | wl-copy

For more information:
  https://www.shellcheck.net/wiki/SC2068 -- Double quote array expansions to ...
  https://www.shellcheck.net/wiki/SC2046 -- Quote this to prevent word splitt...
  https://www.shellcheck.net/wiki/SC2254 -- Quote expansions in case patterns...

In install/waybar/cyanohydrin/scripts/date line 6:
pointX=$(echo $((($W-$ww)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/waybar/cyanohydrin/scripts/date line 7:
pointY=$(echo $((($H-$wh)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/waybar/blue_sapphire/scripts/date line 6:
pointX=$(echo $((($W-$ww)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/waybar/blue_sapphire/scripts/date line 7:
pointY=$(echo $((($H-$wh)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/wayfire/scripts/alacritty line 21:
	alacritty --config-file "$CONFIG" ${@}
                                          ^--^ SC2068 (error): Double quote array expansions to avoid re-splitting elements.


In install/waybar/default/scripts/date line 6:
pointX=$(echo $((($W-$ww)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/waybar/default/scripts/date line 7:
pointY=$(echo $((($H-$wh)/2)))
       ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                  ^-- SC2004 (style): $/${} is unnecessary on arithmetic variables.
                     ^-^ SC2004 (style): $/${} is unnecessary on arithmetic variables.


In install/wayfire/scripts/wlogout line 10:
if [[ ! `pidof wlogout` ]]; then
        ^-------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
if [[ ! $(pidof wlogout) ]]; then


In install/wayfire/scripts/wlogout line 11:
	wlogout --layout ${LAYOUT} --css ${STYLE} \
                         ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                         ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	wlogout --layout "${LAYOUT}" --css "${STYLE}" \


In install/wayfire/scripts/rofi_runner line 12:
	-theme ${RASI}
               ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	-theme "${RASI}"

For more information:
  https://www.shellcheck.net/wiki/SC2068 -- Double quote array expansions to ...
  https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...
  https://www.shellcheck.net/wiki/SC2004 -- $/${} is unnecessary on arithmeti...

In install/wayfire/scripts/rofi_music line 10:
status="`mpc status`"
        ^----------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
status="$(mpc status)"


In install/wayfire/scripts/rofi_music line 15:
	prompt="`mpc -f "%artist%" current`"
                ^-------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	prompt="$(mpc -f "%artist%" current)"


In install/wayfire/scripts/rofi_music line 16:
	mesg="`mpc -f "%title%" current` :: `mpc status | grep "#" | awk '{print $3}'`"
              ^------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                                            ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
	mesg="$(mpc -f "%title%" current) :: $(mpc status | grep "#" | awk '{print $3}')"


In install/wayfire/scripts/rofi_music line 20:
layout=`cat ${RASI} | grep 'USE_ICON' | cut -d'=' -f2`
       ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
            ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
layout=$(cat "${RASI}" | grep 'USE_ICON' | cut -d'=' -f2)


In install/wayfire/scripts/rofi_music line 70:
		${active} ${urgent} \
                ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                          ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		"${active}" "${urgent}" \


In install/wayfire/scripts/rofi_music line 72:
		-theme ${RASI}
                       ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		-theme "${RASI}"


In install/wayfire/scripts/rofi_music line 85:
		mpc -q toggle && ${notify_song} "`mpc -f "%artist%" current`"
                                                 ^-------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
		mpc -q toggle && ${notify_song} "$(mpc -f "%artist%" current)"


In install/wayfire/scripts/rofi_music line 89:
		mpc -q prev && ${notify_song} "`mpc -f "%artist%" current`"
                                               ^-------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
		mpc -q prev && ${notify_song} "$(mpc -f "%artist%" current)"


In install/wayfire/scripts/rofi_music line 91:
		mpc -q next && ${notify_song} "`mpc -f "%artist%" current`"
                                               ^-------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
		mpc -q next && ${notify_song} "$(mpc -f "%artist%" current)"


In install/wayfire/scripts/rofi_music line 102:
    $option_1)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_music line 105:
    $option_2)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_music line 108:
    $option_3)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_music line 111:
    $option_4)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_music line 114:
    $option_5)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_music line 117:
    $option_6)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/lockscreen line 7:
source "$DIR"/theme/current.bash
       ^-----------------------^ SC1091 (info): Not following: ./theme/current.bash: openBinaryFile: does not exist (No such file or directory)


In install/wayfire/scripts/lockscreen line 10:
bg=${background:1}  fg=${foreground:1}
   ^-------------^ SC2154 (warning): background is referenced but not assigned.
                       ^-------------^ SC2154 (warning): foreground is referenced but not assigned.


In install/wayfire/scripts/lockscreen line 11:
red=${color1:1}     green=${color2:1}    yellow=${color3:1}
    ^---------^ SC2154 (warning): color1 is referenced but not assigned.
                          ^---------^ SC2154 (warning): color2 is referenced but not assigned.
                                         ^----^ SC2034 (warning): yellow appears unused. Verify use (or export if used externally).
                                                ^---------^ SC2154 (warning): color3 is referenced but not assigned.


In install/wayfire/scripts/lockscreen line 12:
blue=${color4:1}    magenta=${color5:1}  cyan=${color6:1}
     ^---------^ SC2154 (warning): color4 is referenced but not assigned.
                            ^---------^ SC2154 (warning): color5 is referenced but not assigned.
                                              ^---------^ SC2154 (warning): color6 is referenced but not assigned.


In install/wayfire/scripts/lockscreen line 25:
	--color ${bg}E6 \
                ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--color "${bg}"E6 \


In install/wayfire/scripts/lockscreen line 29:
	--key-hl-color ${green} \
                       ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--key-hl-color "${green}" \


In install/wayfire/scripts/lockscreen line 30:
	--caps-lock-key-hl-color ${blue} \
                                 ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--caps-lock-key-hl-color "${blue}" \


In install/wayfire/scripts/lockscreen line 31:
	--bs-hl-color ${red} \
                      ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--bs-hl-color "${red}" \


In install/wayfire/scripts/lockscreen line 32:
	--caps-lock-bs-hl-color ${red} \
                                ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--caps-lock-bs-hl-color "${red}" \


In install/wayfire/scripts/lockscreen line 42:
	--inside-ver-color ${blue} \
                           ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--inside-ver-color "${blue}" \


In install/wayfire/scripts/lockscreen line 43:
	--inside-wrong-color ${red} \
                             ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--inside-wrong-color "${red}" \


In install/wayfire/scripts/lockscreen line 46:
	--layout-bg-color ${cyan} \
                          ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--layout-bg-color "${cyan}" \


In install/wayfire/scripts/lockscreen line 47:
	--layout-border-color ${cyan} \
                              ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--layout-border-color "${cyan}" \


In install/wayfire/scripts/lockscreen line 48:
	--layout-text-color ${bg} \
                            ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--layout-text-color "${bg}" \


In install/wayfire/scripts/lockscreen line 51:
	--line-color ${bg} \
                     ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--line-color "${bg}" \


In install/wayfire/scripts/lockscreen line 52:
	--line-clear-color ${red} \
                           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--line-clear-color "${red}" \


In install/wayfire/scripts/lockscreen line 53:
	--line-caps-lock-color ${bg} \
                               ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--line-caps-lock-color "${bg}" \


In install/wayfire/scripts/lockscreen line 54:
	--line-ver-color ${bg} \
                         ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--line-ver-color "${bg}" \


In install/wayfire/scripts/lockscreen line 55:
	--line-wrong-color ${bg} \
                           ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--line-wrong-color "${bg}" \


In install/wayfire/scripts/lockscreen line 58:
	--ring-color ${cyan} \
                     ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--ring-color "${cyan}" \


In install/wayfire/scripts/lockscreen line 59:
	--ring-clear-color ${bg} \
                           ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--ring-clear-color "${bg}" \


In install/wayfire/scripts/lockscreen line 60:
	--ring-caps-lock-color ${magenta} \
                               ^--------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--ring-caps-lock-color "${magenta}" \


In install/wayfire/scripts/lockscreen line 61:
	--ring-ver-color ${blue} \
                         ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--ring-ver-color "${blue}" \


In install/wayfire/scripts/lockscreen line 62:
	--ring-wrong-color ${red} \
                           ^----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--ring-wrong-color "${red}" \


In install/wayfire/scripts/lockscreen line 65:
	--separator-color ${bg} \
                          ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--separator-color "${bg}" \


In install/wayfire/scripts/lockscreen line 68:
	--text-color ${fg} \
                     ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--text-color "${fg}" \


In install/wayfire/scripts/lockscreen line 69:
	--text-clear-color ${fg} \
                           ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--text-clear-color "${fg}" \


In install/wayfire/scripts/lockscreen line 70:
	--text-caps-lock-color ${fg} \
                               ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--text-caps-lock-color "${fg}" \


In install/wayfire/scripts/lockscreen line 71:
	--text-ver-color ${bg} \
                         ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--text-ver-color "${bg}" \


In install/wayfire/scripts/lockscreen line 72:
	--text-wrong-color ${bg}
                           ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--text-wrong-color "${bg}"


In install/wayfire/scripts/foot line 9:
background="`cat $DIR/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;`"
            ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                 ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
background="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'background:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/foot line 10:
accent="`cat $DIR/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;`"
        ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
             ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
accent="$(cat "$DIR"/rofi/shared/colors.rasi | grep 'selected:' | cut -d':' -f2 | tr -d ' '\;)"


In install/wayfire/scripts/foot line 20:
	--window-size-pixels=$(slurp -b ${background:1}CC -c ${accent:1}ff -s ${accent:1}0D -w 2 -f "%wx%h")
                             ^-- SC2046 (warning): Quote this to prevent word splitting.
                                        ^-------------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                             ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.
                                                                              ^---------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	--window-size-pixels=$(slurp -b "${background:1}"CC -c "${accent:1}"ff -s "${accent:1}"0D -w 2 -f "%wx%h")


In install/wayfire/scripts/foot line 22:
	foot --config="$CONFIG" ${@}
                                ^--^ SC2068 (error): Double quote array expansions to avoid re-splitting elements.


In install/wayfire/scripts/rofi_powermenu line 11:
prompt="`hostname` (`echo $DESKTOP_SESSION`)"
        ^--------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                    ^---------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
                    ^---------------------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
                          ^--------------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
prompt="$(hostname) ($(echo "$DESKTOP_SESSION"))"


In install/wayfire/scripts/rofi_powermenu line 12:
mesg="Uptime : `uptime -p | sed -e 's/up //g'`"
               ^-----------------------------^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
mesg="Uptime : $(uptime -p | sed -e 's/up //g')"


In install/wayfire/scripts/rofi_powermenu line 15:
layout=`cat ${RASI} | grep 'USE_ICON' | cut -d'=' -f2`
       ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
            ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
layout=$(cat "${RASI}" | grep 'USE_ICON' | cut -d'=' -f2)


In install/wayfire/scripts/rofi_powermenu line 31:
cnflayout=`cat ${CNFR} | grep 'USE_ICON' | cut -d'=' -f2`
          ^-- SC2006 (style): Use $(...) notation instead of legacy backticks `...`.
               ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
cnflayout=$(cat "${CNFR}" | grep 'USE_ICON' | cut -d'=' -f2)


In install/wayfire/scripts/rofi_powermenu line 46:
		-theme ${RASI}
                       ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		-theme "${RASI}"


In install/wayfire/scripts/rofi_powermenu line 61:
		-theme ${CNFR}
                       ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
		-theme "${CNFR}"


In install/wayfire/scripts/rofi_powermenu line 99:
    $option_1)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_powermenu line 102:
    $option_2)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_powermenu line 105:
    $option_3)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_powermenu line 108:
    $option_4)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_powermenu line 111:
    $option_5)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_powermenu line 114:
    $option_6)
    ^-------^ SC2254 (warning): Quote expansions in case patterns to match literally rather than as a glob.


In install/wayfire/scripts/rofi_launcher line 12:
	-theme ${RASI}
               ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
	-theme "${RASI}"


In install/wayfire/scripts/rofi_askpass line 12:
     -theme ${RASI}
            ^-----^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
     -theme "${RASI}"

For more information:
  https://www.shellcheck.net/wiki/SC2068 -- Double quote array expansions to ...
  https://www.shellcheck.net/wiki/SC2034 -- yellow appears unused. Verify use...
  https://www.shellcheck.net/wiki/SC2046 -- Quote this to prevent word splitt...

. error: exit status 1
zsh: exit 1     gh setup
```
