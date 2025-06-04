#!/usr/bin/env bash
# shellcheck disable=all
# File: Wayfire_configurator.sh
# Author: 4ndr0666
# Date: 2024-12-17
set -euo pipefail

# =========================================== // WAYFIRE_CONFIGURATOR.SH //
# --- // Logging:
LOGFILE="$(mktemp /tmp/wayfire_config_log.XXXXXX)"
exec 3>"$LOGFILE"  # File descriptor 3 for logging

function log_debug() {
    echo "[DEBUG] $1" >&3
}

# --- // Error:
trap 'echo "An unexpected error occurred. Please review $LOGFILE for details."; exit 1' ERR

# Function to display messages with formatting
function echo_msg() {
    echo -e "\n=== $1 ===\n"
    log_debug "$1"
}

# Function to prompt user with validation and undo capability
function prompt_with_undo() {
    local prompt="$1"
    local default_value="$2"
    local var_type="$3"
    local user_input=""
    while true; do
        read -rp "$prompt [default: $default_value] (type 'undo' to go back): " user_input
        if [[ -z "$user_input" ]]; then
            user_input="$default_value"
        fi
        if [[ "$user_input" == "undo" ]]; then
            # Signal to handle undo upstream
            echo "UNDO_TRIGGERED"
            return
        fi
        # Validation based on variable type
        case "$var_type" in
            boolean)
                if [[ "$user_input" =~ ^(true|false)$ ]]; then
                    echo "$user_input"
                    return
                else
                    echo "Error: Please enter 'true' or 'false'."
                fi
                ;;
            integer)
                if [[ "$user_input" =~ ^-?[0-9]+$ ]]; then
                    echo "$user_input"
                    return
                else
                    echo "Error: Not a valid integer."
                fi
                ;;
            double)
                if [[ "$user_input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
                    echo "$user_input"
                    return
                else
                    echo "Error: Not a valid floating point number."
                fi
                ;;
            color)
                # Accepts RGBA as "0.1 0.1 0.1 1.0" or hex like "#FF0000FF"
                if [[ "$user_input" =~ ^#?[0-9A-Fa-f]{8}$ ]] || [[ "$user_input" =~ ^([0-1]\.\d+ ){3}[0-1]\.\d+$ ]]; then
                    echo "$user_input"
                    return
                else
                    echo "Error: Please enter a valid RGBA color (e.g., '#FF0000FF' or '0.1 0.1 0.1 1.0')."
                fi
                ;;
            gesture|string)
                # Minimal validation; accept any non-empty input
                if [[ -n "$user_input" ]]; then
                    echo "$user_input"
                    return
                else
                    echo "Error: Input cannot be empty."
                fi
                ;;
            *)
                # Fallback to accepting any input
                echo "$user_input"
                return
                ;;
        esac
    done
}

declare -A modules

# ALPHA MODULE PARAMETERS
modules["alpha.min_value"]="double|0.1|Minimum opacity for alpha plugin (0..1)."
modules["alpha.modifier"]="string|<super> <alt>|Modifier to adjust window opacity by scrolling."

# AUTOSTART MODULE PARAMETERS
modules["autostart.0_environment"]="string|dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP=wayfire|Environment variables to update on autostart."
modules["autostart.dex"]="string|dex -a -s /etc/xdg/autostart/:~/.config/autostart:/usr/local/bin/run-wayfire|Command to run dex for autostart applications."
modules["autostart.apply_themes"]="string|~/.config/wayfire/scripts/gtkthemes &|Command to apply GTK themes."
modules["autostart.set_wallpaper"]="string|~/.config/wayfire/scripts/wallpaper &|Command to set the wallpaper."
modules["autostart.autostart_wf_shell"]="boolean|false|Whether to autostart wf-shell."
modules["autostart.polkit-gnome"]="string|/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1|Command to start Polkit GNOME authentication agent."
modules["autostart.gnome-keyring"]="string|gnome-keyring-daemon --daemonize --start --components=gpg,pkcs11,secrets,ssh|Command to start GNOME Keyring daemon."
modules["autostart.clipman-restore"]="string|clipman restore|Command to restore Clipman clipboard manager."
modules["autostart.clipman-store"]="string|wl-paste -t text --watch clipman store|Command to store clipboard contents."
modules["autostart.idle"]="string|swayidle before-sleep ~/.config/wayfire/scripts/lockscreen|Command to handle idle actions."
modules["autostart.outputs"]="string|kanshi|Command to start kanshi for output management."
modules["autostart.portal"]="string|/usr/libexec/xdg-desktop-portal|Command to start xdg-desktop-portal."
modules["autostart.start_nma"]="string|nm-applet --indicator &|Command to start Network Manager Applet."
modules["autostart.start_notify"]="string|~/.config/wayfire/scripts/notifications &|Command to start notification daemon."
modules["autostart.start_statusbar"]="string|~/.config/wayfire/scripts/statusbar &|Command to start the status bar."

