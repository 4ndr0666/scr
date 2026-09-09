#!/usr/bin/env bash
# Author: 4ndr0666
set -Eeuo pipefail
#                   #=== 4ndr0pac ===#
# Description: Advanced Arch Linux Package Manager UI (Production Grade).
# -----------------------------------------------------------------------

# --- COLORS + CONSTANTS ---
RED='\e[31m'
CYAN='\e[36m'
BRED='\e[41m'
INV='\e[7m'
BOLD='\e[1m'
RESET='\e[0m'
AUR_Helper=""
argument_flag=()
argument_input=""

# --- AUR HELPER DETECTION ---
detect_aur_helper() {
	if [[ -n "$AUR_Helper" ]]; then return 0; fi
	local helpers=(yay paru pikaur aurman pakku trizen pacaur pamac)
	for h in "${helpers[@]}"; do
		if command -v "$h" &>/dev/null; then
			AUR_Helper="$h"
			return 0
		fi
	done
	AUR_Helper="pacman"
}

# --- UNIFIED AUR/PACMAN EXECUTION HANDLER ---
aur_exec() {
	local cmd=()
	case "$AUR_Helper" in
	paru) cmd=("$AUR_Helper" "${argument_flag[@]}" --sudoloop "$@" --color always) ;;
	pamac)
		if [[ "$1" == "-Syu" ]]; then
			cmd=("$AUR_Helper" "${argument_flag[@]}" update -a)
		else
			cmd=("$AUR_Helper" "${argument_flag[@]}" "$@")
		fi
		;;
	pacman) cmd=(sudo pacman "${argument_flag[@]}" "$@" --color always) ;;
	*) cmd=("$AUR_Helper" "${argument_flag[@]}" "$@" --color always) ;;
	esac
	"${cmd[@]}"
}

# --- SHARED HELPERS ---
_remove_db_lock() {
	local dbpath
	dbpath="$(awk -F '=' '/^DBPath/ {gsub(" ","",$2); print $2}' /etc/pacman.conf || true)"
	dbpath="${dbpath:-/var/lib/pacman/}"
	if [[ -f "${dbpath}db.lck" ]]; then
		echo " removing stale pacman database lock ..."
		sudo unlink "${dbpath}db.lck"
		echo ""
	fi
}

_update_extra_package_managers() {
	if command -v snap &>/dev/null; then
		echo " updating snap packages ..."
		sudo snap refresh
		echo ""
	fi
	if command -v flatpak &>/dev/null; then
		echo " updating flatpak packages ..."
		flatpak update -y
		echo ""
	fi
}

# Bounded connectivity probe — hard 3s timeout, EAFP-justified: prevents pacman
# from serially retrying every broken mirror in the list (the actual expensive
# path) before the user learns the network itself is the problem.
_check_network_connectivity() {
	timeout 3 getent hosts archlinux.org &>/dev/null
}

# --- CORE UI HELPERS ---
4ndr0pac_tty_clean() {
	if [[ "$(tty)" == *"tty"* ]]; then
		clear
	fi
}

func_diff() {
	local file1 file2 half_width cols
	file1="$(echo "$argument_input" | awk '{print $1}')"
	file2="$(echo "$argument_input" | awk '{print $2}')"
	cols=$(tput cols)
	half_width=$(( (cols / 2) - ${#file1} + ${#file2} ))
	half_width=$(( half_width > 1 ? half_width : 1 ))

	echo -n -e "${RED}${BOLD}$file1"
	printf "%*s\n" "$half_width" "$file2"
	tput sgr0
	diff --side-by-side --suppress-common-lines --ignore-all-space \
		--color=always --width="$(tput cols)" "$file1" "$file2"
}

# ==============================================================================
# FUNC_U — Update System
# ==============================================================================
func_u() {
	if ! _check_network_connectivity; then
		echo -e " ${BRED}No network connectivity detected (DNS lookup to archlinux.org timed out).${RESET}"
		echo -e " ${BOLD}Skipping sync to avoid flooding unreachable mirrors. Check your connection and retry.${RESET}"
		return 1
	fi

	local install_successful=false
	if aur_exec -Syu; then
		install_successful=true
	fi
	if [[ "$install_successful" == "false" ]]; then
		if ! sudo pacman -Syu --color always; then
			echo -e " ${BOLD}Updates from system repositories have failed.${RESET}"
			if ! _check_network_connectivity; then
				echo -e " ${BRED}Connectivity was lost during the sync attempt. Not retrying — check your network first.${RESET}"
				return 1
			fi
			echo -e " ${BRED}Network is reachable; failure was mirror-specific. Try updating forcefully? [y/N] ${RESET}"
			read -r -n 1 -e answer
			case "${answer:-n}" in
			y | Y | yes | Yes)
				sudo pacman -Syu --color always --overwrite='*'
				;;
			*)
				echo -e " ${BOLD}Packages have not been updated.${RESET}"
				;;
			esac
		fi
	fi
	_update_extra_package_managers
}

# ==============================================================================
# FUNC_M — Maintain System
# ==============================================================================
func_m() {
	if sudo find /tmp -maxdepth 1 -name '4ndr0pac*' -print -quit 2>/dev/null | grep -q .; then
		echo " deleting 4ndr0pac cache ..."
		sudo find /tmp -maxdepth 1 -name '4ndr0pac*' -exec rm -rf {} +
		echo ""
	fi

	_remove_db_lock

	local cache
	cache="$(awk -F '=' '/^CacheDir/ {gsub(" ","",$2); print $2}' /etc/pacman.conf || true)"
	cache="${cache:-/var/cache/pacman/pkg/}"

	if sudo find "$cache" -type f -iname "*.part" -print -quit 2>/dev/null | grep -q .; then
		echo " deleting partially downloaded packages from cache ..."
		sudo find "$cache" -type f -iname "*.part" -delete
		echo ""
	fi

	if sudo find "$cache" -maxdepth 1 -name 'download-*' -print -quit 2>/dev/null | grep -q .; then
		echo " purging orphaned transient download descriptors from package cache..."
		sudo find "$cache" -maxdepth 1 -name 'download-*' -delete
		echo ""
	fi

	local connection_error=true
	echo " choosing fastest mirror (which can take a while) and updating system ..."

	if command -v pacman-mirrors &>/dev/null; then
		if sudo pacman-mirrors -f 0; then
			sudo pacman -Syyuu --noconfirm
			connection_error=false
		fi
	elif command -v reflector &>/dev/null; then
		if sudo reflector --verbose --protocol https --age 6 --delay 6 --sort rate \
			--connection-timeout 2 --score 30 --fastest 10 --save /etc/pacman.d/mirrorlist; then
			sleep 3 && sudo pacman -Syyuu --noconfirm
			connection_error=false
		fi
	else
		local mirror_server_list
		mirror_server_list="$(curl --silent 'https://archlinux.org/mirrorlist/?country=all&protocol=https&use_mirror_status=on' || true)"
		if [[ -n "$mirror_server_list" ]]; then
			mirror_server_list="$(echo "$mirror_server_list" | sed -e 's/^#Server/Server/' -e '/^#/d')"
			mirror_server_list="$(echo "$mirror_server_list" | sudo rankmirrors -n 10 --max-time 2 --verbose - || true)"
			if [[ -n "$(echo "$mirror_server_list" | awk '/ ... /')" ]]; then
				echo "$mirror_server_list" | sudo tee /etc/pacman.d/mirrorlist
				sudo pacman -Syyuu --noconfirm
				connection_error=false
			fi
		fi
		if [[ "$connection_error" == "true" ]]; then
			echo -e " ${RED}No mirror tool found and curl fallback failed. Skipping mirror sort.${RESET}"
		fi
	fi
	echo ""

	if [[ "$connection_error" == "false" ]]; then
		if command -v flatpak &>/dev/null; then
			echo " repairing flatpak(s) ..."
			sudo flatpak repair
			echo " cleaning up orphaned flatpak(s) ..."
			flatpak uninstall --unused --delete-data -y
			echo ""
		fi
		_update_extra_package_managers
	fi

	echo " searching orphans ..."
	case "$AUR_Helper" in
	yay) yay -Yc ;;
	pamac) pamac remove -o ;;
	paru) paru -c ;;
	*)
		local orphans=()
		mapfile -t orphans < <(pacman -Qqdt 2>/dev/null || true)
		if [[ ${#orphans[@]} -gt 0 ]]; then
			pacman -Qdt --color always
			echo -e " ${BRED}Do you want to remove these orphaned packages? [Y/n] ${RESET}"
			read -r -n 1 -e answer
			case "${answer:-y}" in
			y | Y | yes)
				sudo pacman -Rsn "${orphans[@]}" --color always
				;;
			*)
				echo -e " ${BOLD}Orphaned packages retained.${RESET}"
				;;
			esac
		fi
		;;
	esac
	echo ""

	echo " cleaning pacman package cache ..."
	sudo paccache --verbose --remove --uninstalled --keep 1
	echo ""
	sudo paccache --verbose --remove --keep 3
	echo ""

	case "$AUR_Helper" in
	yay)
		echo " cleaning yay package cache '$HOME/.cache/yay/' ..."
		paccache --verbose --remove --keep 2 --cachedir "$HOME/.cache/yay/" || true
		echo ""
		;;
	pikaur)
		echo " cleaning pikaur package cache '$HOME/.cache/pikaur/pkg/' ..."
		paccache --verbose --remove --keep 2 --cachedir "$HOME/.cache/pikaur/pkg/" || true
		echo ""
		;;
	paru)
		echo " cleaning paru package cache '$HOME/.cache/paru/' ..."
		paccache --verbose --remove --keep 2 --cachedir "$HOME/.cache/paru/" || true
		echo ""
		;;
	pamac)
		echo " cleaning pamac package cache ..."
		pamac clean --keep 2 || true
		echo ""
		;;
	esac

	echo " sudo pacdiff ..."
	if [[ -n "${DIFFPROG:-}" ]]; then
		sudo pacdiff
	else
		sudo DIFFPROG="diff --side-by-side --suppress-common-lines --color=always --width=$(tput cols)" pacdiff
	fi
	echo ""

	echo " checking systemctl ..."
	if [[ "$(LC_ALL=C systemctl is-system-running 2>/dev/null)" != "running" ]]; then
		echo -e " ${BRED}The following systemd service(s) have failed:${RESET}"
		systemctl list-units --state=failed
	fi
	echo ""

	echo " checking symlink(s) ..."
	if sudo find /usr/bin /usr/lib /etc -xtype l -print -quit 2>/dev/null | grep -q .; then
		echo " broken symlink(s) found. Try fixing them manually:"
		sudo find /usr/bin /usr/lib /etc -xtype l
	else
		echo " no broken symlinks found in /usr/bin, /usr/lib, /etc."
	fi
	echo ""

	echo " checking consistency of local repository ..."
	if ! pacman -Dk &>/dev/null; then
		echo -e " ${BRED}The following inconsistencies have been found in your local packages:${RESET}"
		pacman -Dk || true
	fi
	echo ""

	if [[ -n "$AUR_Helper" ]] && [[ "$AUR_Helper" != "pacman" ]]; then
		echo " checking AUR package(s) (which can take a while) ..."
		curl --url 'https://aur.archlinux.org/packages.gz' --create-dirs \
			--output "/tmp/4ndr0pac-aur/packages.gz" &>/dev/null &&
			gunzip -f "/tmp/4ndr0pac-aur/packages.gz" || true
		if [[ -f /tmp/4ndr0pac-aur/packages ]]; then
			local aur_orphans
			aur_orphans="$(comm -23 <(pacman -Qqm | sort) <(sort -u /tmp/4ndr0pac-aur/packages) || true)"
			if [[ -n "$aur_orphans" ]]; then
				echo -e " ${BOLD}The following packages are neither in your repo nor the AUR:${RESET}"
				echo -e " ${BRED}It is recommended to remove these packages carefully:${RESET}"
				echo "$aur_orphans"
				echo ""
			fi
		fi
	fi
	echo ""

	echo " checking for package(s) moved to the AUR ..."
	local moved_pkgs
	moved_pkgs="$(comm -23 <(pacman -Qqm | sort) <(pacman -Qqem | sort) || true)"
	if [[ -n "$moved_pkgs" ]]; then
		echo -e " ${BOLD}The following packages were not explicitly installed and are not in your system repo:${RESET}"
		echo -e " ${BRED}If no important packages depend on them, consider removing them:${RESET}"
		echo "$moved_pkgs"
		echo ""
	fi
	echo ""

	if [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
		echo " cleaning systemd log file(s) ..."
		sudo journalctl --vacuum-size=100M --vacuum-time=30days
	fi
	echo ""

	if command -v fwupdmgr &>/dev/null; then
		echo " checking for firmware update(s) ..."
		fwupdmgr refresh --force || true
		local fw_out
		fw_out="$(LC_ALL=C fwupdmgr get-updates 2>&1 || true)"
		if echo "$fw_out" | grep -qE 'No updatable devices|No updates available|updated successfully'; then
			:
		else
			echo -e " ${BRED}fwupd reports the following:${RESET}"
			echo "$fw_out"
			echo -e " ${BRED}Do you want to execute 'fwupdmgr update'? [y/N] ${RESET}"
			read -r -n 1 -e answer
			case "${answer:-n}" in
			y | Y | yes | Yes)
				sudo fwupdmgr update
				;;
			*)
				echo -e " ${BOLD}'fwupdmgr update' not executed.${RESET}"
				;;
			esac
		fi
		echo ""
	fi
}

