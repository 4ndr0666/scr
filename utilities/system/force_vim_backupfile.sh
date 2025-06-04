#!/bin/bash
# shellcheck disable=all

# Define the Lua script content
LUA_CONFIG=$(cat << 'EOF'
-- Ensure backup is enabled
vim.o.backup = true

-- Set the backup directory
local backup_dir = vim.fn.expand("~/.config/nvim/backup")
vim.o.backupdir = backup_dir

-- Ensure the backup directory exists
if vim.fn.isdirectory(backup_dir) == 0 then
    vim.fn.mkdir(backup_dir, "p")
end

-- Do not skip any files for backup
vim.o.backupskip = ""

-- Ensure write backup is enabled
vim.o.writebackup = true
EOF
)

# Create the necessary directories
mkdir -p ~/.config/nvim/lua

# --- // Write the lua script to the appropriate file
echo "$LUA_CONFIG" > ~/.config/nvim/lua/forcevimbackup.lua

# Check if the Lua script is sourced in init.vim or init.lua
if [[ -f ~/.config/nvim/init.vim ]]; then
    if ! grep -q "lua require'forcevimbackup'" ~/.config/nvim/init.vim; then
        echo "lua require'forcevimbackup'" >> ~/.config/nvim/init.vim
    fi
elif [[ -f ~/.config/nvim/init.lua ]]; then
    if ! grep -q "require'forcevimbackup'" ~/.config/nvim/init.lua; then
        echo "require'forcevimbackup'" >> ~/.config/nvim/init.lua
    fi
else
    # If neither init.vim nor init.lua exists, create init.lua and source the Lua script
    echo "require'forcevimbackup'" > ~/.config/nvim/init.lua
fi

echo "Setup completed. Restart Neovim to apply the changes."