# COMMAND MODULE PARAMETERS
modules["command.binding_alacritty"]="string|<super> KEY_ENTER|Keybinding to launch Alacritty terminal."
modules["command.binding_st"]="string|<super> <shift> KEY_ENTER|Keybinding to launch st terminal."
modules["command.binding_clipman"]="string|<alt> KEY_F1|Keybinding to launch Clipman."
modules["command.binding_restartwaybar"]="string|<ctrl> <alt> KEY_B|Keybinding to restart Waybar."
modules["command.binding_colorpicker"]="string|<super> KEY_P|Keybinding to launch color picker."
modules["command.binding_cutter"]="string|<super> KEY_F5|Keybinding to launch Flawless Cut."
modules["command.binding_dmenuhandler"]="string|<super> KEY_F10|Keybinding to launch dmenuhandler."
modules["command.binding_dmenurecord"]="string|<super> KEY_F12|Keybinding to launch dmenurecord."
modules["command.binding_editor"]="string|<super> KEY_E|Keybinding to launch lite-xl editor."
modules["command.binding_files"]="string|<super> KEY_F|Keybinding to launch Thunar file manager."
modules["command.binding_jdownloader"]="string|<super> KEY_F7|Keybinding to launch JDownloader."
modules["command.binding_kill"]="string|<super> KEY_ESC|Keybinding to launch wf-kill."
modules["command.binding_launcher"]="string|<super> KEY_D|Keybinding to launch Rofi launcher."
modules["command.binding_lf"]="string|<super> KEY_F2|Keybinding to launch lf file manager."
modules["command.binding_lockscreen"]="string|<ctrl> <alt> KEY_L|Keybinding to launch lockscreen script."
modules["command.binding_logout"]="string|<super> KEY_X|Keybinding to launch logout script."
modules["command.binding_lossless"]="string|<super> KEY_F6|Keybinding to launch losslesscut."
modules["command.binding_media"]="string|<super> KEY_F11|Keybinding to launch media script."
modules["command.binding_micro"]="string|<super> KEY_F3|Keybinding to launch Micro editor."
modules["command.binding_min"]="string|<super> KEY_M|Keybinding to launch min-browser."
modules["command.binding_nm"]="string|<super> KEY_N|Keybinding to launch network manager script."
modules["command.binding_nvim"]="string|<super> KEY_F4|Keybinding to launch Neovim in st."
modules["command.binding_oom"]="string|<super> KEY_0|Keybinding to trigger OOM script."
modules["command.binding_argon"]="string|<super> KEY_F8|Keybinding to launch Argon."
modules["command.binding_pacui"]="string|<super> KEY_F9|Keybinding to launch pacui."
modules["command.binding_playwithmpv"]="string|<super> KEY_F1|Keybinding to toggle MPV playback."
modules["command.binding_runner"]="string|<super> KEY_R|Keybinding to launch Rofi runner."
modules["command.binding_asroot"]="string|<alt> <super> KEY_R|Keybinding to launch Rofi as root."
modules["command.binding_screenshot"]="string|<super> KEY_SYSRQ|Keybinding to launch screenshot script."
modules["command.binding_screenshot_10"]="string|<shift> KEY_SYSRQ|Keybinding to launch screenshot with 10-second delay."
modules["command.binding_screenshot_5"]="string|<alt> KEY_SYSRQ|Keybinding to launch screenshot with 5-second delay."
modules["command.binding_screenshot_interactive"]="string|KEY_SYSRQ|Keybinding to launch interactive screenshot."
modules["command.binding_searchmaster"]="string|<ctrl> <alt> KEY_9|Keybinding to launch searchmaster script."
modules["command.binding_shots"]="string|<super> KEY_S|Keybinding to launch Rofi screenshot."
modules["command.binding_theme"]="string|<super> <shift> KEY_C|Keybinding to launch theme script."
modules["command.binding_web"]="string|<super> KEY_W|Keybinding to launch Brave browser."
modules["command.binding_media-play-pause"]="string|KEY_PLAYPAUSE|Keybinding to toggle media play/pause."
modules["command.binding_mute"]="string|KEY_MUTE|Keybinding to toggle mute."

# COMMAND EXECUTIONS
modules["command.command_alacritty"]="string|~/.config/wayfire/scripts/alacritty|Command to execute Alacritty terminal."
modules["command.command_st"]="string|~/.config/wayfire/scripts/st|Command to execute st terminal."
modules["command.command_clipman"]="string|clipman pick -t wofi|Command to execute Clipman."
modules["command.command_restartwaybar"]="string|alacritty -e /home/andro/.config/wayfire/waybar/scripts/restart_waybar.sh|Command to restart Waybar."
modules["command.command_colorpicker"]="string|~/.config/wayfire/scripts/colorpicker|Command to execute color picker."
modules["command.command_cutter"]="string|flawless-cut|Command to execute Flawless Cut."
modules["command.command_dmenuhandler"]="string|~/.local/bin/dmenuhandler|Command to execute dmenuhandler."
modules["command.command_dmenurecord"]="string|~/.local/bin/dmenurecord|Command to execute dmenurecord."
modules["command.command_editor"]="string|lite-xl|Command to execute lite-xl editor."
modules["command.command_files"]="string|thunar|Command to execute Thunar file manager."
modules["command.command_jdownloader"]="string|jdownloader|Command to execute JDownloader."
modules["command.command_kill"]="string|wf-kill|Command to execute wf-kill."
modules["command.command_launcher"]="string|~/.config/wayfire/scripts/rofi_launcher|Command to execute Rofi launcher."
modules["command.command_lf"]="string|st -e lf|Command to execute lf file manager in st."
modules["command.command_lockscreen"]="string|~/.config/wayfire/scripts/lockscreen|Command to execute lockscreen script."
modules["command.command_logout"]="string|~/.config/wayfire/scripts/rofi_powermenu|Command to execute logout script."
modules["command.command_lossless"]="string|losslesscut|Command to execute losslesscut."
modules["command.command_media"]="string|~/.local/bin/wofi_media.sh|Command to execute media script."
modules["command.command_micro"]="string|alacritty -e micro|Command to execute Micro editor in Alacritty."
modules["command.command_min"]="string|min-browser|Command to execute min-browser."
modules["command.command_nm"]="string|~/.config/wayfire/scripts/rofi_network|Command to execute network manager script."
modules["command.command_nvim"]="string|st -e nvim|Command to execute Neovim in st."
modules["command.command_oom"]="string|/usr/local/bin/trigger_oom.sh|Command to trigger OOM script."
modules["command.command_argon"]="string|argon|Command to execute Argon."
modules["command.command_pacui"]="string|alacritty -e pacui|Command to execute pacui in Alacritty."
modules["command.command_playwithmpv"]="string|~/.local/bin/pwmpv-toggle|Command to toggle MPV playback."
modules["command.command_runner"]="string|~/.config/wayfire/scripts/rofi_runner|Command to execute Rofi runner."
modules["command.command_asroot"]="string|~/.config/wayfire/scripts/rofi_asroot|Command to execute Rofi as root."
modules["command.command_screenshot"]="string|~/.config/wayfire/scripts/rofi_screenshot|Command to execute Rofi screenshot."
modules["command.command_screenshot_10"]="string|~/.config/wayfire/scripts/screenshot --in10|Command to execute screenshot with 10s delay."
modules["command.command_screenshot_5"]="string|~/.config/wayfire/scripts/screenshot --in5|Command to execute screenshot with 5s delay."
modules["command.command_screenshot_interactive"]="string|~/.config/wayfire/scripts/screenshot --area|Command to execute interactive screenshot."
modules["command.command_searchmaster"]="string|st -e /usr/local/bin/searchmaster.py|Command to execute searchmaster script."
modules["command.command_shots"]="string|~/.config/wayfire/scripts/rofi_screenshot|Command to execute Rofi screenshot."
modules["command.command_theme"]="string|~/.config/wayfire/theme/theme.sh --pywal|Command to execute theme script."
modules["command.command_web"]="string|brave-beta --ozone-platform=wayland --enable-features=UseOzonePlatform --disable-gpu --disable-software-rasterizer --disable-crash-reporter --disable-background-networking --disable-component-extensions-with-background-pages & echo \$! > /tmp/brave_pid|Command to execute Brave browser with specific flags."
modules["command.command_volume_down"]="string|~/.config/wayfire/scripts/volume --dec|Command to decrease volume."
modules["command.command_volume_up"]="string|~/.config/wayfire/scripts/volume --inc|Command to increase volume."
modules["command.command_mute"]="string|~/.config/wayfire/scripts/volume --toggle|Command to toggle mute."
modules["command.command_media-play-pause"]="string|playerctl play-pause|Command to toggle media play/pause."

