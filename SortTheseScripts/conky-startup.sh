#!/bin/bash

# Create a new directory for the conky configuration if it doesn't already exist
mkdir -p ~/.config/conky

# Create a conky.conf file with the given configuration
cat > ~/.config/conky/conky.conf << EOL
conky.config = {
  alignment = 'top_right',
  gap_x = 20,
  gap_y = 20,
  minimum_width = 200,
  maximum_width = 300,

  default_color = 'white',
  default_outline_color = 'black',
  default_shade_color = 'black',
  border_width = 1,
  border_inner_margin = 10,
  border_outer_margin = 0,
  draw_borders = true,
  draw_outline = false,
  draw_shades = false,
  font = 'DejaVu Sans Mono:size=10',
  override_utf8_locale = true,
  own_window = true,
  own_window_type = 'normal',
  own_window_transparent = true,
  own_window_argb_visual = true,
  own_window_argb_value = 128,
  own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager'
}

conky.text = [[
\${execi 1 cat ~/.config/conky/keybindings.txt}
]]
EOL

# Download the conky_colors script to the new directory
curl -sSL -o ~/.config/conky/conky_colors.sh https://raw.githubusercontent.com/novaspirit/rpi_conky/master/conky_colors.sh

# Make the conky_colors script executable
chmod +x ~/.config/conky/conky_colors.sh

# Check if sxhkdrc file exists
if [[ -f ~/.config/bspwm/sxhkdrc ]]; then
  # Get the keybindings from the sxhkd configuration file
  keybindings=$(grep -E '^[a-z]+[[:space:]]+\+[[:space:]]+.+' ~/.config/bspwm/sxhkdrc)

  # Format the keybindings as a list
  list=$(echo "$keybindings" | sed -E 's/([a-z]+)\s+\+\s+(.+)/\1 + \2\n/g')

  # Output the formatted text to a file
  echo -e "Keybindings:\n$list" > ~/.config/conky/keybindings.txt
else
  echo "Error: sxhkdrc file not found. Please make sure it's in the correct location." >&2
  exit 1
fi

# Start conky with the new configuration and keybindings
conky -c ~/.config/conky/conky.conf
