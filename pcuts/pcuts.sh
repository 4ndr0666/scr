#!/usr/bin/env bash

# --- // PCUTS.SH // ========
#File: /usr/local/bin/pcuts
#Author: 4ndr0666    
#Edited: 3-21-24

# --- // CONSTANTS_AND_COLORS:
BASEPATH=$(dirname "$0")

if [ -f "${BASEPATH}/colors.sh" ]; then
    . "${BASEPATH}/colors.sh"
else
    heading() {
        echo " ----------------------------------------------------------------------"
        echo "  $2"
        echo " ----------------------------------------------------------------------"
        echo
    }
fi

_sync=false
_search=false
_query=false
_files=false
_remove=false

args=$@


# --- // FUNCTION_DEFINITIONS ========
# --- // HELP_MENU:
help(){

    heading green "HELP" 
    
    echo -e "${grn}pcheat${r}\t\t  # Show all commands"
    echo -e "${grn}pcheat${r}${yel} -s${r}\t  # Sync commands"
    echo -e "${grn}pcheat${r}${yel} -r${r}\t  # Remote search commands"
    echo -e "${grn}pcheat${r}${yel} -q${r}\t  # Local query commands"
    echo -e "${grn}pcheat${r}${yel} -f${r}\t  # File commands"
    echo -e "${grn}pcheat${r}${yel} -x${r}\t  # Remove commands"
    echo -e "${grn}pcheat${r}${yel} -srqfx${r}\t  # Arguments can be combined"
    echo
    exit 1
}

# --- // PACMAN_CMDS_FOR_SEARCHING_REMOTE_PKGS:
search() {

    if [ $_search == false ]; then
    
        heading green "QUERYING"

        echo -e "${grn}pacman${r}${yel} -Ql${r} ${cyn}keyword${r}\t  # Search package databases that contain a keyword"
        echo -e "${grn}pacman${r}${yel} -Ss${r} ${yel}'^${r}${cyn}keyword${r}${yel}'${r}\t  # Search for package name that begins with a keyword"
        echo -e "${grn}pacman${r}${yel} -Si${r} ${cyn}package-name${r}\t  # Show detailed information about a package"

        _search=true
    fi
}

# --- // INSTALLED_PACKGE_INFO:
query() {

    if [ $_query == false ]; then

        heading olive "SEARCH"
        
        echo -e "${grn}pacman${r}${yel} -Qs${r}\t\t  # Show all installed packages"
        echo -e "${grn}pacman${r}${yel} -Qs${r} ${cyn}keyword${r}\t  # Search for installed packages that contain a keyword"
        echo -e "${grn}pacman${r}${yel} -Qi${r} ${cyn}package-name${r}\t  # Show detailed information about an installed package"
        echo -e "${grn}pacman${r}${yel} -Ql${r} ${cyn}package-name${r}\t  # Show all files installed by a package"
        echo -e "${grn}pacman${r}${yel} -Qu${r}\t\t  # List all packages that are out of date"
        echo -e "${grn}pacman${r}${yel} -Qm${r}\t\t  # List all foreign (AUR) packages and include version info"
        echo -e "${grn}pacman${r}${yel} -Qmq${r}\t\t  # List all foreign (AUR) packages - name only"
        echo -e "${grn}pacman${r}${yel} -Qqe ${yel}>${r}${r} ${cyn}pkglist.txt${r}\t  # Create a file with all installed pckages including AUR"
        echo -e "${grn}pacman${r}${yel} -Qq | grep -Ee '-(bzr|cvs|darcs|git|hg|svn)$'${r}\t  # List all dev packages"
        echo -e "${grn}pacman${r}${yel} -Qq | fzf --preview 'pacman -Qil {}' --layout=reverse --bind 'enter:execute(pacman -Qil {} | less)' ${r}\t  # Browse all in GUI"

        _query=true
    fi                
}

# --- // PKG_FILES_INFORMATION:
files() {

    if [ $_files == false ]; then

        heading blue "FILES"

        echo -e "${grn}lsof${r}${yel} +c 0 | grep -w DEL | awk '1 { print $1 ": " $NF }' | sort -u ${r} ${cyn}${r}\t  # These pkgs are using old libraries" 
        echo -e "${grn}pacman${r}${yel} -Fs${r} ${cyn}keyword${r}\t                    # Search onboard pkgfiles by keyword"
        echo -e "${grn}pacman${r}${yel} -Q | grep -i${r} ${cyn}keyword${r}\t            # Search installed pkgs by keyword"
        echo -e "${grn}pacman${r}${yel} -Fl${r} ${cyn}package-name${r}\t                    # Lists all files installed via remote pkg" 
        echo -e "${grn}pacman${r}${yel} -Fo${r} ${cyn}/path/filename${r}\t            # List the remote pkg a file belongs to" 
        echo -e "${grn}pacman${r}${yel} -Q${r}\t                            # List all installed pkgs" 
        echo -e "${grn}paccheck${r}${yel} --md5sum --quiet${r} ${r}\t            # List all files that have changed" 

        _files=true
    fi
}

# --- // SPECIAL_DOWNLOAD_USES:
sync() {

    if [ $_sync == false ]; then
    
        heading purple "SYNC"

        echo -e "${grn}pacman${r}${yel} -S --needed - < ${cyn}pkglist.txt${r}\t  # Install from a list"
        echo -e "${grn}pacman${r}${yel} -Sw${r} ${cyn}package-name${r}\t  # Download a package but do not install it"

        _sync=true
    fi
}

# --- // PKG_REMOVAL_COMMANDS:
remove() {

    if [ $_remove == false ]; then

        heading red "REMOVE"

        echo -e "${grn}pacreport${r}${yel} --unowned-files${r}   ${cyn}${r}\t     # Identify files not owned by any package"
        echo -e "${grn}pacman${r}${yel} -R${r}   ${cyn}package-name${r}\t     # Remove pkg leaving all dependencies" 
        echo -e "${grn}pacman${r}${yel} -Rs${r}  ${cyn}package-name${r}\t     # Remove pkg and dependencies not needed elsewhere" 
        echo -e "${grn}pacman${r}${yel} -Rc${r}  ${cyn}package-name${r}\t     # Remove pkg and its config"
        echo -e "${grn}pacman${r}${yel} -Rsc${r} ${cyn}package-name${r}\t     # Remove pkg, its dependencies and config"
        echo -e "${grn}pacman${r}${yel} -Qtdq | pacman -Rns -${r} ${cyn}${r}\t     # Remove orphans"
        echo -e "${grn}pacman${r}${yel} -Qqd | pacman -Rsu --print - ${r} ${cyn}${r}\t  # Detect more unneeded packages"
        echo -e "${grn}pacman${r}${yel} -D --asdeps $ (pacman -Qqe)${r}\t  # Remove everything but essential packages"
        echo -e "${grn}pacman${r}${yel} -D --asexplicit${r} ${cyn}package-name${r}\t  # Mark as explicitly installed"

        _remove=true
    fi
}
clear

if [ -z "$args" ]; then
    sync
    search
    query
    files
    remove
    echo
    exit 1
fi

args=${args,,}    # lowercase
args=${args// /}  # remove spaces
args=${args//-/}  # remove dashes

if [[ $args =~ [h] ]] ; then
    help
fi

if [[ $args =~ [^srqfx] ]]; then
    help
fi

args=$(echo $args | grep -o .)

for arg in ${args[@]}; do
    case "$arg" in
        s)  sync    ;;
        r)  search  ;;
        q)  query   ;;
        f)  files   ;;
        x)  remove  ;;
        *)  help    ;;
    esac
done
echo