# CUBE MODULE PARAMETERS
modules["cube.activate"]="string|<ctrl> <alt> BTN_LEFT|Button/activator to rotate the cube."
modules["cube.background"]="color|0.024 0.039 0.074 1.0|Background color for the cube (RGBA)."
modules["cube.background_mode"]="string|simple|Background mode (simple, cubemap, skydome)."
modules["cube.deform"]="integer|0|Deformation type: 0->None, 1->Cylinder, 2->Star."
modules["cube.initial_animation"]="integer|350|Initial animation duration in milliseconds."
modules["cube.light"]="boolean|true|Enable lighting effect on the cube."
modules["cube.rotate_left"]="string|<ctrl> <alt> KEY_LEFT|Activator to rotate the cube left."
modules["cube.rotate_right"]="string|<ctrl> <alt> KEY_RIGHT|Activator to rotate the cube right."
modules["cube.skydome_mirror"]="boolean|true|Mirror skydome texture."
modules["cube.speed_spin_horiz"]="double|0.02|Horizontal spin velocity."
modules["cube.speed_spin_vert"]="double|0.02|Vertical spin velocity."
modules["cube.speed_zoom"]="double|0.07|Zoom speed factor."
modules["cube.zoom"]="double|0.1|Zoom-out level (0.0 means no zoom)."

# DECORATION MODULE PARAMETERS
modules["decoration.active_color"]="color|0.494 0.498 0.506 1.0|Color when the window is active (RGBA)."
modules["decoration.border_size"]="integer|3|Size of the window border in pixels."
modules["decoration.button_order"]="string|minimize maximize close|Order of window buttons."
modules["decoration.font"]="string|meslo LGS NF|Font used for window title bars."
modules["decoration.ignore_views"]="string|none|Disable decoration for matching windows."
modules["decoration.inactive_color"]="color|0.047 0.078 0.149 1.0|Color when the window is inactive (RGBA)."
modules["decoration.title_height"]="integer|0|Height of the window title bar in pixels."

# EXPO MODULE PARAMETERS
modules["expo.background"]="color|0.024 0.039 0.074 1.0|Background color for expo plugin."
modules["expo.duration"]="integer|200|Zoom duration in milliseconds for expo."
modules["expo.offset"]="double|10.0|Delimiter offset between workspaces."
modules["expo.toggle"]="string|<super> KEY_E|Activator to toggle expo."

# FOCUS-REQUEST MODULE PARAMETERS
modules["focus-request.auto_grant_focus"]="boolean|true|Automatically grant focus requests."

# GRID MODULE PARAMETERS
modules["grid.duration"]="string|300ms circle|Duration of grid animations."
modules["grid.restore"]="string|<super> KEY_K | <super> KEY_DOWN | <super> KEY_KP0|Activator to restore window to original size and position."
modules["grid.slot_b"]="string|<super> KEY_KP2|Activator to position window at the bottom edge of the screen."
modules["grid.slot_bl"]="string|<alt> KEY_N | <super> KEY_KP1|Activator to position window at the bottom left corner."
modules["grid.slot_br"]="string|<alt> KEY_DOT | <super> KEY_KP3|Activator to position window at the bottom right corner."
modules["grid.slot_c"]="string|<super> KEY_UP | <super> KEY_KP5|Activator to maximize window to center."
modules["grid.slot_l"]="string|<super> KEY_H | <super> KEY_KP4|Activator to position window at the left edge."
modules["grid.slot_r"]="string|<super> KEY_L | <super> KEY_KP6|Activator to position window at the right edge."
modules["grid.slot_t"]="string|<super> KEY_KP8|Activator to position window at the top edge."
modules["grid.slot_tl"]="string|<alt> KEY_Y | <super> KEY_KP7|Activator to position window at the top left corner."
modules["grid.slot_tr"]="string|<alt> KEY_O | <super> KEY_KP9|Activator to position window at the top right corner."
modules["grid.type"]="string|wobbly|Type of grid animation (simple, wobbly)."

