#!/bin/bash

# Function to check if a package is installed.
is_installed() {
    pacman -Qi "$1" &> /dev/null || yay -Qs --info "$1" &> /dev/null
}

# Function to install a package from official repos or AUR.
install_package() {
    echo "Installing $1..."

     # Try installing with pacman first.
     sudo pacman -S --noconfirm "$1" &>/dev/null

      # If installation fails (package not found in repos), try with yay.
      if [ $? != 0 ]; then

         # Check whether the given pkg exists on aur before trying to install using 'yay'.
         curl https://aur.archlinux.org/cgit/aur.git/snapshot/"$dep".tar.gz > "/tmp/$dep.tar.gz" 2>/dev/null

         if [ $? == 0 ]; then
            yay -S --noconfirm "$1"
         else
            echo "Package $dep does not exist in the repositories or AUR. Skipping..."
        fi

     fi

    echo "Installed."
}

check_and_install_deps_system_wide(){

   all_packages=$(pacman -Qq)

   for pkg in $all_packages; do

       deps=$(pactree -u "${pkg}")

       for dep in ${deps}; do

           if ! is_installed "${dep}"; then

               install_package "${dep}"

           else

              echo "${dep} is already installed."

          fi

        done

    done

echo "All dependencies are satisfied."

}

check_and_install_deps_system_wide