# --- ENTRY POINT TRIGGER ---
detect_aur_helper

# ==============================================================================
# FUNC_I — Install Packages (Native)
# ==============================================================================
func_i() {
	echo -e " ${CYAN}Fetching synchronization databases...${RESET}"
	local pkgs=()
	mapfile -t pkgs < <(pacman -Slq | sort -u | fzf \
		--multi \
		--reverse \
		--prompt="[Install Native] > " \
		--preview 'pacman -Si {} | grep -v "^$" || echo "Package not found or requires sync."' \
		--preview-window=right:60%:wrap \
		--bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all')

	if [[ ${#pkgs[@]} -gt 0 ]]; then
		4ndr0pac_tty_clean
		echo -e " ${BOLD}Installing: ${pkgs[*]}${RESET}"
		aur_exec -S "${pkgs[@]}"
	else
		echo -e " ${RED}No packages selected.${RESET}"
	fi
	echo ""
}

# ==============================================================================
# FUNC_A — Search & Install AUR
# ==============================================================================
func_a() {
	echo -e " ${CYAN}Fetching AUR & Repository databases via ${AUR_Helper}...${RESET}"
	local pkgs=()
	mapfile -t pkgs < <("${AUR_Helper}" -Slq 2>/dev/null | sort -u | fzf \
		--multi \
		--reverse \
		--prompt="[Install AUR/Native] > " \
		--preview "${AUR_Helper} -Si {} 2>/dev/null | grep -v '^$' || echo 'Fetching data...'" \
		--preview-window=right:60%:wrap \
		--bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all')

	if [[ ${#pkgs[@]} -gt 0 ]]; then
		4ndr0pac_tty_clean
		echo -e " ${BOLD}Installing: ${pkgs[*]}${RESET}"
		aur_exec -S "${pkgs[@]}"
	else
		echo -e " ${RED}No packages selected.${RESET}"
	fi
	echo ""
}

# ==============================================================================
# FUNC_R — Remove Packages & Dependencies (with full recovery loop)
# ==============================================================================
func_r() {
	echo -e " ${CYAN}Loading installed packages...${RESET}"
	local pkgs=()
	mapfile -t pkgs < <(pacman -Qq | fzf \
		--multi \
		--reverse \
		--prompt="[Remove] > " \
		--preview 'pacman -Qi {}' \
		--preview-window=right:60%:wrap \
		--bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all')

	if [[ ${#pkgs[@]} -eq 0 ]]; then
		echo -e " ${RED}No packages selected.${RESET}"
		echo ""
		return 0
	fi

	4ndr0pac_tty_clean
	echo -e " ${BRED}Removing: ${pkgs[*]}${RESET}"

	if ! sudo pacman -Rns "${pkgs[@]}" --color always; then
		echo ""
		echo -e " ${BOLD}Package removal has failed.${RESET}"
		echo -e " ${BOLD}Choose one of the following options:${RESET}"
		echo ""
		echo -e "${BOLD}    1     Try again (re-select from failed list).${RESET}"
		echo -e "${BOLD}          Read the error message(s) above and deselect dependencies.${RESET}"
		echo ""
		echo -e "${BOLD}${RED}    2     Force remove without checking dependencies (-Rdd).${RESET}"
		echo -e "${BOLD}${RED}          Attention: This can break dependencies.${RESET}"
		echo ""
		echo -e "${BOLD}${RED}    3     Cascade remove — also removes packages that depend on selected (-Rsnc).${RESET}"
		echo -e "${BOLD}${RED}          Attention: This is recursive and can remove many packages.${RESET}"
		echo ""
		echo -e "${BOLD}   ENTER  Exit without removing any packages.${RESET}"
		echo ""
		read -r -n 1 -e answer

		case "${answer:-q}" in
		1)
			local pkg_backup=("${pkgs[@]}")
			while [[ ${#pkg_backup[@]} -gt 0 ]]; do
				local retry_pkgs=()
				mapfile -t retry_pkgs < <(printf '%s\n' "${pkg_backup[@]}" | fzf \
					--multi \
					--reverse \
					--prompt="[Retry Remove] > " \
					--preview 'pacman -Qi {} 2>/dev/null || echo "Not installed."' \
					--preview-window=right:60%:wrap)

				if [[ ${#retry_pkgs[@]} -eq 0 ]]; then
					break
				fi

				if ! sudo pacman -Rns "${retry_pkgs[@]}" --color always; then
					echo ""
					echo -e " ${BRED}Package removal failed again. Press ENTER to retry or Ctrl+C to abort.${RESET}"
					read -r
					pkg_backup=("${retry_pkgs[@]}")
				else
					pkg_backup=()
				fi
			done
			;;
		2) sudo pacman -Rdd "${pkgs[@]}" --color always ;;
		3) sudo pacman -Rsnc "${pkgs[@]}" --color always ;;
		*) echo -e " ${BOLD}Removal of packages has been cancelled.${RESET}" ;;
		esac
	fi
	echo ""
}

# ==============================================================================
# FUNC_L — List Installed Packages & Versions
# ==============================================================================
func_l() {
	echo -e " ${CYAN}Displaying installed packages... (ESC to exit)${RESET}"
	pacman -Q --color always | fzf \
		--ansi \
		--reverse \
		--prompt="[Installed Packages] > " \
		--preview 'pacman -Qi {1}' \
		--preview-window=right:60%:wrap
	echo ""
}

# ==============================================================================
# FUNC_T — Dependency Tree (packages required BY target)
# ==============================================================================
func_t() {
	if ! command -v pactree &>/dev/null; then
		echo -e " ${BRED}Error: 'pactree' is not installed. Please install 'pacman-contrib'.${RESET}"
		return 1
	fi
	local target
	target=$(pacman -Qq | fzf --reverse --prompt="[Dependencies OF] > " --preview 'pacman -Qi {}')
	if [[ -n "$target" ]]; then
		4ndr0pac_tty_clean
		echo -e " ${CYAN}Dependencies required by ${BOLD}$target${RESET}:"
		pactree -c "$target" | less -R
	fi
	echo ""
}

# ==============================================================================
# FUNC_V — Reverse Dependency Tree (packages that depend ON target)
# ==============================================================================
func_v() {
	if ! command -v pactree &>/dev/null; then
		echo -e " ${BRED}Error: 'pactree' is not installed. Please install 'pacman-contrib'.${RESET}"
		return 1
	fi
	local target
	target=$(pacman -Qq | fzf --reverse --prompt="[Packages depending ON] > " --preview 'pacman -Qi {}')
	if [[ -n "$target" ]]; then
		4ndr0pac_tty_clean
		echo -e " ${CYAN}Packages that require ${BOLD}$target${RESET}:"
		pactree -cr "$target" | less -R
	fi
	echo ""
}

# ==============================================================================
# FUNC_B — Roll Back System
# ==============================================================================
func_b() {
	local cache logpath cachePACAUR=""
	local line temp1 temp2 temp3
	local pacui_cache_packages pacui_cache_install pacui_aur_install=""
	local pacui_cache_downgrade pacui_cache_downgrade_counted pacui_tmp_downgrade
	local pacui_install pacui_downgrade
	local pacui_cache_upgrade pacui_cache_upgrade_counted pacui_tmp_upgrade
	local pacui_upgrade

	cache="$(awk -F '=' '/CacheDir/ {gsub(" ","",$2); print $2}' /etc/pacman.conf || true)"
	cache="${cache:-/var/cache/pacman/pkg/}"
	logpath="$(awk -F '=' '/^LogFile/ {gsub(" ","",$2); print $2}' /etc/pacman.conf || true)"
	logpath="${logpath:-/var/log/pacman.log}"

	if [[ "$AUR_Helper" == "pacaur" ]]; then
		cachePACAUR="${AURDEST:-$HOME/.cache/pacaur/}"
	fi

	4ndr0pac_tty_clean

	pacui_cache_packages="$(tail -8000 "$logpath" |
		grep "] installed\|removed\|upgraded\|downgraded" |
		awk -F '[\\[\\]]' '{ print $2 " " $5 }' |
		awk '{ $1=$1 ":"; $2="  " $2; $3="\t\033[1m" $3 " \033[0m"; print }' |
		fzf -i --multi --exact --no-sort --select-1 --ansi \
			--query="$argument_input" --cycle --tac --layout=reverse \
			--bind='pgdn:half-page-down,pgup:half-page-up' \
			--margin=1 --info=inline-right --no-separator \
			--header="Press TAB key to (un)select. ENTER to roll back. ESC to quit." \
			--prompt='Enter string to filter displayed list of recent Pacman changes > ' |
		sed 's/ ([^)]*)//g' |
		awk '{ print $(NF-1) " " $NF }' || true)"

	4ndr0pac_tty_clean
	[[ -z "$pacui_cache_packages" ]] && return 0

	local pkgR_arr=()
	mapfile -t pkgR_arr < <(echo "${pacui_cache_packages}" | awk '/installed/ {print $2}' | sort -u)
	if [[ ${#pkgR_arr[@]} -gt 0 ]]; then
		sudo pacman "${argument_flag[@]}" -R "${pkgR_arr[@]}" --color always
	fi

	pacui_cache_install="$(echo "${pacui_cache_packages}" | awk '/removed/ {print $2}' || true)"
	if [[ -n "$pacui_cache_install" ]]; then
		if [[ "$AUR_Helper" == "pacaur" ]]; then
			pacui_aur_install="$(
				while IFS='' read -r line || [[ -n "$line" ]]; do
					find "$cachePACAUR" -maxdepth 2 -mindepth 2 -type f -printf "%T+\t%p\n" |
						grep -E '\.pkg\.tar\.(zst|xz|gz|bz2)$' | sort -rn | awk '{print $2}' |
						grep "${line}-" | sed -n '1p'
				done < <(echo "${pacui_cache_install}")
			)"
		fi

		pacui_install="$(
			while IFS='' read -r line || [[ -n "$line" ]]; do
				find "$cache" -name "${line}-[0-9a-z.-_]*.pkg.tar.*" | sort -r | sed -n '1p'
			done < <(echo "${pacui_cache_install}")
		)"

		local pkgI_arr=()
		if [[ -n "$pacui_aur_install" ]]; then
			mapfile -t pkgI_arr < <(printf "%s\n%s" "${pacui_install}" "${pacui_aur_install}" | sort -u | grep -v '^$')
		else
			mapfile -t pkgI_arr < <(echo "${pacui_install}" | sort -u | grep -v '^$')
		fi

		if [[ ${#pkgI_arr[@]} -gt 0 ]]; then
			sudo pacman "${argument_flag[@]}" -U "${pkgI_arr[@]}" --color always
		fi
	fi

	pacui_cache_downgrade="$(echo "${pacui_cache_packages}" | awk '/upgraded/ {print $2}' || true)"
	if [[ -n "$pacui_cache_downgrade" ]]; then
		pacui_tmp_downgrade="$(mktemp /tmp/4ndr0pac-tmp-downgrade.XXXXXXXX)"
		trap 'rm -f "${pacui_tmp_downgrade}"' RETURN

		pacui_cache_downgrade_counted="$(echo "${pacui_cache_downgrade}" | sort | uniq -c)"

		pacui_downgrade="$(
			while read -r line && [[ -n "$line" ]]; do
				temp1="$(echo "$line" | awk '{print $1}')"
				temp2="$(echo "$line" | awk '{print $2}')"
				if [[ -n "$temp2" ]]; then
					find "$cache" -name "${temp2}-[0-9a-z.-_]*.pkg.tar.*" | sort -r >"${pacui_tmp_downgrade}"
					if [[ "$AUR_Helper" == "pacaur" ]]; then
						find "$cachePACAUR" -maxdepth 2 -mindepth 2 -type f -printf "%T+\t%p\n" |
							grep -E '\.pkg\.tar\.(zst|xz|gz|bz2)$' | sort -rn | awk '{print $2}' |
							grep "${temp2}-" >>"${pacui_tmp_downgrade}" || true
					fi
					temp3="$((temp1 + 1))p"
					grep "$(pacman -Q "$temp2" | awk '{print $2}')" -A 100 "${pacui_tmp_downgrade}" |
						sed -n "${temp3}" || true
				fi
			done < <(echo "${pacui_cache_downgrade_counted}")
		)"

		rm -f "${pacui_tmp_downgrade}"
		trap - RETURN

		local pkgD_arr=()
		mapfile -t pkgD_arr < <(echo "${pacui_downgrade}" | sort -u | grep -v '^$')
		if [[ ${#pkgD_arr[@]} -gt 0 ]]; then
			sudo pacman "${argument_flag[@]}" -U "${pkgD_arr[@]}" --color always
		fi
	fi

	pacui_cache_upgrade="$(echo "${pacui_cache_packages}" | awk '/downgraded/ {print $2}' || true)"
	if [[ -n "$pacui_cache_upgrade" ]]; then
		pacui_tmp_upgrade="$(mktemp /tmp/4ndr0pac-tmp-upgrade.XXXXXXXX)"
		trap 'rm -f "${pacui_tmp_upgrade}"' RETURN

		pacui_cache_upgrade_counted="$(echo "${pacui_cache_upgrade}" | sort | uniq -c)"

		pacui_upgrade="$(
			while read -r line && [[ -n "$line" ]]; do
				temp1="$(echo "$line" | awk '{print $1}')"
				temp2="$(echo "$line" | awk '{print $2}')"
				if [[ -n "$temp2" ]]; then
					find "$cache" -name "${temp2}-[0-9a-z.-_]*.pkg.tar.*" | sort -r >"${pacui_tmp_upgrade}"
					if [[ "$AUR_Helper" == "pacaur" ]]; then
						find "$cachePACAUR" -maxdepth 2 -mindepth 2 -type f -printf "%T+\t%p\n" |
							grep -E '\.pkg\.tar\.(zst|xz|gz|bz2)$' | sort -rn | awk '{print $2}' |
							grep "${temp2}-" >>"${pacui_tmp_upgrade}" || true
					fi
					temp3="$((temp1 + 1))p"
					grep "$(pacman -Q "$temp2" | awk '{print $2}')" -B 100 "${pacui_tmp_upgrade}" |
						tac | sed -n "${temp3}" || true
				fi
			done < <(echo "${pacui_cache_upgrade_counted}")
		)"

		rm -f "${pacui_tmp_upgrade}"
		trap - RETURN

		local pkgU_arr=()
		mapfile -t pkgU_arr < <(echo "${pacui_upgrade}" | sort -u | grep -v '^$')
		if [[ ${#pkgU_arr[@]} -gt 0 ]]; then
			sudo pacman "${argument_flag[@]}" -U "${pkgU_arr[@]}" --color always
		fi
	fi
}

# ==============================================================================
# FUNC_FIX — Fix Pacman Errors
# ==============================================================================
func_fix() {
	if sudo find /tmp/ -maxdepth 1 -iname '4ndr0pac*' -print -quit 2>/dev/null | grep -q .; then
		echo " deleting 4ndr0pac cache ..."
		sudo find /tmp/ -maxdepth 1 -iname '4ndr0pac*' -exec rm -rf {} +
		echo ""
	fi

	_remove_db_lock

	sudo find /var/lib/pacman/local -name 'desc' -exec grep -l '%INSTALLED_DB%' {} + | xargs sudo sed -i '/^%INSTALLED_DB%$/{N;d;}' 2>/dev/null || true

	echo " fixing mirrors (which can take a while) ..."
	if command -v pacman-mirrors &>/dev/null; then
		sudo pacman-mirrors -f 0 && sudo pacman -Syy
	elif command -v reflector &>/dev/null; then
		sudo reflector --verbose --protocol https,ftps --age 5 --sort rate \
			--save /etc/pacman.d/mirrorlist && sleep 10 && sudo pacman -Syy
	else
		local mirror_server_list
		mirror_server_list="$(curl --silent 'https://archlinux.org/mirrorlist/?country=all&protocol=https&use_mirror_status=on' || true)"
		if [[ -n "$mirror_server_list" ]]; then
			mirror_server_list="$(echo "$mirror_server_list" | sed -e 's/^#Server/Server/' -e '/^#/d')"
			mirror_server_list="$(echo "$mirror_server_list" | sudo rankmirrors -n 10 --max-time 2 --verbose - || true)"
			if [[ -n "$(echo "$mirror_server_list" | awk '/ ... /')" ]]; then
				echo "$mirror_server_list" | sudo tee /etc/pacman.d/mirrorlist
				sudo pacman -Syy
			fi
		fi
	fi
	echo ""

	local server
	server="$(grep "^Server =" -m 1 /etc/pacman.d/mirrorlist | awk -F '=' '{print $2}' | awk -F '$' '{print $1}' | xargs || true)"

	if [[ -z "$server" ]] || ! curl --silent --fail "$server" &>/dev/null; then
		echo ""
		echo -e " ${BRED}Either there is something wrong with your internet connection or with your mirror: $server${RESET}"
		echo -e " ${BRED}Please make sure both are ok and rerun Fix Pacman Errors.${RESET}"
		echo ""
		return 1
	fi

	echo ""
	echo " sudo dirmngr </dev/null ..."
	if ! sudo dirmngr </dev/null 2>/dev/null; then
		echo ""
		echo -e " ${BRED}The following dirmngr errors have occurred:${RESET}"
		sudo dirmngr </dev/null || true
	fi
	echo ""

	echo " cleaning pacman cache ..."
	sudo pacman -Sc --noconfirm
	echo ""

	if [[ -f "$HOME/.gnupg/gpg.conf" ]]; then
		if ! grep -q "/etc/pacman.d/gnupg/pubring.gpg" "$HOME/.gnupg/gpg.conf" &>/dev/null; then
			echo " trusting keys from system developers ..."
			{
				echo "# "
				echo "# Automatically trust all keys in Pacman's keyring:"
				echo "keyring /etc/pacman.d/gnupg/pubring.gpg"
				echo ""
			} >>"$HOME/.gnupg/gpg.conf"
		fi
	fi

	echo " trying to update system conventionally ..."
	if ! sudo pacman -Syuu --noconfirm; then
		echo ""
		echo -e " ${BRED}Conventional update(s) failed. Please read the error message(s) above.${RESET}"
		echo -e " ${BRED}Did the update fail because of key or keyring errors? [y/N]${RESET}"
		read -r -n 1 -e answer

		case "${answer:-n}" in
		y | Y | yes | YES | Yes)
			echo ""
			echo " Lowering pacman securities (in case keyring is broken) ..."
			echo -e " ${BRED}WARNING: Do NOT kill this script (Ctrl+C) until securities are restored.${RESET}"
			sudo cp --preserve=all -f /etc/pacman.conf /etc/pacman.conf.backup &&
				sudo sed -i 's/SigLevel[ ]*=[A-Za-z ]*/SigLevel = Never/' /etc/pacman.conf
			trap "sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf && sudo rm -f /etc/pacman.conf.backup" EXIT
			echo ""

			echo " trying to update system manually without checking keys ..."
			if ! sudo pacman -Syu; then
				echo ""
				echo -e " ${BRED}Update still not successful. 4ndr0pac is unable to fix the system automatically.${RESET}"
				echo -e " ${BRED}Read all error messages carefully and try to fix them yourself.${RESET}"
				echo ""
				echo " raising pacman securities back ..."
				sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf &&
					sudo rm -f /etc/pacman.conf.backup
				trap - EXIT
				echo ""
			else
				echo ""
				echo -e " ${BRED}Update succeeded despite the temporary lack of key checks.${RESET}"
				echo -e " ${BRED}Should 4ndr0pac prevent all future key / keyring errors? [y/N]${RESET}"
				read -r -n 1 -e answer2

				case "${answer2:-n}" in
				y | Y | yes | YES | Yes)
					if [[ -d /etc/pacman.d/gnupg ]]; then
						echo ""
						echo " sudo rm -r /etc/pacman.d/gnupg ..."
						sudo rm -r /etc/pacman.d/gnupg &>/dev/null || true
					fi
					echo ""
					echo " reinstalling gnupg ..."
					sudo pacman -Syu gnupg --noconfirm
					echo ""
					echo " installing all necessary keyrings ..."
					local keyrings=()
					mapfile -t keyrings < <(pacman -Qsq '(-keyring)' | grep -v -i -E '(gnome|python|debian)')
					if [[ ${#keyrings[@]} -gt 0 ]]; then
						sudo pacman -Syu "${keyrings[@]}" --noconfirm
					fi
					echo ""
					echo " raising pacman securities back ..."
					sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf &&
						sudo rm -f /etc/pacman.conf.backup
					trap - EXIT
					echo ""
					echo " initializing and populating keyring ..."
					sudo pacman-key --init && echo "" &&
						sudo pacman-key --populate "${keyrings[@]/#/-keyring}" 2>/dev/null ||
						sudo pacman-key --populate
					echo ""
					echo " updating file database ..."
					sudo pacman -Fyy
					echo ""
					;;
				n | N | no | NO | No)
					echo ""
					echo " do not fix keyring(s) ..."
					echo ""
					echo " raising pacman securities back ..."
					sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf &&
						sudo rm -f /etc/pacman.conf.backup
					trap - EXIT
					echo ""
					echo " updating file database ..."
					sudo pacman -Fyy
					echo ""
					;;
				*)
					echo ""
					echo -e " ${BRED}Answer not recognized. All attempts to fix your system were stopped.${RESET}"
					echo ""
					echo " raising pacman securities back ..."
					sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf &&
						sudo rm -f /etc/pacman.conf.backup
					trap - EXIT
					echo ""
					;;
				esac
			fi
			;;

		n | N | no | NO | No)
			if [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
				echo ""
				echo " sudo systemctl stop ntpd.service ..."
				sudo systemctl stop ntpd.service &>/dev/null || true
				echo ""
				echo " installing ntp ..."
				sudo pacman -S ntp --noconfirm
				echo ""
				echo " setting clock (which can take a while) ..."
				sudo ntpd -qg && sleep 10 && sudo hwclock -w
				echo ""
			fi

			echo " trying to update system manually again ..."
			if ! sudo pacman -Syuu; then
				echo ""
				echo -e " ${BRED}Update still not successful. 4ndr0pac is unable to fix the system automatically.${RESET}"
				echo -e " ${BRED}Read all error messages carefully and try to fix them yourself.${RESET}"
				echo ""
			else
				echo ""
				echo " updating file database ..."
				sudo pacman -Fyy
				echo ""
			fi
			;;

		*)
			echo ""
			echo -e " ${BRED}Answer not recognized. All attempts to fix your system were stopped.${RESET}"
			;;
		esac
	else
		echo ""
		echo " updating file database ..."
		sudo pacman -Fyy
		echo ""
	fi
}

# ==============================================================================
# FUNC_D — Rollback / Downgrade Package
# ==============================================================================
func_d() {
	if ! command -v downgrade &>/dev/null; then
		echo -e " ${BRED}Error: 'downgrade' is not installed. Please install it from the AUR.${RESET}"
		echo -e " ${BOLD}Alternatively, use Roll Back System (option B) for cache-based downgrades.${RESET}"
		return 1
	fi
	local target
	target=$(pacman -Qq | fzf --reverse --prompt="[Downgrade Package] > " --preview 'pacman -Qi {}')
	if [[ -n "$target" ]]; then
		4ndr0pac_tty_clean
		echo -e " ${CYAN}Fetching downgrade history for ${BOLD}$target${RESET}..."
		sudo downgrade "$target"
	fi
	echo ""
}

# ==============================================================================
# FUNC_E — Edit System Configurations
# ==============================================================================
func_e() {
	local editor="${EDITOR:-vim}"
	local configs=()

	[[ -f "$HOME/.config/hypr/hyprland.conf" ]] && configs+=("Hyprland Config          | $HOME/.config/hypr/hyprland.conf")
	[[ -f "$HOME/.config/hypr/hypridle.conf" ]] && configs+=("Hyprland Idle            | $HOME/.config/hypr/hypridle.conf")
	[[ -f "$HOME/.config/hypr/hyprlock.conf" ]] && configs+=("Hyprland Lock            | $HOME/.config/hypr/hyprlock.conf")
	[[ -f "$HOME/.config/hypr/hyprpaper.conf" ]] && configs+=("Hyprland Paper           | $HOME/.config/hypr/hyprpaper.conf")
	[[ -f "$HOME/.config/waybar/config" ]] && configs+=("Waybar Config            | $HOME/.config/waybar/config")
	[[ -f "$HOME/.config/waybar/style.css" ]] && configs+=("Waybar Styles            | $HOME/.config/waybar/style.css")
	[[ -f "$HOME/.config/wofi/config" ]] && configs+=("Wofi Config              | $HOME/.config/wofi/config")
	[[ -f "$HOME/.config/wofi/style.css" ]] && configs+=("Wofi Styles              | $HOME/.config/wofi/style.css")
	[[ -f "$HOME/.config/mako/config" ]] && configs+=("Mako Notifications       | $HOME/.config/mako/config")
	[[ -f "$HOME/.config/dunst/dunstrc" ]] && configs+=("Dunst Notifications      | $HOME/.config/dunst/dunstrc")
	[[ -f "$HOME/.config/weston.ini" ]] && configs+=("Weston Compositor        | $HOME/.config/weston.ini")
	[[ -f "$HOME/.config/kitty/kitty.conf" ]] && configs+=("Kitty Config             | $HOME/.config/kitty/kitty.conf")
	[[ -f "$HOME/.config/alacritty/alacritty.toml" ]] && configs+=("Alacritty Config         | $HOME/.config/alacritty/alacritty.toml")
	[[ -f "$HOME/.config/foot/foot.ini" ]] && configs+=("Foot Terminal            | $HOME/.config/foot/foot.ini")
	[[ -f "$HOME/.config/nvim/init.vim" ]] && configs+=("Neovim Init (vim)        | $HOME/.config/nvim/init.vim")
	[[ -f "$HOME/.config/nvim/init.lua" ]] && configs+=("Neovim Init (lua)        | $HOME/.config/nvim/init.lua")
	[[ -f "$HOME/.zshrc" ]] && configs+=("Zsh Profile              | $HOME/.zshrc")
	[[ -f "$HOME/.bashrc" ]] && configs+=("Bash Profile             | $HOME/.bashrc")
	[[ -f "$HOME/.config/fish/config.fish" ]] && configs+=("Fish Shell               | $HOME/.config/fish/config.fish")
	[[ -f "$HOME/.xinitrc" ]] && configs+=("X Server Startup         | $HOME/.xinitrc")
	[[ -f "$HOME/.Xresources" ]] && configs+=("X Client Applications    | $HOME/.Xresources")
	[[ -f /etc/pacman.conf ]] && configs+=("Pacman Config            | /etc/pacman.conf")
	[[ -f /etc/makepkg.conf ]] && configs+=("Makepkg Config           | /etc/makepkg.conf")
	[[ -f /etc/pacman.d/mirrorlist ]] && configs+=("Pacman Mirrorlist        | /etc/pacman.d/mirrorlist")
	[[ -f /etc/pacman-mirrors.conf ]] && configs+=("Pacman-Mirrors Config    | /etc/pacman-mirrors.conf")
	[[ -f /etc/xdg/reflector/reflector.conf ]] && configs+=("Reflector Config         | /etc/xdg/reflector/reflector.conf")
	[[ -f /etc/pamac.conf ]] && configs+=("Pamac Config             | /etc/pamac.conf")
	[[ -f /etc/pakku.conf ]] && configs+=("Pakku Config             | /etc/pakku.conf")
	[[ -f "$HOME/.config/yay/config.json" ]] && configs+=("Yay Config               | $HOME/.config/yay/config.json")
	[[ -f "$HOME/.config/paru/paru.conf" ]] && configs+=("Paru Config (user)       | $HOME/.config/paru/paru.conf")
	[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/paru/paru.conf" ]] && configs+=("Paru Config (XDG)        | ${XDG_CONFIG_HOME:-$HOME/.config}/paru/paru.conf")
	[[ -f "$HOME/.config/pikaur.conf" ]] && configs+=("Pikaur Config            | $HOME/.config/pikaur.conf")
	[[ -f "$HOME/.config/trizen/trizen.conf" ]] && configs+=("Trizen Config            | $HOME/.config/trizen/trizen.conf")
	[[ -f "${XDG_CONFIG_DIRS:-/etc/xdg}/pacaur/config" ]] && configs+=("Pacaur Config            | ${XDG_CONFIG_DIRS:-/etc/xdg}/pacaur/config")
	[[ -f "$HOME/.config/aurman/aurman_config" ]] && configs+=("Aurman Config (user)     | $HOME/.config/aurman/aurman_config")
	[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/aurman/aurman_config" ]] && configs+=("Aurman Config (XDG)      | ${XDG_CONFIG_HOME:-$HOME/.config}/aurman/aurman_config")
	[[ -f /etc/environment ]] && configs+=("System Environment       | /etc/environment")
	[[ -f /etc/locale.conf ]] && configs+=("Locale Config            | /etc/locale.conf")
	[[ -f /etc/vconsole.conf ]] && configs+=("Virtual Console          | /etc/vconsole.conf")
	[[ -f /etc/hostname ]] && configs+=("Hostname                 | /etc/hostname")
	[[ -f /etc/hosts ]] && configs+=("Local DNS (hosts)        | /etc/hosts")
	[[ -f /etc/resolv.conf ]] && configs+=("DNS Servers              | /etc/resolv.conf")
	[[ -f /etc/fstab ]] && configs+=("Fstab (mount table)      | /etc/fstab")
	[[ -f /etc/crypttab ]] && configs+=("Crypttab (encrypted fs)  | /etc/crypttab")
	[[ -f /etc/sudoers ]] && configs+=("Sudoers                  | /etc/sudoers")
	[[ -f /etc/tlp ]] && configs+=("TLP Power Management     | /etc/tlp")
	[[ -f /etc/default/cpupower ]] && configs+=("CPU Power Management     | /etc/default/cpupower")
	[[ -f /etc/profile.d/freetype2.sh ]] && configs+=("FreeType2 / Infinality   | /etc/profile.d/freetype2.sh")
	[[ -f /etc/pulse/daemon.conf ]] && configs+=("PulseAudio Daemon        | /etc/pulse/daemon.conf")
	[[ -f /etc/pulse/default.pa ]] && configs+=("PulseAudio Modules       | /etc/pulse/default.pa")
	[[ -f /etc/asound.conf ]] && configs+=("ALSA Config              | /etc/asound.conf")
	[[ -f "$HOME/.gnupg/gpg.conf" ]] && configs+=("GnuPG User Settings      | $HOME/.gnupg/gpg.conf")
	[[ -f /etc/sddm.conf ]] && configs+=("SDDM Display Manager     | /etc/sddm.conf")
	[[ -f /etc/lightdm.conf ]] && configs+=("LightDM Display Manager  | /etc/lightdm.conf")
	[[ -f /etc/gdm/custom.conf ]] && configs+=("GDM Display Manager      | /etc/gdm/custom.conf")
	[[ -f /etc/lxdm/lxdm.conf ]] && configs+=("LXDM Display Manager     | /etc/lxdm/lxdm.conf")
	[[ -f /etc/mdm/mdm.conf ]] && configs+=("MDM Display Manager      | /etc/mdm/mdm.conf")
	[[ -f /etc/slim.conf ]] && configs+=("SLiM Display Manager     | /etc/slim.conf")
	[[ -f /etc/entrance/entrance.conf ]] && configs+=("Entrance Display Manager | /etc/entrance/entrance.conf")
	[[ -f /etc/conf.d/xdm ]] && configs+=("XDM Display Manager      | /etc/conf.d/xdm")
	[[ -d /usr/lib/NetworkManager/conf.d ]] && configs+=("NetworkManager Conf.d    | /usr/lib/NetworkManager/conf.d/")
	[[ -f /etc/updatedb.conf ]] && configs+=("Locate Database          | /etc/updatedb.conf")
	[[ -f /etc/systemd/swap.conf ]] && configs+=("Systemd Swap             | /etc/systemd/swap.conf")
	[[ -f /etc/systemd/homed.conf ]] && configs+=("Systemd Homed            | /etc/systemd/homed.conf")
	[[ -f /etc/systemd/logind.conf ]] && configs+=("Systemd Logind           | /etc/systemd/logind.conf")
	[[ -f /etc/systemd/journald.conf ]] && configs+=("Systemd Journald         | /etc/systemd/journald.conf")
	[[ -f /etc/systemd/coredump.conf ]] && configs+=("Systemd Coredump         | /etc/systemd/coredump.conf")
	[[ -f /etc/systemd/networkd.conf ]] && configs+=("Systemd Networkd         | /etc/systemd/networkd.conf")
	[[ -f /etc/systemd/oomd.conf ]] && configs+=("Systemd OOM              | /etc/systemd/oomd.conf")
	[[ -f /etc/systemd/resolved.conf ]] && configs+=("Systemd Resolved         | /etc/systemd/resolved.conf")
	[[ -f /etc/systemd/sleep.conf ]] && configs+=("Systemd Sleep            | /etc/systemd/sleep.conf")
	[[ -f /etc/systemd/system.conf ]] && configs+=("Systemd System           | /etc/systemd/system.conf")
	[[ -f /etc/systemd/timesyncd.conf ]] && configs+=("Systemd Timesyncd        | /etc/systemd/timesyncd.conf")
	[[ -f /etc/systemd/user.conf ]] && configs+=("Systemd User Units       | /etc/systemd/user.conf")
	[[ -d /etc/systemd/user ]] && configs+=("Systemd User Units Dir   | /etc/systemd/user/")
	[[ -d /usr/lib/systemd/system ]] && configs+=("Systemd System Units Dir | /usr/lib/systemd/system/")
	[[ -d /usr/lib/systemd/network ]] && configs+=("Systemd Network Units    | /usr/lib/systemd/network/")
	[[ -d /etc/udev/rules.d ]] && configs+=("Udev Rules               | /etc/udev/rules.d/")
	[[ -d /usr/lib/sysctl.d ]] && configs+=("Sysctl Parameters        | /usr/lib/sysctl.d/")
	[[ -d /etc/modules-load.d ]] && configs+=("Kernel Module Loading    | /etc/modules-load.d/")
	[[ -f /etc/mkinitcpio.conf ]] && configs+=("Mkinitcpio (initramfs)   | /etc/mkinitcpio.conf")
	[[ -f /etc/default/grub ]] && configs+=("GRUB Boot Loader         | /etc/default/grub")
	[[ -f /boot/grub/custom.cfg ]] && configs+=("GRUB Custom Entries      | /boot/grub/custom.cfg")
	[[ -f /boot/loader/loader.conf ]] && configs+=("Systemd-Boot Loader      | /boot/loader/loader.conf")
	[[ -f /etc/sdboot-manage.conf ]] && configs+=("Systemd-Boot Manager     | /etc/sdboot-manage.conf")
	[[ -d /boot/loader/entries ]] && configs+=("Systemd-Boot Entries     | /boot/loader/entries/")
	[[ -f /boot/refind_linux.conf ]] && configs+=("rEFInd Boot Loader       | /boot/refind_linux.conf")
	[[ -f /boot/EFI/refind/refind.conf ]] && configs+=("rEFInd EFI Config        | /boot/EFI/refind/refind.conf")
	[[ -f /boot/EFI/CLOVER/config.plist ]] && configs+=("Clover Boot Loader       | /boot/EFI/CLOVER/config.plist")
	[[ -f /boot/syslinux/syslinux.cfg ]] && configs+=("Syslinux Boot Loader     | /boot/syslinux/syslinux.cfg")
	[[ -d /etc/X11/xorg.conf.d ]] && configs+=("Xorg Config Dir          | /etc/X11/xorg.conf.d/")

	if [[ ${#configs[@]} -eq 0 ]]; then
		echo -e " ${RED}No configuration files found on this system.${RESET}"
		return 0
	fi

	local selection target_path
	selection=$(printf "%s\n" "${configs[@]}" | fzf \
		--reverse \
		--delimiter="|" \
		--with-nth=1 \
		--prompt="[Edit Config] > " \
		--preview 'bat --color=always {2} 2>/dev/null || cat {2} 2>/dev/null || ls {2} 2>/dev/null || echo "File/directory not found."')

	[[ -z "$selection" ]] && return 0
	target_path=$(echo "$selection" | awk -F'|' '{print $2}' | xargs)

	if [[ "$target_path" == */ ]]; then
		local selected_file
		selected_file=$(find "$target_path" -maxdepth 1 -xtype f | sort | fzf \
			--reverse \
			--prompt="[Select File in $(basename "$target_path")] > " \
			--preview 'bat --color=always {} 2>/dev/null || cat {} 2>/dev/null || echo "Read permission denied."')
		[[ -z "$selected_file" ]] && return 0
		target_path="$selected_file"
	fi

	if [[ ! -f "$target_path" && "$target_path" == "$HOME"* ]]; then
		mkdir -p "$(dirname "$target_path")"
		touch "$target_path"
	fi

	if [[ "$target_path" == "/etc/sudoers" ]]; then
		sudo SUDO_EDITOR="${SUDO_EDITOR:-$editor}" visudo
	elif [[ -w "$target_path" ]]; then
		"$editor" "$target_path"
	else
		echo -e " ${CYAN}Root privileges required to edit $target_path${RESET}"
		sudo "$editor" "$target_path"
	fi

	case "$target_path" in
	/etc/default/grub | /boot/grub/custom.cfg)
		echo -e " ${CYAN}Regenerating GRUB config...${RESET}"
		sudo grub-mkconfig -o /boot/grub/grub.cfg
		;;
	/etc/mkinitcpio.conf)
		echo -e " ${BRED}Do you want to regenerate the initramfs and update grub.cfg? [y/N]${RESET}"
		read -r -n 1 -e answer
		case "${answer:-n}" in
		y | Y | yes | YES | Yes)
			sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg
			;;
		*)
			echo -e " ${BOLD}Changes in /etc/mkinitcpio.conf require manual initramfs regeneration.${RESET}"
			;;
		esac
		;;
	/etc/pacman.conf | /etc/pacman.d/mirrorlist)
		sudo pacman "${argument_flag[@]}" -Syyu
		;;
	/etc/pacman-mirrors.conf)
		sudo pacman-mirrors -f 0 && sudo pacman "${argument_flag[@]}" -Syyu
		;;
	/etc/pamac.conf)
		pamac "${argument_flag[@]}" update --force-refresh || true
		;;
	/etc/fstab | /etc/crypttab)
		sudo mount -a || true
		;;
	/boot/loader/*)
		sudo bootctl list || true
		;;
	esac

	if [[ "$target_path" == *"/waybar/"* ]]; then
		killall -SIGUSR2 waybar 2>/dev/null || true
	fi
	if [[ "$target_path" == *"/mako/"* ]]; then
		makoctl reload 2>/dev/null || true
	fi
}

# ==============================================================================
# FUNC_INFO — Detailed Package Information
# ==============================================================================
func_info() {
	local target
	target=$(pacman -Slq | sort -u | fzf --reverse --prompt="[Package Info] > " --preview 'pacman -Si {1}')
	if [[ -n "$target" ]]; then
		4ndr0pac_tty_clean
		if pacman -Qq "$target" &>/dev/null; then
			pacman -Qi "$target" | less
		else
			pacman -Si "$target" | less
		fi
	fi
}

# ==============================================================================
# FUNC_F — Search Files in Packages
# ==============================================================================
func_f() {
	echo -n -e " ${CYAN}Enter filename/path to search (e.g., 'libutil.so'): ${RESET}"
	read -r search_term
	if [[ -n "$search_term" ]]; then
		4ndr0pac_tty_clean
		pacman -Fy "$search_term"
		echo ""
		echo -e " ${BOLD}Press ENTER to return...${RESET}"
		read -r
	fi
}

# ==============================================================================
# FUNC_FO — List Files Owned by Package
# ==============================================================================
func_fo() {
	local target
	target=$(pacman -Qq | fzf --reverse --prompt="[List Files In] > " --preview 'pacman -Qi {1}')
	if [[ -n "$target" ]]; then
		4ndr0pac_tty_clean
		pacman -Ql "$target" | less
	fi
}

# ==============================================================================
# FUNC_LS — List Packages by Size
# ==============================================================================
func_ls() {
	if ! command -v expac &>/dev/null; then
		echo -e " ${BRED}Error: 'expac' is not installed. Please install 'expac'.${RESET}"
		return 1
	fi
	4ndr0pac_tty_clean
	expac -H M -Q '%12m - \e[1m%n\e[0m' | sort -n -r | fzf \
		-i --multi --exact --no-sort --ansi --layout=reverse \
		--bind='pgdn:half-page-down,pgup:half-page-up' \
		--margin=1 --info=inline-right --no-separator \
		--preview-window='right,60%,wrap' \
		--header="Navigate with PageUp/PageDown. ESC to quit." \
		--prompt='Enter string to filter list > ' \
		--preview 'pacman -Qi {4} --color always'
}

# ==============================================================================
# FUNC_UA — Force Update AUR
# ==============================================================================
func_ua() {
	if [[ "$AUR_Helper" == "pacman" ]]; then
		echo -e " ${BRED}No AUR helper has been found. Please install yay, paru, or another AUR helper.${RESET}"
		return 1
	fi
	case "$AUR_Helper" in
	yay) yay "${argument_flag[@]}" -Syu --devel --needed ;;
	pikaur) pikaur "${argument_flag[@]}" -Syu --devel --needed ;;
	aurman) aurman "${argument_flag[@]}" -Syu --devel --needed ;;
	pakku) pakku "${argument_flag[@]}" -Syu --needed ;;
	trizen) trizen "${argument_flag[@]}" -Syu --devel --needed ;;
	paru) paru "${argument_flag[@]}" -Syu --devel --needed --color always ;;
	pacaur) pacaur "${argument_flag[@]}" -Syua --devel --needed --color always ;;
	pamac) pamac "${argument_flag[@]}" update -a --devel ;;
	*)
		echo -e " ${BRED}AUR helper '$AUR_Helper' does not support --devel. Falling back to standard update.${RESET}"
		aur_exec -Syu
		;;
	esac
}

# ==============================================================================
# FUNC_LA — List Installed from AUR
# ==============================================================================
func_la() {
	4ndr0pac_tty_clean
	echo -e " ${CYAN}Listing packages installed from AUR or manually...${RESET}"
	pacman -Qqm | fzf \
		-i --multi --exact --no-sort --layout=reverse \
		--bind='pgdn:half-page-down,pgup:half-page-up' \
		--margin=1 --info=inline-right --no-separator \
		--preview-window='right,60%,wrap' \
		--header="List of manually installed packages. ESC to quit." \
		--prompt='Enter string to filter list > ' \
		--preview 'pacman -Qi {} --color always'
}

# ==============================================================================
# FUNC_CACHYOS — CachyOS Repository & Kernel Manager
# ==============================================================================
func_cachyos() {
	_cachyos_check_repo() {
		sudo grep -qE '\[(cachyos|cachyos-v3|cachyos-core-v3|cachyos-extra-v3|cachyos-testing-v3|cachyos-v4|cachyos-core-v4|cachyos-extra-v4|cachyos-znver4|cachyos-core-znver4|cachyos-extra-znver4)\]' /etc/pacman.conf
		isInstalled=$?
		sudo grep -E '(cachyos|cachyos-v3|cachyos-core-v3|cachyos-extra-v3|cachyos-testing-v3|cachyos-v4|cachyos-core-v4|cachyos-extra-v4|cachyos-znver4|cachyos-core-znver4|cachyos-extra-znver4)' /etc/pacman.conf | grep -v '#\[' | grep -q '\['
		isCommented=$?
	}

	_cachyos_run_script() {
		local action="${1:---add}"
		local tmpdir
		tmpdir="$(mktemp -d /tmp/4ndr0pac-cachyos.XXXXXXXX)"
		trap 'sudo rm -rf "${tmpdir}"' RETURN
		echo -e " ${CYAN}Downloading CachyOS repo installer...${RESET}"
		if ! curl --fail --location https://mirror.cachyos.org/cachyos-repo.tar.xz -o "${tmpdir}/cachyos-repo.tar.xz"; then
			echo -e " ${BRED}Download failed. Check your internet connection.${RESET}"
			return 1
		fi
		echo -e " ${CYAN}Extracting...${RESET}"
		tar -xf "${tmpdir}/cachyos-repo.tar.xz" -C "${tmpdir}"
		echo -e " ${CYAN}Running cachyos-repo.sh ${action}...${RESET}"
		if [[ "$action" == "--remove" ]]; then
			sudo bash "${tmpdir}/cachyos-repo/cachyos-repo.sh" --remove
		else
			sudo bash "${tmpdir}/cachyos-repo/cachyos-repo.sh"
		fi
	}

	_cachyos_setup_repos() {
		_cachyos_check_repo
		if [[ "$isInstalled" -ne 0 ]]; then
			echo -e " ${CYAN}Installing CachyOS repo...${RESET}"
			_cachyos_run_script --add
		else
			echo -e " ${BOLD}CachyOS repo is already installed.${RESET}"
		fi
	}

	_cachyos_set_default_kernel() {
		_cachyos_check_repo
		if [[ "$isInstalled" -ne 0 ]] || [[ "$isCommented" -ne 0 ]]; then
			echo -e " ${CYAN}Installing CachyOS kernels...${RESET}"
			sudo pacman -S --needed --noconfirm linux-cachyos-lts linux-cachyos-lts-headers linux-cachyos linux-cachyos-headers
			if [[ ! -f /etc/default/grub ]]; then
				echo -e " ${BRED}Error: /etc/default/grub not found. Is GRUB installed?${RESET}"
				return 1
			fi
			local oldDefault newDefault escapedOld
			oldDefault="$(grep '^GRUB_DEFAULT=' /etc/default/grub | head -n 1)"
			newDefault='GRUB_DEFAULT="Advanced options for Arch Linux>Arch Linux, with Linux linux-cachyos-lts"'
			escapedOld="$(echo "$oldDefault" | sed 's/[\/&]/\\&/g')"
			sudo sed -i "s/${escapedOld}/${newDefault}/" /etc/default/grub
			echo -e " ${CYAN}Regenerating GRUB config...${RESET}"
			sudo grub-mkconfig -o /boot/grub/grub.cfg
			echo -e " ${BOLD}CachyOS-LTS is now the default kernel. Reboot to activate.${RESET}"
		else
			echo -e " ${BRED}CachyOS repos are not installed. Please install them first (option 1).${RESET}"
		fi
	}

	_cachyos_reset_default_kernel() {
		if [[ ! -f /etc/default/grub ]]; then
			echo -e " ${BRED}Error: /etc/default/grub not found.${RESET}"
			return 1
		fi
		local oldDefault escapedOld
		oldDefault="$(grep '^GRUB_DEFAULT=' /etc/default/grub | head -n 1)"
		if echo "$oldDefault" | grep -q 'linux-cachyos-lts'; then
			escapedOld="$(echo "$oldDefault" | sed 's/[\/&]/\\&/g')"
			sudo sed -i "s/${escapedOld}/GRUB_DEFAULT=0/" /etc/default/grub
			echo -e " ${CYAN}Regenerating GRUB config...${RESET}"
			sudo grub-mkconfig -o /boot/grub/grub.cfg
			echo -e " ${BOLD}Default kernel reset to stock (GRUB_DEFAULT=0). Reboot to activate.${RESET}"
		else
			echo -e " ${BOLD}CachyOS is not currently the default kernel. Nothing to reset.${RESET}"
		fi
	}

	_cachyos_remove_repos() {
		_cachyos_check_repo
		if [[ "$isInstalled" -eq 0 ]]; then
			echo -e " ${CYAN}Removing CachyOS repo...${RESET}"
			_cachyos_run_script --remove
		else
			echo -e " ${BOLD}CachyOS repo is not installed. Nothing to remove.${RESET}"
		fi
	}

	4ndr0pac_tty_clean
	echo -e " ${BOLD}${CYAN}--- CachyOS Repository & Kernel Manager ---${RESET}"
	echo -e "  ${BOLD}1${RESET}) Install CachyOS repos"
	echo -e "  ${BOLD}2${RESET}) Set CachyOS-LTS as default kernel"
	echo -e "  ${BOLD}3${RESET}) Install CachyOS repos AND set CachyOS-LTS as default kernel"
	echo -e "  ${BOLD}4${RESET}) Remove CachyOS repos and reset default kernel to stock"
	echo -e "  ${BOLD}5${RESET}) Reset default kernel to stock only"
	echo -e "  ${BOLD}Q${RESET}) Cancel"
	echo ""
	echo -n -e " ${BOLD}${INV} Choice [1-5/Q]: ${RESET} "
	read -r cachyos_choice

	case "${cachyos_choice:-q}" in
	1) _cachyos_setup_repos ;;
	2) _cachyos_set_default_kernel ;;
	3) _cachyos_setup_repos && _cachyos_set_default_kernel ;;
	4) _cachyos_remove_repos && _cachyos_reset_default_kernel ;;
	5) _cachyos_reset_default_kernel ;;
	q | Q) echo -e " ${BOLD}Cancelled.${RESET}" ;;
	*) echo -e " ${BRED}Invalid choice.${RESET}" ;;
	esac
	echo ""
}

# ==============================================================================
# FUNC_CHAOTIC — Chaotic-AUR Repository Installer
# ==============================================================================
func_chaotic() {
	if grep -q '\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null; then
		echo -e " ${BOLD}Chaotic-AUR repository is already installed.${RESET}"
		return 0
	fi
	echo -e " ${CYAN}Installing Chaotic-AUR repository...${RESET}"
	sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	sudo pacman-key --lsign-key 3056513887B78AEB
	sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
	sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
	printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.conf >/dev/null
	sudo pacman -Syu --noconfirm
	echo -e " ${BOLD}Chaotic-AUR repository installed and enabled.${RESET}"
	echo ""
}

# ==============================================================================
# FUNC_CLEANUP — System Cleanup
# ==============================================================================
func_cleanup() {
	echo -e " ${CYAN}Performing system cleanup...${RESET}\n"
	sudo pacman -Sc --noconfirm

	local orphans=()
	mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
	if [[ ${#orphans[@]} -gt 0 ]]; then
		echo -e " ${BRED}The following orphaned packages will be removed:${RESET}"
		printf '  %s\n' "${orphans[@]}"
		sudo pacman -Rns "${orphans[@]}" --noconfirm || true
	else
		echo " no orphaned packages found."
	fi

	if [[ -d /var/tmp ]]; then sudo find /var/tmp -type f -atime +5 -delete; fi
	if [[ -d /tmp ]]; then sudo find /tmp -type f -atime +5 -delete 2>/dev/null || true; fi
	if [[ -d /var/log ]]; then sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; ; fi

	if [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
		sudo journalctl --vacuum-time=3d
	fi

	echo -n -e " Flush localized user cache files and empty trash? [y/N]: "
	read -r -n 1 -e clean_response
	case "${clean_response:-n}" in
	y | Y)
		if [[ -d "$HOME/.cache" ]]; then find "$HOME/.cache/" -type f -atime +5 -delete 2>/dev/null || true; fi
		if [[ -d "$HOME/.local/share/Trash" ]]; then find "$HOME/.local/share/Trash" -mindepth 1 -delete 2>/dev/null || true; fi
		echo -e "\n ${BOLD}Cache and trash cleanup completed.${RESET}"
		;;
	*) echo -e "\n ${BOLD}Skipping user cache clean operations.${RESET}" ;;
	esac
}

# ==============================================================================
# FUNC_TOPGRADE — Install and Run Topgrade
# ==============================================================================
func_topgrade() {
	if [[ -d "$HOME/.cargo/bin" ]]; then export PATH="$HOME/.cargo/bin:$PATH"; fi
	if ! command -v topgrade &>/dev/null; then
		echo -e " ${CYAN}topgrade not found. Installing via ${AUR_Helper}...${RESET}"
		if [[ "$AUR_Helper" == "pacman" ]]; then
			echo -e " ${BRED}No AUR helper detected. topgrade is an AUR package.${RESET}"
			return 1
		fi
		aur_exec -S --needed --noconfirm topgrade
	fi
	if command -v topgrade &>/dev/null; then
		topgrade
	else
		echo -e " ${BRED}topgrade executable could not be mapped to user PATH environments.${RESET}"
	fi
}

# ==============================================================================
# FUNC_REMOVE_DE — Detect and Uninstall Desktop Environments / Window Managers
# ==============================================================================
func_remove_de() {
	local de_table=("GNOME|gnome-shell" "KDE Plasma|startplasma-x11" "XFCE|xfce4-session" "Cinnamon|cinnamon-session" "MATE|mate-session" "Budgie|budgie-desktop" "LXQt|lxqt-session" "LXDE|lxsession" "i3|i3" "Sway|sway" "DWM|dwm" "Awesome|awesome" "BSPWM|bspwm" "Openbox|openbox" "Fluxbox|fluxbox" "niri|niri" "river|river" "hyde|Hyprland" "miracle-wm|miracle-wm")
	local installed_names=()
	for entry in "${de_table[@]}"; do
		if command -v "${entry##*|}" &>/dev/null; then installed_names+=("${entry%%|*}"); fi
	done

	if [[ ${#installed_names[@]} -eq 0 ]]; then
		echo -e " ${BOLD}No supported desktop environments detected.${RESET}"
		return 0
	fi

	local selected
	selected=$(printf '%s\n' "${installed_names[@]}" | fzf --reverse --prompt="[Select DE/WM to uninstall] > ")
	[[ -z "$selected" ]] && return 0

	local packages="" config_dirs=""
	case "$selected" in
	"GNOME") packages="gnome gnome-extra"; config_dirs="$HOME/.config/gnome-shell $HOME/.local/share/gnome-shell $HOME/.config/dconf" ;;
	"KDE Plasma") packages="plasma kde-applications"; config_dirs="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc $HOME/.config/plasmarc $HOME/.kde" ;;
	"XFCE") packages="xfce4 xfce4-goodies"; config_dirs="$HOME/.config/xfce4 $HOME/.local/share/xfce4" ;;
	"Cinnamon") packages="cinnamon"; config_dirs="$HOME/.cinnamon $HOME/.config/cinnamon" ;;
	"MATE") packages="mate mate-extra"; config_dirs="$HOME/.config/mate $HOME/.local/share/mate" ;;
	*) packages="${selected,,}"; config_dirs="$HOME/.config/${selected,,}" ;;
	esac

	echo -n -e " Purge ${BOLD}$selected${RESET} and configurations permanently? [y/N]: "
	read -r -n 1 -e confirm
	if [[ "$confirm" =~ ^[yY] ]]; then
		# shellcheck disable=SC2086
		sudo pacman -Rns $packages --noconfirm || true
		for dir in $config_dirs; do if [[ -e "$dir" ]]; then rm -rf "$dir"; fi; done
		sudo paccache -rk0 2>/dev/null || true
	fi
}

# ==============================================================================
# FUNC_HELP — Help Documentation
# ==============================================================================
func_help() {
	4ndr0pac_tty_clean
	cat <<'HELPEOF' | less -R
4ndr0pac - GOD MODE MANUAL

CORE COMMANDS:
  1. Update        - Full system sync (Native + AUR + Flatpak + Snap).
  2. Maintain      - Mirror sort, cache clean, orphan removal, consistency, pacdiff.
  3. Install       - Search and install from official repositories.
  4. AUR           - Search and install from the AUR (active helper shown in menu).
  5. Remove        - Recursive removal with retry/force/cascade recovery.
  6. List          - Interactive viewer for installed packages.
  7. Deps (OF)     - Visual tree of what a package requires.
  8. Deps (ON)     - Visual tree of what requires a package.
  9. Edit          - Full system + Wayland/Hyprland configuration manager.
  B. Roll Back     - Reverse installs/upgrades/removals from pacman.log.
  Z. Fix Errors    - Repair mirrors, DB lock, keyring, GPG, and update failures.
  X. By Size       - List installed packages sorted by installation size.
  W. Force AUR     - Force rebuild of all AUR packages including devel (--devel).
  N. List AUR      - Show all manually installed and AUR packages.

ADMIN TOOLS:
  C. CachyOS       - Manage CachyOS repos and set/reset the CachyOS-LTS kernel.
  G. Chaotic AUR   - Install the Chaotic-AUR third-party repository.
  K. Cleanup       - Deep system cleanup: cache, orphans, logs, trash.
  T. Topgrade      - Install and run topgrade (meta-updater for everything).
  Y. Remove DE     - Detect and uninstall a desktop environment or window manager.

EXTRAS:
  P) Package Info  - Detailed info for any repo or installed package.
  F) Find File     - Search which package owns a file.
  O) Files In Pkg  - List all files installed by a package.
  D) Downgrade     - Downgrade a package via 'downgrade' tool.
  H) Help          - This manual.
HELPEOF
}

# ==============================================================================
# FUNC_MENU — Main UI Menu
# ==============================================================================
func_menu() {
	echo -e " ${BOLD}${CYAN}--- 4ndr0pac: ARCH LINUX PACKAGE MANAGER (GOD MODE) [${AUR_Helper}] ---${RESET}"
	echo -e "  ${BOLD}1${RESET}) Update System         ${BOLD}6${RESET}) List Installed"
	echo -e "  ${BOLD}2${RESET}) Maintain System       ${BOLD}7${RESET}) Dependency Tree (OF)"
	echo -e "  ${BOLD}3${RESET}) Install (Native)      ${BOLD}8${RESET}) Dependency Tree (ON)"
	echo -e "  ${BOLD}4${RESET}) Install (AUR)         ${BOLD}9${RESET}) Edit Configurations"
	echo -e "  ${BOLD}5${RESET}) Remove Packages       ${BOLD}0${RESET}) Exit"
	echo -e " ---------------------------------------------------------------"
	echo -e "  ${BOLD}B${RESET}) Roll Back System      ${BOLD}Z${RESET}) Fix Pacman Errors"
	echo -e "  ${BOLD}X${RESET}) Packages by Size      ${BOLD}W${RESET}) Force Update AUR"
	echo -e "  ${BOLD}N${RESET}) List AUR Installed    ${BOLD}D${RESET}) Downgrade Package"
	echo -e " ---------------------------------------------------------------"
	echo -e "  ${BOLD}C${RESET}) CachyOS Repo/Kernel   ${BOLD}G${RESET}) Chaotic AUR"
	echo -e "  ${BOLD}K${RESET}) System Cleanup        ${BOLD}T${RESET}) Topgrade"
	echo -e "  ${BOLD}Y${RESET}) Remove Desktop"
	echo -e " ---------------------------------------------------------------"
	echo -e "  ${BOLD}P${RESET}) Package Info          ${BOLD}F${RESET}) Find File Owner"
	echo -e "  ${BOLD}O${RESET}) Files in Package      ${BOLD}H${RESET}) Manual / Help"
	echo ""
	echo -n -e " ${BOLD}${INV} Selection: ${RESET} "
}

# ==============================================================================
# CLEANUP
# ==============================================================================
4ndr0pac_clean() {
	rm -f /tmp/4ndr0pac_* 2>/dev/null || true
	4ndr0pac_tty_clean
}

# ==============================================================================
# CLI ARGUMENT DISPATCH
# ==============================================================================
if [[ $# -gt 0 ]]; then
	key="${1,,}"
	key="${key##-}"
	key="${key##-}"
	shift
	argument_input="${*:-}"

	case "$key" in
	1 | u | update)         func_u ;;
	2 | m | maintain)       func_m ;;
	3 | i | install)        func_i ;;
	4 | a | aur)            func_a ;;
	5 | r | remove)         func_r ;;
	6 | l | list)           func_l ;;
	7 | t | tree)           func_t ;;
	8 | v | rtree | rev-tree) func_v ;;
	9 | e | edit)           func_e ;;
	b | rollback)           func_b ;;
	z | fix)                func_fix ;;
	x | ls | listsize)      func_ls ;;
	w | ua | force-aur)     func_ua ;;
	n | la | list-aur)      func_la ;;
	d | down | downgrade)   func_d ;;
	p | info)               func_info ;;
	f | find | find-file)   func_f ;;
	o | fo | files-in-pkg)  func_fo ;;
	c | cachyos)            func_cachyos ;;
	g | chaotic)            func_chaotic ;;
	k | cleanup | clean)    func_cleanup ;;
	t | topgrade)           func_topgrade ;;
	y | remove-de | de)     func_remove_de ;;
	h | help)               func_help ;;
	diff)                   func_diff ;;
	flag=*)
		argument_flag=("${key#*=}")
		exec "$0" "$@"
		;;
	*)
		echo -e " ${BRED}Unknown option: $key. Press ENTER to start 4ndr0pac UI.${RESET}"
		read -r
		;;
	esac
	exit $?
fi

# ==============================================================================
# MAIN LOOP — Interactive UI
# ==============================================================================
main_loop() {
	trap 4ndr0pac_clean EXIT
	while true; do
		4ndr0pac_tty_clean
		func_menu
		read -r choice

		case "$choice" in
		1 | u | U) func_u ;;
		2 | m | M) func_m ;;
		3 | i | I) func_i ;;
		4 | a | A) func_a ;;
		5 | r | R) func_r ;;
		6 | l | L) func_l ;;
		7 | t | T) func_t ;;
		8)         func_v ;;
		9 | e | E) func_e ;;
		b | B)     func_b ;;
		z | Z)     func_fix ;;
		x | X)     func_ls ;;
		w | W)     func_ua ;;
		n | N)     func_la ;;
		d | D)     func_d ;;
		p | P)     func_info ;;
		f | F)     func_f ;;
		o | O)     func_fo ;;
		c | C)     func_cachyos ;;
		g | G)     func_chaotic ;;
		k | K)     func_cleanup ;;
		t | T)     func_topgrade ;;
		y | Y)     func_remove_de ;;
		h | H)     func_help ;;
		0 | q | Q) exit 0 ;;
		*)
			echo -e " ${BRED} Invalid Option ${RESET}"
			sleep 1
			;;
		esac

		if [[ "$choice" != "0" && "$choice" != "q" && "$choice" != "Q" ]]; then
			echo -n -e "${CYAN}Task Complete. Press ENTER for Menu...${RESET}"
			read -r
		fi
	done
}

main_loop