# IDLE MODULE PARAMETERS
modules["idle.toggle"]="string|<super> KEY_Z|Activator to disable/enable idle."
modules["idle.screensaver_timeout"]="integer|-1|Seconds of inactivity before screensaver (-1 disables)."
modules["idle.dpms_timeout"]="integer|-1|Seconds of inactivity before DPMS (-1 disables)."
modules["idle.disable_on_fullscreen"]="boolean|true|Disable idle on fullscreen windows."
modules["idle.cube_max_zoom"]="double|1.5|Maximum zoom level for idle cube rotation."
modules["idle.cube_rotate_speed"]="double|1.0|Cube rotation speed for idle."
modules["idle.cube_zoom_speed"]="integer|1000|Cube zoom speed time in milliseconds."

# INVERT MODULE PARAMETERS
modules["invert.toggle"]="string|<super> KEY_I|Key or gesture to toggle color inversion."

# MOVE MODULE PARAMETERS
modules["move.activate"]="string|<super> BTN_LEFT|Button/activator to drag and move windows."
modules["move.enable_snap"]="boolean|true|Enable snapping windows to screen edges."
modules["move.enable_snap_off"]="boolean|true|Enable snapping off when moving snapped windows."
modules["move.join_views"]="boolean|false|Disallow independently moving dialogues."
modules["move.preview_base_border"]="string|#15FFFFFF|Preview border color."
modules["move.preview_base_color"]="string|#222222AA|Preview base color."
modules["move.preview_border_width"]="integer|2|Preview border width in pixels."
modules["move.snap_off_threshold"]="integer|10|Pixels required to move a snapped window."
modules["move.snap_threshold"]="integer|10|Pixels from edge to trigger snap."

# PRESERVE-OUTPUT MODULE PARAMETERS
modules["preserve-output.last_output_focus_timeout"]="integer|10000|Timeout in milliseconds to preserve output focus."

# RESIZE MODULE PARAMETERS
modules["resize.activate"]="string|<super> BTN_RIGHT|Button/activator to drag and resize windows."
modules["resize.activate_preserve_aspect"]="string|<ctrl> <super> BTN_RIGHT|Button/activator to drag and resize while preserving aspect ratio."

# SESSION-LOCK MODULE PARAMETERS
modules["session-lock.enable"]="boolean|true|Enable the session lock protocol."
modules["session-lock.command"]="string|~/.config/wayfire/scripts/lockscreen|Command to execute when locking the session."

# SIMPLE-TILE MODULE PARAMETERS
modules["simple-tile.animation_duration"]="string|0ms circle|Animation duration (e.g., '0ms circle')."
modules["simple-tile.button_move"]="string|<super> BTN_LEFT|Mouse/activator to drag/move tiled windows."
modules["simple-tile.button_resize"]="string|<super> BTN_RIGHT|Mouse/activator to resize tiled windows."
modules["simple-tile.inner_gap_size"]="integer|5|Inner gap size between tiled windows."
modules["simple-tile.outer_horiz_gap_size"]="integer|0|Outer horizontal gap size."
modules["simple-tile.outer_vert_gap_size"]="integer|0|Outer vertical gap size."
modules["simple-tile.preview_base_border"]="string|#15FFFFFF|Preview border color in hex RGBA."
modules["simple-tile.preview_base_color"]="string|#8080FF80|Preview base color in hex RGBA."
modules["simple-tile.preview_border_width"]="integer|2|Border width for preview rectangle."
modules["simple-tile.tile_by_default"]="string|all|Conditions (criteria) for tiling by default."
modules["simple-tile.key_focus_above"]="string|<super> KEY_UP|Key to focus window above."
modules["simple-tile.key_focus_below"]="string|<super> KEY_DOWN|Key to focus window below."
modules["simple-tile.key_focus_left"]="string|<super> KEY_LEFT|Key to focus window left."
modules["simple-tile.key_focus_right"]="string|<super> KEY_RIGHT|Key to focus window right."
modules["simple-tile.key_toggle"]="string|<super> KEY_SPACE|Key to toggle tiling mode."
modules["simple-tile.keep_fullscreen_on_adjacent"]="boolean|true|Keep fullscreen state when focusing adjacent windows."

# SWITCHER MODULE PARAMETERS
modules["switcher.gesture_toggle"]="string|edge-swipe down 3|Gesture to toggle the switcher."
modules["switcher.next_view"]="string|<super> KEY_TAB|Keybinding to switch to the next view."
modules["switcher.prev_view"]="string|<super> <shift> KEY_TAB|Keybinding to switch to the previous view."
modules["switcher.speed"]="string|300ms circle|Duration of switcher animation."
modules["switcher.touch_sensitivity"]="double|1.0|Touch sensitivity for the switcher."
modules["switcher.view_thumbnail_rotation"]="double|30|Rotation angle for view thumbnails."
modules["switcher.view_thumbnail_scale"]="double|1.0|Scale factor for view thumbnails."

# SCALE MODULE PARAMETERS
modules["scale.allow_zoom"]="boolean|true|Allow zooming in scale mode."
modules["scale.bg_color"]="string|#1A1A1AE6|Background color for scale mode (hex RGBA)."
modules["scale.close_on_new_view"]="boolean|false|Close scale mode when a new view is opened."
modules["scale.duration"]="string|300ms circle|Duration of scale animations."
modules["scale.inactive_alpha"]="double|0.4|Alpha value for inactive scale items."
modules["scale.include_minimized"]="boolean|true|Include minimized windows in scale mode."
modules["scale.interact"]="boolean|true|Enable interactions in scale mode."
modules["scale.middle_click_close"]="boolean|false|Close window on middle click in scale mode."
modules["scale.minimized_alpha"]="double|0.45|Alpha value for minimized windows in scale mode."
modules["scale.outer_margin"]="integer|0|Outer margin in scale mode."
modules["scale.spacing"]="integer|50|Spacing between windows in scale mode."
modules["scale.text_color"]="string|#15FFFFFF|Text color for window titles in scale mode (hex RGBA)."
modules["scale.title_font_size"]="integer|12|Font size for window titles in scale mode."
modules["scale.title_overlay"]="string|all|Overlay setting for window titles (e.g., all)."
modules["scale.title_position"]="string|center|Position of window titles (e.g., center)."
modules["scale.toggle"]="string|<super> KEY_V|Keybinding to toggle scale mode."
modules["scale.toggle_all"]="string|hotspot bottom-left 100x10 1000 | <super> <ctrl> KEY_V|Keybinding to toggle all scale mode features."

# VSWITCH MODULE PARAMETERS
modules["vswitch.duration"]="integer|300|Duration of workspace switching animation in ms."
modules["vswitch.gap"]="integer|20|Gap between workspaces during switching."
modules["vswitch.background"]="color|0.024 0.039 0.074 1.0|Background color for vswitch gap."
modules["vswitch.wraparound"]="boolean|false|Enable wraparound when switching workspaces."

# VSWIPE MODULE PARAMETERS
modules["vswipe.background"]="color|0.024 0.039 0.074 1.0|Background color for vswipe."
modules["vswipe.delta_threshold"]="double|24.0|Delta threshold for swipe detection."
modules["vswipe.duration"]="integer|180|Swipe animation duration in ms."
modules["vswipe.enable_free_movement"]="boolean|false|Enable free movement swiping."
modules["vswipe.enable_horizontal"]="boolean|true|Allow horizontal swiping."
modules["vswipe.enable_vertical"]="boolean|false|Allow vertical swiping."
modules["vswipe.fingers"]="integer|3|Number of fingers required for swiping."
modules["vswipe.gap"]="double|32.0|Gap between transitions during swipe."
modules["vswipe.speed_cap"]="double|0.05|Cap on swipe speed."
modules["vswipe.speed_factor"]="double|256.0|Swipe speed factor."
modules["vswipe.threshold"]="double|0.35|Swipe threshold."

# WOBBLY MODULE PARAMETERS
modules["wobbly.friction"]="double|3.0|Friction coefficient for wobble effect."
modules["wobbly.spring_k"]="double|8.0|Spring constant for wobble effect."
modules["wobbly.grid_resolution"]="integer|6|Grid resolution for wobble effect."

# WSETS MODULE PARAMETERS
modules["wsets.label_duration"]="string|5000ms circle|Duration to display workspace set labels."
modules["wsets.send_to_wset_1"]="string|<super> <shift> <alt> KEY_1|Keybinding to send the focused window to workspace set 1."
modules["wsets.send_to_wset_2"]="string|<super> <shift> <alt> KEY_2|Keybinding to send the focused window to workspace set 2."
modules["wsets.send_to_wset_3"]="string|<super> <shift> <alt> KEY_3|Keybinding to send the focused window to workspace set 3."
modules["wsets.wset_1"]="string|<super> <alt> KEY_1|Keybinding to switch to workspace set 1."
modules["wsets.wset_2"]="string|<super> <alt> KEY_2|Keybinding to switch to workspace set 2."
modules["wsets.wset_3"]="string|<super> <alt> KEY_3|Keybinding to switch to workspace set 3."

# WM-ACTIONS MODULE PARAMETERS
modules["wm-actions.minimize"]="string|<shift> <super> KEY_F5|Keybinding to minimize the active view."
modules["wm-actions.send_to_back"]="string|<shift> <super> KEY_F4|Keybinding to send the active view to the back."
modules["wm-actions.toggle_always_on_top"]="string|<shift> <super> KEY_F7|Keybinding to toggle always-on-top state."
modules["wm-actions.toggle_fullscreen"]="string|<shift> <super> KEY_F8|Keybinding to toggle fullscreen state."
modules["wm-actions.toggle_maximize"]="string|<shift> <super> KEY_F6|Keybinding to toggle maximize state."
modules["wm-actions.toggle_showdesktop"]="string|<shift> <super> KEY_F9|Keybinding to show the desktop."
modules["wm-actions.toggle_sticky"]="string|<shift> <super> KEY_F8|Keybinding to toggle sticky state."

# WORKAROUNDS MODULE PARAMETERS
modules["workarounds.all_dialogs_modal"]="boolean|true|Make all dialogs modal."
modules["workarounds.app_id_mode"]="string|stock|Application ID mode."
modules["workarounds.discard_command_output"]="boolean|true|Discard output from commands invoked by Wayfire."
modules["workarounds.dynamic_repaint_delay"]="boolean|true|Allow dynamic repaint delay."
modules["workarounds.enable_input_method_v2"]="boolean|false|Enable input method version 2."
modules["workarounds.enable_opaque_region_damage_optimizations"]="boolean|false|Enable opaque region damage optimizations."
modules["workarounds.enable_so_unloading"]="boolean|false|Enable calling dlclose() when unloading plugins."
modules["workarounds.force_preferred_decoration_mode"]="boolean|false|Force clients to use compositor-preferred decoration mode."
modules["workarounds.remove_output_limits"]="boolean|false|Allow views to overlap between multiple outputs."
modules["workarounds.use_external_output_configuration"]="boolean|false|Use external output configuration instead of Wayfire's own."

# WROT MODULE PARAMETERS
modules["wrot.activate"]="string|<shift> <super> BTN_LEFT|Button/activator to rotate windows."
modules["wrot.activate_3d"]="string|<shift> <super> BTN_RIGHT|Button/activator to activate 3D rotation."
modules["wrot.invert"]="boolean|false|Invert rotation direction."
modules["wrot.reset"]="string|<shift> <super> KEY_R|Keybinding to reset rotation."
modules["wrot.reset_radius"]="double|25.0|Radius to reset rotation."
modules["wrot.sensitivity"]="integer|24|Sensitivity of rotation."

# ZOOM MODULE PARAMETERS
modules["zoom.modifier"]="string|<ctrl> <super>|Modifier for zoom scrolling."
modules["zoom.smoothing_duration"]="integer|300|Smoothing duration in milliseconds."
modules["zoom.speed"]="double|0.01|Zoom speed factor."
modules["zoom.interpolation_method"]="integer|0|Interpolation method for zoom (e.g., 0)."
modules["zoom.zoom"]="double|0.1|Zoom level."

# Additional Commented-Out Modules for Compatibility
# These modules are included as commented-out blocks to ensure compatibility.
# Users can activate them by uncommenting and configuring as needed.

# [annotate]
# clear_workspace = <alt> <super> KEY_C
# draw = <alt> <super> BTN_LEFT
# from_center = true
# line_width = 3.000000
# method = draw
# stroke_color = \#FF0000FF

# [autorotate-iio]
# lock_rotation = false
# rotate_down = <ctrl> <super> KEY_DOWN
# rotate_left = <ctrl> <super> KEY_LEFT
# rotate_right = <ctrl> <super> KEY_RIGHT
# rotate_up = <ctrl> <super> KEY_UP

# [bench]
# average_frames = 25
# position = top_center

# [blur]
# blur_by_default = type is "toplevel"
# bokeh_degrade = 1
# bokeh_iterations = 15
# bokeh_offset = 5.000000
# box_degrade = 1
# box_iterations = 2
# box_offset = 1.000000
# gaussian_degrade = 1
# gaussian_iterations = 2
# gaussian_offset = 1.000000
# kawase_degrade = 3
# kawase_iterations = 2
# kawase_offset = 1.700000
# method = kawase
# saturation = 1.000000
# toggle = none

# [crosshair]
# line_color = \#FF0000FF
# line_width = 2

# [input-device]
# output =

# [mag]
# default_height = 660
# toggle = <shift> <super> KEY_M
# zoom_level = 75

# [force-fullscreen]
# constrain_pointer = false
# constraint_area = view
# key_toggle_fullscreen = <alt> <super> KEY_F
# preserve_aspect = true
# transparent_behind_views = true
# x_skew = 0.000000
# y_skew = 0.000000

# [ghost]
# ghost_match =
# ghost_toggle =

# [foreign-toplevel]

# [focus-change]
# cross_output = false
# cross_workspace = false
# down = <shift> <super> KEY_DOWN
# grace_down = 1
# grace_left = 1
# grace_right = 1
# grace_up = 1
# left = <shift> <super> KEY_LEFT
# raise_on_change = true
# right = <shift> <super> KEY_RIGHT
# scan_height = 0
# scan_width = 0
# up = <shift> <super> KEY_UP

# [focus-steal-prevent]
# cancel_keys = KEY_ENTER
# deny_focus_views = none
# timeout = 1000

# [follow-focus]
# change_output = true
# change_view = true
# focus_delay = 400
# raise_on_top = true
# threshold = 10

# [ipc]
#

# [ipc-rules]
#

# [join-views]
#

# [keycolor]
# color = \#000000FF
# opacity = 0.250000
# threshold = 0.500000

# [view-shot]
# capture = <alt> <super> BTN_MIDDLE
# command = notify-send "The view under cursor was captured to %f"
# filename = /tmp/snapshot-%F-%T.png

# [water]
# activate = <ctrl> <super> BTN_LEFT

# [wayfire-shell]
# toggle_menu = <super>

# [shortcuts-inhibit]
# break_grab = none
# ignore_views = none
# inhibit_by_default = none

# [showrepaint]
# reduce_flicker = true
# toggle = <alt> <super> KEY_S

# --- // Map definitions:
declare -A synergy_map
synergy_map["snap"]="grid"
synergy_map["set_alpha"]="alpha"
synergy_map["maximize"]="animate"
synergy_map["invert_colors"]="invert"
synergy_map["zoom"]="zoom"
synergy_map["rotate_cube"]="cube"

# Array to keep track of required plugins based on user selections
declare -A synergy_plugins_needed

# Function to list all available modules
function dynamic_list_all_modules() {
    declare -A module_list
    for key in "${!modules[@]}"; do
        mod_name="${key%%.*}"
        module_list["$mod_name"]=1
    done
    echo "${!module_list[@]}"
}

# Function to prompt user for module selection
function prompt_for_modules() {
    local mod_list=$(dynamic_list_all_modules)
    echo_msg "AVAILABLE MODULES FOR CONFIGURATION:"
    echo "$mod_list"
    echo "Type space-separated module names or 'all' to configure all."
    read -rp "Modules to configure: " selected
    if [[ "$selected" == "all" ]]; then
        echo "$mod_list"
    else
        echo "$selected"
    fi
}

# Function to configure a specific module
function configure_module() {
    local mod_name="$1"
    local final_str="[${mod_name}]\n"

    declare -a props_for_mod=()
    for key in "${!modules[@]}"; do
        local prefix="${key%%.*}"
        if [[ "$prefix" == "$mod_name" ]]; then
            props_for_mod+=("$key")
        fi
    done
    if [ ${#props_for_mod[@]} -eq 0 ]; then
        echo_msg "No known parameters for module: $mod_name"
        return ""
    fi

    # Store user answers in associative array
    declare -A stored_answers
    local param_index=0
    while [ $param_index -lt ${#props_for_mod[@]} ]; do
        local key="${props_for_mod[$param_index]}"
        local raw="${modules[$key]}"
        local field_type="${raw%%|*}"
        local remain="${raw#*|}"
        local default_val="${remain%%|*}"
        local desc="${remain#*|}"
        local param_name="${key#*.}"

        echo_msg "CONFIGURING: [$mod_name] -> $param_name"
        echo "Description: $desc"

        local user_val
        user_val=$(prompt_with_undo "$param_name" "$default_val" "$field_type")
        if [[ "$user_val" == "UNDO_TRIGGERED" ]]; then
            if [ $param_index -gt 0 ]; then
                param_index=$((param_index - 1))
                unset "stored_answers[${props_for_mod[$param_index]#*.}]"
                continue
            else
                echo "Already at the first parameter. Cannot undo further."
                continue
            fi
        fi
        stored_answers["$param_name"]="$user_val"
        param_index=$((param_index + 1))
    done

    # Compile the module's configuration
    for param_key in "${props_for_mod[@]}"; do
        local param_name="${param_key#*.}"
        local value="${stored_answers[$param_name]}"
        final_str+="${param_name} = ${value}\n"

        # Synergy checks based on the synergy_map
        for key in "${!synergy_map[@]}"; do
            if [[ "$param_name" == "$key" ]]; then
                synergy_plugins_needed["${synergy_map[$key]}"]=1
            fi
        done

        # Additionally, handle the commands that require certain plugins
        if [[ "$mod_name" == "command" ]]; then
            if [[ "$param_name" =~ ^command_ ]]; then
                local command="${value%%|*}"
                for cmd in "${!synergy_map[@]}"; do
                    if [[ "$command" == *"$cmd"* ]]; then
                        synergy_plugins_needed["${synergy_map[$cmd]}"]=1
                    fi
                done
            fi
        fi
    done

    echo -e "$final_str"
}

declare -a WINDOW_RULES_COLLECTED=()

function add_window_rule() {
    local rule_name="$1"
    local rule_str="$2"
    WINDOW_RULES_COLLECTED+=("$rule_name|$rule_str")
}

function parse_window_rule_command_for_synergy() {
    local cmd="$1"
    for key in "${!synergy_map[@]}"; do
        if [[ "$cmd" =~ ^$key ]]; then
            synergy_plugins_needed["${synergy_map[$key]}"]=1
        fi
    done
}

function set_window_rules_module() {
    echo_msg "CONFIGURE [window-rules] MODULE"
    local final_str="[window-rules]\n"
    while true; do
        read -rp "Would you like to add a window rule? (yes/no): " ans
        if [[ ! "$ans" =~ ^[Yy]es$ ]]; then
            break
        fi

        local rule_name
        while true; do
            read -rp "Enter rule name (e.g., rule_maximize_alacritty): " rule_name
            if [ -z "$rule_name" ]; then
                echo "Rule name cannot be empty!"
            else
                break
            fi
        done

        # Event selection
        local event
        while true; do
            read -rp "Choose event (created/unmaximized/maximized/minimized/fullscreened): " event
            case "$event" in
                created|unmaximized|maximized|minimized|fullscreened)
                    break
                    ;;
                *)
                    echo "Invalid event. Please choose from (created, unmaximized, maximized, minimized, fullscreened)."
                    ;;
            esac
        done

        # Criteria
        read -rp "Add criteria? (yes/no): " has_criteria
        local criteria_str=""
        if [[ "$has_criteria" =~ ^[Yy]es$ ]]; then
            local done_criteria=false
            while [ "$done_criteria" = false ]; do
                echo_msg "Add a criterion (e.g., app_id is \"Alacritty\", type is \"toplevel\"). Type 'done' to finish."
                read -rp "Criterion: " c
                if [[ "$c" == "done" || -z "$c" ]]; then
                    done_criteria=true
                    break
                fi
                # Basic validation could be added here
                if [ -z "$criteria_str" ]; then
                    criteria_str="$c"
                else
                    criteria_str="($criteria_str & $c)"
                fi
            done
        fi

        # Command
        read -rp "Enter the command (e.g., maximize, snap top_left, set alpha 0.5): " command
        if [ -z "$command" ]; then
            command="maximize"
        fi

        # Add to window rules
        local rule_final=""
        if [ -n "$criteria_str" ]; then
            rule_final="on $event if $criteria_str then $command"
        else
            rule_final="on $event then $command"
        fi

        final_str+="$rule_name = $rule_final\n"
        add_window_rule "$rule_name" "$rule_final"

        # Synergy checks based on command
        parse_window_rule_command_for_synergy "$command"
    done

    echo -e "$final_str"
}

# Function to ensure plugins are included in [core].plugins without duplication
function ensure_plugins_in_core() {
    local plugins_line="$1"
    local final_plugins=()

    # Convert existing plugins to an array
    IFS=' ' read -ra existing_plugins <<< "$plugins_line"

    # Add existing plugins to final_plugins array
    for plugin in "${existing_plugins[@]}"; do
        final_plugins+=("$plugin")
    done

    # Add required plugins from synergy_plugins_needed
    for plugin in "${!synergy_plugins_needed[@]}"; do
        # Check if plugin already exists
        if [[ ! " ${final_plugins[@]} " =~ " $plugin " ]]; then
            final_plugins+=("$plugin")
            log_debug "Added plugin '$plugin' to [core].plugins for synergy."
        fi
    done

    # Assemble final plugins string
    local final_plugins_str=$(printf " %s" "${final_plugins[@]}")
    final_plugins_str="${final_plugins_str:1}"  # Remove leading space

    echo "$final_plugins_str"
}

# Function to configure the [core] module
function configure_core_final() {
    echo_msg "CONFIGURING [core] MODULE"
    local core_section="[core]\n"
    local default_plugins="alpha animate autostart command cube decoration expo fast-switcher grid idle move oswitch pin place preserve-output resize session-lock scale simple-tile switcher vswipe vswitch wf-kill window-rules wm-actions wobbly workarounds wrot wsets zoom"

    # Ensure synergy plugins are included
    local final_plugins=$(ensure_plugins_in_core "$default_plugins")
    core_section+="plugins = \\\n  $(echo "$final_plugins" | sed 's/ / \\\n  /g')\n"
    core_section+="preferred_decoration_mode = server\n"
    core_section+="background_color = 0.024 0.039 0.074 1.0\n"
    core_section+="close_top_view = <super> KEY_Q | <alt> KEY_F4\n"
    core_section+="exit = <alt> <ctrl> KEY_BACKSPACE\n"
    core_section+="focus_button_with_modifiers = false\n"
    core_section+="focus_buttons = BTN_LEFT\n"
    core_section+="focus_buttons_passthrough = true\n"
    core_section+="max_render_time = -1\n"
    core_section+="vheight = 3\n"
    core_section+="vwidth = 3\n"
    core_section+="xwayland = true\n"

    echo -e "$core_section"
}

# Function to validate the final configuration before writing to file
function validate_final_config() {
    local config_file="$1"
    if ! wayfire --check-config "$config_file" >/dev/null 2>&1; then
        echo "Error: The generated configuration file has syntax errors."
        echo "Please review $config_file and the debug log at $LOGFILE for details."
        exit 1
    fi
}

# Function to backup existing configuration
function backup_existing_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.backup_$(date +%F_%T)"
        echo_msg "Existing configuration backed up to ${config_file}.backup_$(date +%F_%T)"
    fi
}

# Function to merge new configuration with existing one
function merge_configurations() {
    local new_config="$1"
    local existing_config="$2"
    local merged_config="$3"

    if [ ! -f "$existing_config" ]; then
        cp "$new_config" "$merged_config"
        echo_msg "No existing configuration found. New configuration copied to $merged_config."
        return
    fi

    # Use awk to merge configurations, giving precedence to new_config
    awk '
        BEGIN { FS="="; OFS="=" }
        FNR==NR {
            config[$1] = $2;
            next
        }
        {
            if ($1 in config) {
                print $1, config[$1]
                delete config[$1]
            } else {
                print $0
            }
        }
        END {
            for (k in config) {
                print k, config[k]
            }
        }
    ' "$new_config" "$existing_config" > "$merged_config"

    echo_msg "Configurations merged successfully into $merged_config."
}

# Function to perform cleanup
function cleanup() {
    rm -f "$LOGFILE"
    echo_msg "Cleanup completed. Temporary files removed."
}

# Function to configure all selected modules and assemble the final configuration
function configure_all_modules() {
    local final_config="# Generated Wayfire Config - Production-Ready\n\n"

    # Step 1: Core configuration
    local core_config=$(configure_core_final)
    final_config+="$core_config\n"

    # Step 2: Configure each selected module
    for mod in "${chosen_mods[@]}"; do
        if [[ "$mod" == "core" ]]; then
            continue
        fi
        if [[ "$mod" == "window-rules" ]]; then
            local wrules=$(set_window_rules_module)
            final_config+="$wrules\n"
            continue
        fi
        local mod_out=$(configure_module "$mod")
        final_config+="$mod_out\n"
    done

    # Step 3: Add window rules
    # Removed as window rules are handled in loop.

    # Step 4: Final notes and user instructions
    final_config+="#\n# NOTE: The [core] section has been updated to include synergy plugins for your selected commands.\n"
    final_config+="# This script merges synergy requirements (e.g., 'grid' plugin for 'snap' rules) automatically.\n"
    final_config+="# You can remove or reorder plugins in 'plugins = ...' if needed.\n"
    final_config+="# Always review these changes manually and confirm synergy with your existing setup.\n#\n"

    echo -e "$final_config"
}

# Enhanced error handling for unexpected exits
trap 'echo "An unexpected error occurred. Please review $LOGFILE for details."; cleanup; exit 1' ERR

# Main orchestration function
function main_final() {
    echo_msg "WAYFIRE UNIVERSAL CONFIG FINAL (CYCLE 2 - Final)"
    # Step 1: Which modules does the user want?
    local mod_list_str=$(prompt_for_modules)
    local final_config="# Generated Wayfire Config - Production-Ready\n\n"

    # Step 2: For each module name, gather config
    IFS=' ' read -ra chosen_mods <<< "$mod_list_str"

    # Handle special case for [window-rules]
    local want_window_rules=false

    for mod in "${chosen_mods[@]}"; do
        if [[ "$mod" == "window-rules" ]]; then
            want_window_rules=true
            break
        fi
    done

    # Collect all modules if 'all' is selected
    if [[ "$mod_list_str" == "all" ]]; then
        declare -A all_mods=()
        for key in "${!modules[@]}"; do
            local modn="${key%%.*}"
            all_mods["$modn"]=1
        done
        chosen_mods=("${!all_mods[@]}")
        want_window_rules=true
    fi

    # Step 3: Configure all modules
    local config=$(configure_all_modules)
    final_config+="$config"

    # Step 4: Final notes and user instructions
    final_config+="#\n# Configuration complete. Please merge the relevant sections into your wayfire.ini.\n"
    final_config+="# Ensure that you back up your existing wayfire.ini before applying the new configuration.\n#\n"

    # Step 5: Output to file
    local out_file="wayfire_universal_config.ini"
    echo -e "$final_config" > "$out_file"
    echo_msg "CONFIGURATION FINALIZED: $out_file"
    echo "A debug log was stored in: $LOGFILE"
    echo "Feel free to remove or keep that log. Manual review is encouraged to confirm synergy and usage."

    # Optional: Validate the final configuration
    # Uncomment the following line if wayfire provides a config check command
    # validate_final_config "$out_file"

    # Optional: Backup and merge with existing configuration
    # Uncomment the following lines if merging is desired
    # local existing_config="$HOME/.config/wayfire.ini"
    # local merged_config="$HOME/.config/wayfire.ini.merged"
    # backup_existing_config "$existing_config"
    # merge_configurations "$out_file" "$existing_config" "$merged_config"

    echo_msg "DONE"
}

# Start the main orchestration.
main_final
