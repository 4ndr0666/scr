#!/usr/bin/env bash
# shellcheck disable=all
# Author: 4ndr0666
# ============================== // GUI.SH //

## Colors & Icons
CYAN="\033[38;2;21;255;255m"
NC="\033[0m"
INFO="➡️"
ERROR="❌"
SUCCESS="✔️"

prominent() {
	local msg
	msg="$1"
	printf '%b\n' "${BOLD}${GREEN}${msg}${NC}"
	return 0
}

bug() {
	local msg
	msg="$1"
	printf '%b\n' "${BOLD}${RED}${msg}${NC}"
	return 1
}

echo_cyan() {
	local msg
	msg="$1"
	printf '%b\n' "\e[36m${msg}\e[0m"
	return 0
}

# --- // check_and_setup_ssh:
check_and_setup_ssh() {
	local ssh_key
	ssh_key="${HOME}/.ssh/id_ed25519"

	if [[ -f "${ssh_key}" ]]; then
		prominent "SSH key exists at ${ssh_key}."
		return 0
	fi

	prominent "SSH key not found. Generating one..."
	if ! ssh-keygen -t ed25519 -C "01_dolor.loftier@icloud.com" -f "${ssh_key}" -N ''; then
		bug "ssh-keygen failed."
		return 1
	fi

	if ! eval "$(ssh-agent -s)"; then
		bug "Failed to start ssh-agent."
		return 1
	fi

	if ! ssh-add "${ssh_key}"; then
		bug "Failed to add SSH key to agent."
		return 1
	fi

	echo_cyan "Please upload ${ssh_key}.pub to GitHub."
	if ! gh auth login --scopes repo; then
		bug "gh auth login failed."
		return 1
	fi

	if ! gh ssh-key add "${ssh_key}.pub"; then
		bug "Failed to add SSH key to GitHub account."
		return 1
	fi

	prominent "SSH setup complete."
	return 0
}

# --- // list_and_manage_remotes:
list_and_manage_remotes() {
	prominent "Current Git remotes:"
	git remote -v || bug "git remote failed." && return 1

	read -rp "Remove any remote? (y/N): " response
	if [[ ! "${response}" =~ ^[Yy]$ ]]; then
		prominent "No remotes removed."
		return 0
	fi

	local remotes remote_to_remove
	mapfile -t remotes < <(git remote)
	if [[ ${#remotes[@]} -eq 0 ]]; then
		bug "No remotes to remove."
		return 1
	fi

	remote_to_remove=$(printf '%s\n' "${remotes[@]}" | fzf --height=40% --prompt="Select remote to remove: ")
	if [[ -z "${remote_to_remove}" ]]; then
		prominent "No selection made."
		return 0
	fi

	if git remote remove "${remote_to_remove}"; then
		prominent "Removed remote '${remote_to_remove}'."
	else
		bug "Failed to remove '${remote_to_remove}'."
		return 1
	fi

	return 0
}

# --- // switch_to_ssh:
switch_to_ssh() {
	local remote_name old_url user_repo new_url
	remote_name=$(git remote | fzf --height=40% --prompt="Select remote to convert: ")
	if [[ -z "${remote_name}" ]]; then
		bug "No remote selected."
		return 1
	fi

	if ! old_url=$(git remote get-url "${remote_name}"); then
		bug "Failed to get URL for ${remote_name}."
		return 1
	fi

	if [[ "${old_url}" == git@github.com:* ]]; then
		prominent "Already using SSH."
		return 0
	fi

	user_repo=${old_url#*github.com/}
	user_repo=${user_repo%.git}
	new_url="git@github.com:4ndr0666/${user_repo}.git"

	if ! gh repo view "4ndr0666/${user_repo}" &>/dev/null; then
		read -rp "Repo not found on GitHub. Create? (y/N): " yn
		if [[ "${yn}" =~ ^[Yy]$ ]]; then
			if ! gh repo create "4ndr0666/${user_repo}" --private --confirm; then
				bug "Repo creation failed."
				return 1
			fi
			prominent "Created remote repo."
		else
			bug "SSH switch aborted."
			return 1
		fi
	fi

	if git remote set-url "${remote_name}" "${new_url}"; then
		prominent "Set ${remote_name} → ${new_url}"
	else
		bug "Failed to set-url."
		return 1
	fi

	return 0
}

# --- // update_remote_url:
update_remote_url() {
	local repo_base repos repo_name new_url
	repo_base='https://github.com/4ndr0666/'
	mapfile -t repos < <(gh repo list 4ndr0666 -L100 --json name -q '.[].name')
	if [[ ${#repos[@]} -eq 0 ]]; then
		bug "No repos found."
		return 1
	fi

	prominent "Select repo to update:"
	repo_name=$(printf '%s\n' "${repos[@]}" | fzf --height=40% --prompt="Repo: ")
	if [[ -z "${repo_name}" ]]; then
		bug "Abort."
		return 1
	fi

	new_url="${repo_base}${repo_name}.git"
	gh repo view "4ndr0666/${repo_name}" &>/dev/null || {
		read -rp "Create on GitHub? (y/N): " yn
		if [[ "${yn}" =~ ^[Yy]$ ]]; then
			gh repo create "4ndr0666/${repo_name}" --private --confirm || {
				bug "Create failed"
				return 1
			}
		else
			bug "Aborted."
			return 1
		fi
	}

	git remote set-url origin "${new_url}" || {
		bug "set-url failed"
		return 1
	}
	prominent "origin → ${new_url}"
	return 0
}

# --- // fetch_from_remote:
fetch_from_remote() {
	prominent "Fetching origin..."
	git fetch origin || {
		bug "fetch failed"
		return 1
	}
	prominent "Fetch complete."
	return 0
}

# --- // pull_from_remote:
pull_from_remote() {
	local branch
	branch=$(git branch --show-current)
	prominent "Pulling ${branch}..."
	git pull origin "${branch}" || {
		bug "pull failed"
		return 1
	}
	prominent "Pull complete."
	return 0
}

# --- // push_to_remote:
push_to_remote() {
	local branch auto_msg
	branch=$(git branch --show-current)
	if ! git diff-index --quiet HEAD --; then
		prominent "Staging & committing changes..."
		git add -A || {
			bug "git add failed"
			return 1
		}
		auto_msg="Auto-commit: $(date +'%Y-%m-%d_%H:%M:%S')"
		git commit -m "${auto_msg}" || {
			bug "commit failed"
			return 1
		}
		prominent "Committed: ${auto_msg}"
	fi

	prominent "Pushing ${branch}..."
	git push -u origin "${branch}" || {
		bug "push failed"
		return 1
	}
	prominent "Push complete."
	return 0
}

# --- // list_branches:
list_branches() {
	prominent "Branches:"
	git branch --all || {
		bug "git branch failed"
		return 1
	}
	return 0
}

# --- // switch_branch:
switch_branch() {
	local branches branch_name
	mapfile -t branches < <(git branch --all | sed 's|remotes/||g')
	branch_name=$(printf '%s\n' "${branches[@]}" | fzf --height=40% --prompt="Branch: ")
	if [[ -z "${branch_name}" ]]; then
		bug "No branch."
		return 1
	fi

	read -rp "Switch to ${branch_name}? (y/N): " yn
	if [[ ! "${yn}" =~ ^[Yy]$ ]]; then
		prominent "Canceled."
		return 0
	fi

	git checkout "${branch_name}" || {
		bug "checkout failed"
		return 1
	}
	prominent "Switched to ${branch_name}."
	return 0
}

# --- // create_new_branch:
create_new_branch() {
	local new_branch
	read -rp "New branch name: " new_branch
	if [[ -z "${new_branch}" ]]; then
		bug "No name."
		return 1
	fi

	read -rp "Create & switch to ${new_branch}? (y/N): " yn
	if [[ ! "${yn}" =~ ^[Yy]$ ]]; then
		prominent "Canceled."
		return 0
	fi

	git checkout -b "${new_branch}" || {
		bug "create failed"
		return 1
	}
	prominent "Created & switched to ${new_branch}."
	return 0
}

# --- // delete_branch:
delete_branch() {
	local branches del_branch
	mapfile -t branches < <(git branch --all | sed 's|remotes/||g')
	del_branch=$(printf '%s\n' "${branches[@]}" | fzf --height=40% --prompt="Delete: ")
	if [[ -z "${del_branch}" ]]; then
		bug "No branch."
		return 1
	fi

	read -rp "Delete ${del_branch}? (y/N): " yn
	if [[ ! "${yn}" =~ ^[Yy]$ ]]; then
		prominent "Canceled."
		return 0
	fi

	git branch -d "${del_branch}" || {
		bug "delete failed"
		return 1
	}
	prominent "Deleted ${del_branch}."
	return 0
}

# --- // reconnect_old_repo:
reconnect_old_repo() {
	local type reconnect_url repo_name new_url yn
	read -rp "Do you know URL or Name? (url/name): " type

	case "${type,,}" in
	url)
		read -rp "Enter URL: " reconnect_url
		repo_name=$(basename "${reconnect_url}" .git)
		new_url="${reconnect_url}"
		;;
	name)
		read -rp "Enter name: " repo_name
		new_url="git@github.com:4ndr0666/${repo_name}.git"
		;;
	*)
		bug "Invalid."
		return 1
		;;
	esac

	gh repo view "4ndr0666/${repo_name}" &>/dev/null || {
		read -rp "Create on GitHub? (y/N): " yn
		if [[ "${yn}" =~ ^[Yy]$ ]]; then
			gh repo create "4ndr0666/${repo_name}" --private --confirm || {
				bug "create failed"
				return 1
			}
		else
			bug "Abort."
			return 1
		fi
	}

	git remote add origin "${new_url}" || {
		bug "remote add failed"
		return 1
	}
	prominent "Origin set → ${new_url}"
	return 0
}

# --- // manage_stashes:
manage_stashes() {
	echo "1) Stash changes"
	echo "2) List stashes"
	echo "3) Apply latest"
	echo "4) Pop latest"
	echo "5) Clear all"
	echo "6) Show stash"
	echo "7) Apply specific"
	echo "8) Drop specific"
	read -rp "Choice (1-8): " choice

	case "${choice}" in
	1)
		read -rp "Message (optional): " msg
		git stash push -m "${msg}" || bug "stash failed"
		;;
	2) git stash list || bug "list failed" ;;
	3) git stash apply || bug "apply failed" ;;
	4) git stash pop || bug "pop failed" ;;
	5)
		read -rp "Clear all? (y/N): " yn
		[[ "${yn}" =~ ^[Yy]$ ]] && git stash clear || prominent "Canceled"
		;;
	6)
		read -rp "Stash (e.g. stash@{0}): " s
		git stash show -p "${s}" || bug "show failed"
		;;
	7)
		read -rp "Stash to apply: " s
		git stash apply "${s}" || bug "apply failed"
		;;
	8)
		read -rp "Stash to drop: " s
		git stash drop "${s}" || bug "drop failed"
		;;
	*)
		bug "Invalid"
		return 1
		;;
	esac
	return 0
}

# --- // cherry_pick_commits:
cherry_pick_commits() {
	prominent "Fetching all..."
	git fetch --all || {
		bug "fetch failed"
		return 1
	}
	local commit
	commit=$(git log --oneline --graph --all | fzf --height=40% --prompt="Pick commit: " | awk '{print $1}')
	if [[ -z "${commit}" ]]; then
		bug "No commit."
		return 1
	fi
	read -rp "Cherry-pick ${commit}? (y/N): " yn
	if [[ "${yn}" =~ ^[Yy]$ ]]; then
		git cherry-pick "${commit}" || bug "cherry-pick failed"
	else
		prominent "Canceled."
	fi
	return 0
}

# --- // restore_branch:
restore_branch() {
	local commit branch_name yn
	commit=$(git log --oneline --all | fzf --height=40% --prompt="Select commit: " | awk '{print $1}')
	if [[ -z "${commit}" ]]; then
		bug "No commit."
		return 1
	fi
	read -rp "New branch from ${commit}? (y/N): " yn
	if [[ ! "${yn}" =~ ^[Yy]$ ]]; then
		prominent "Canceled."
		return 0
	fi
	branch_name="restore-$(date +%Y%m%d%H%M%S)"
	git checkout -b "${branch_name}" "${commit}" || {
		bug "checkout failed"
		return 1
	}
	prominent "Branch ${branch_name} created."
	read -rp "Merge into main & push? (y/N): " yn
	if [[ "${yn}" =~ ^[Yy]$ ]]; then
		git checkout main || {
			bug "no main"
			return 1
		}
		git merge "${branch_name}" || bug "merge failed"
		git push origin main || bug "push failed"
	fi
	return 0
}

# --- // revert_version:
revert_version() {
	prominent "Recent reflog:"
	git reflog -10
	local entry
	entry=$(git reflog | fzf --height=40% --prompt="Select entry: " | awk '{print $1}')
	if [[ -z "${entry}" ]]; then
		bug "None selected."
		return 1
	fi
	read -rp "Reset hard to ${entry}? (yes/no): " yn
	if [[ "${yn}" == "yes" ]]; then
		git reset --hard "${entry}" || {
			bug "reset failed"
			return 1
		}
		prominent "Reset to ${entry}"
	else
		prominent "Canceled."
	fi
	return 0
}

# --- // view_commit_history:
view_commit_history() {
	prominent "Commit history:"
	git log --oneline --graph --decorate | less
	return 0
}

# --- // rebase_branch:
rebase_branch() {
	local base confirm
	base=$(git branch --all | grep -v HEAD | sed 's|remotes/||g' | sort -u | fzf --height=40% --prompt="Base branch: ")
	if [[ -z "${base}" ]]; then
		bug "None."
		return 1
	fi
	read -rp "Rebase onto ${base}? (y/N): " confirm
	if [[ "${confirm}" =~ ^[Yy]$ ]]; then
		git rebase "${base}" || {
			bug "rebase failed"
			return 1
		}
		prominent "Rebase onto ${base} complete."
	else
		prominent "Canceled."
	fi
	return 0
}

# --- // resolve_merge_conflicts:
resolve_merge_conflicts() {
	local target confirm
	target=$(git branch --all | grep -v HEAD | sed 's|remotes/||g' | sort -u | fzf --height=40% --prompt="Merge branch: ")
	if [[ -z "${target}" ]]; then
		bug "None."
		return 1
	fi
	read -rp "Merge ${target}? (y/N): " confirm
	if [[ "${confirm}" =~ ^[Yy]$ ]]; then
		if git merge "${target}"; then
			prominent "Merged ${target}."
		else
			bug "Merge conflicts."
			read -rp "Auto-resolve? (y/N): " yn
			if [[ "${yn}" =~ ^[Yy]$ ]]; then
				resolve_git_conflicts_automatically
				git merge --continue || {
					bug "merge-continue failed"
					return 1
				}
				prominent "Auto-resolve complete."
			fi
		fi
	else
		prominent "Canceled."
	fi
	return 0
}

# --- // fix_git_repository:
fix_git_repository() {
	local backup_dir hooks_dir fsck_output bad_refs specific_bad_ref line ref_name
	backup_dir="../git_repo_backup_$(date +%Y%m%d_%H%M%S)"
	prominent "Backing up to ${backup_dir}"
	if ! cp -r . "${backup_dir}"; then
		bug "Backup failed."
		return 1
	fi

	hooks_dir=".git/hooks"
	if [[ -d "${hooks_dir}" ]]; then
		prominent "Disabling hooks..."
		while IFS= read -r hook; do
			[[ -x "${hook}" && ! "${hook}" =~ \.sample$ ]] || continue
			mv "${hook}" "${hook}.disabled" || bug "mv failed"
			prominent "Disabled ${hook}"
		done < <(find "${hooks_dir}" -type f)
	fi

	prominent "Running git fsck --full"
	fsck_output=$(git fsck --full 2>&1) || true
	printf '%s\n' "${fsck_output}"

	bad_refs=()
	while IFS= read -r line; do
		if [[ "${line}" =~ ^(error|warning):\ ([^ ]+)\ (.+)$ ]]; then
			ref_name="${BASH_REMATCH[2]}"
			bad_refs+=("${ref_name}")
		fi
	done <<<"${fsck_output}"

	if [[ ${#bad_refs[@]} -gt 0 ]]; then
		prominent "Bad refs found:"
		for ref_name in "${bad_refs[@]}"; do
			prominent "Deleting ${ref_name}"
			git update-ref -d "${ref_name}" || bug "delete-ref failed"
		done
	else
		prominent "No bad refs."
	fi

	specific_bad_ref=$(git show-ref | grep '_zsh_highlight_highlighter_cursor_predicate' || true)
	if [[ -n "${specific_bad_ref}" ]]; then
		ref_name=$(awk '{print $2}' <<<"${specific_bad_ref}")
		prominent "Deleting specific ref ${ref_name}"
		git update-ref -d "${ref_name}" || bug "delete failed"
	fi

	prominent "Expiring reflog"
	git reflog expire --expire=now --all || bug "reflog expire failed"

	prominent "Running git gc --prune=now --aggressive"
	git gc --prune=now --aggressive || {
		bug "gc failed"
		return 1
	}

	prominent "Writing commit graph"
	git commit-graph write --reachable || {
		bug "graph write failed"
		return 1
	}

	prominent "Verifying integrity"
	git fsck --full || {
		bug "fsck failed"
		return 1
	}

	prominent "Git fix process complete."
	return 0
}

# --- // setup_git_hooks:
setup_git_hooks() {
	local GIT_HOOKS_DIR HOOKS_LOG

	GIT_HOOKS_DIR=".git/hooks"
	HOOKS_LOG="${GIT_HOOKS_DIR}/hooks_setup.log"

	if [[ ! -d "${GIT_HOOKS_DIR}" ]]; then
		bug ".git/hooks not found"
		return 1
	fi

	printf 'Git hooks setup started at %s\n' "$(date)" >"${HOOKS_LOG}"

	install_hook() {
		local hook_name="$1" hook_content="$2" hook_path
		hook_path="${GIT_HOOKS_DIR}/${hook_name}"

		if [[ -f "${hook_path}" && ! "${hook_path}" =~ \.sample$ ]]; then
			cp "${hook_path}" "${hook_path}.backup.$(date +%s)"
			printf 'Backed up %s\n' "${hook_name}" >>"${HOOKS_LOG}"
		fi

		printf '%s\n' "${hook_content}" >"${hook_path}"
		chmod +x "${hook_path}"
		printf 'Installed %s\n' "${hook_name}" >>"${HOOKS_LOG}"
	}

	# commit-msg hook
	COMMIT_MSG_HOOK='#!/usr/bin/env bash
set -euo pipefail
msg_file="$1"
if [[ ! -f "${msg_file}" ]]; then
  echo "Missing commit-msg file." >&2
  exit 1
fi
subj=$(head -n1 "${msg_file}")
if (( ${#subj} > 72 )); then
  echo "Subject too long (${#subj} chars)." >&2
  exit 1
fi
if grep -qi placeholder "${msg_file}"; then
  echo "Forbidden word: placeholder" >&2
  exit 1
fi
exit 0
'

	# pre-commit hook
	PRE_COMMIT_HOOK='#!/usr/bin/env bash
set -euo pipefail
max_kb=100000
mapfile -t shs < <(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$" || true)
for f in "${shs[@]}"; do
  [[ -f "${f}" ]] || continue
  kb=$(du -k "${f}" | cut -f1)
  (( kb <= max_kb )) || { echo "Large file ${f} (${kb} KB)" >&2; exit 1; }
done
for f in "${shs[@]}"; do
  shfmt -w "${f}"
  git add "${f}"
done
bash -c "shellcheck ${shs[*]}" || { echo "shellcheck issues" >&2; exit 1; }
exit 0
'

	# pre-push hook
	PRE_PUSH_HOOK='#!/bin/sh
set -euo pipefail
tests="Git/scripts/integration_tests.sh"
if [[ -x "${tests}" ]]; then
  printf "Running tests...\n"
  bash "${tests}"
else
  printf "Tests missing, skipping.\n"
fi
exit 0
'

	# post-commit hook
	POST_COMMIT_HOOK='#!/bin/sh
msg=$(git log -1 --pretty=%B | head -n1)
notify-send "Git" "Committed: ${msg}"
exit 0
'

	install_hook commit-msg "${COMMIT_MSG_HOOK}"
	install_hook pre-commit "${PRE_COMMIT_HOOK}"
	install_hook pre-push "${PRE_PUSH_HOOK}"
	install_hook post-commit "${POST_COMMIT_HOOK}"

	prominent "Git hooks installed."
	return 0
}

# --- // run_integration_tests:
run_integration_tests() {
	local script="Git/scripts/integration_tests.sh"
	if [[ -x "${script}" ]]; then
		prominent "Running integration tests..."
		bash "${script}" || {
			bug "Tests failed"
			return 1
		}
		prominent "Tests passed."
	else
		bug "Test script not found."
	fi
	return 0
}

# --- // resolve_git_conflicts_automatically:
resolve_git_conflicts_automatically() {
	local resolver="Git/scripts/automated_git_conflict_resolver.sh"
	if [[ -x "${resolver}" ]]; then
		prominent "Resolving conflicts..."
		bash "${resolver}" || {
			bug "Resolver failed"
			return 1
		}
		prominent "Conflicts resolved."
	else
		bug "Resolver script missing."
	fi
	return 0
}

# --- // setup_cron_job:
setup_cron_job() {
	local cron_script="Git/scripts/setup_cron_job.sh"
	if [[ -x "${cron_script}" ]]; then
		prominent "Setting cron job..."
		bash "${cron_script}" || {
			bug "Cron setup failed"
			return 1
		}
		prominent "Cron job configured."
	else
		bug "Cron script missing."
	fi
	return 0
}

# --- // setup_dependencies:
setup_dependencies() {
	local deps_script="Git/scripts/setup_dependencies.sh"
	if [[ -x "${deps_script}" ]]; then
		prominent "Installing dependencies..."
		bash "${deps_script}" || {
			bug "Deps setup failed"
			return 1
		}
		prominent "Dependencies installed."
	else
		bug "Deps script missing."
	fi
	return 0
}

# --- // perform_backup:
perform_backup() {
	local backup_script="Git/scripts/backup_new.sh"
	if [[ -x "${backup_script}" ]]; then
		prominent "Performing backup..."
		bash "${backup_script}" || {
			bug "Backup failed"
			return 1
		}
		prominent "Backup done."
	else
		bug "Backup script missing."
	fi
	return 0
}

# ─── GUI LOOP ─────────────────────────────────────────────────────────────────
gui() {
	local choice

	# helper for printing a single menu entry
	menu_item() {
		# $1 = label number (e or digit), $2 = description
		printf "    ${CYAN}%2s)${NC} %-13s" "$1" "$2"
	}

	while true; do
		clear

		# Header
		echo -e "${CYAN}#${NC} === ${CYAN}//${NC} Git User Interface ${CYAN}//${NC}"
        echo
		# Rows of four entries (last row has three)
	    menu_item 1 "Setup SSH"
	    menu_item 2 "List Remotes"
	    menu_item 3 "Update URL"
	    menu_item 4 "HTTPS→SSH"
	    echo
	    menu_item 5 "Fetch"
	    menu_item 6 "Pull"
	    menu_item 7 "Push"
	    menu_item 8 "Branches"
	    echo
	    menu_item 9 "Switch Branch"
	    menu_item 10 "New Branch"
	    menu_item 11 "Delete Branch"
	    menu_item 12 "Reconnect"
	    echo
	    menu_item 13 "Manage Stash"
	    menu_item 14 "Cherry-pick"
	    menu_item 15 "Restore"
	    menu_item 16 "Revert"
	    echo
	    menu_item 17 "History"
	    menu_item 18 "Rebase"
	    menu_item 19 "Merge"
	    menu_item 20 "Backup"
	    echo
	    menu_item 21 "Fix Repo"
	    menu_item 22 "Hooks"
	    menu_item 23 "Tests"
	    menu_item 24 "Auto-Resolve"
	    echo
	    menu_item 25 "Cron"
	    menu_item 26 "Deps"
	    menu_item e "Exit"
	    echo
	    echo
		# Prompt
		printf "%b" "\n"
		read -rp "By your command: " choice
		echo

		case "$choice" in
		1) check_and_setup_ssh ;;
		2) list_and_manage_remotes ;;
		3) update_remote_url ;;
		4) switch_to_ssh ;;
		5) fetch_from_remote ;;
		6) pull_from_remote ;;
		7) push_to_remote ;;
		8) list_branches ;;
		9) switch_branch ;;
		10) create_new_branch ;;
		11) delete_branch ;;
		12) reconnect_old_repo ;;
		13) manage_stashes ;;
		14) cherry_pick_commits ;;
		15) restore_branch ;;
		16) revert_version ;;
		17) view_commit_history ;;
		18) rebase_branch ;;
		19) resolve_merge_conflicts ;;
		20) perform_backup ;;
		21) fix_git_repository ;;
		22) setup_git_hooks ;;
		23) run_integration_tests ;;
		24) resolve_git_conflicts_automatically ;;
		25) setup_cron_job ;;
		26) setup_dependencies ;;
		e | E)
			echo -e "${CYAN}💥 Terminated!${NC}"
			exit 0
			;;
		*)
			echo -e "${ERROR}Invalid choice: '$choice'${NC}"
			sleep 1
			;;
		esac

		echo
		echo -e "${INFO}Press [Enter] to return to menu…${NC}"
		read
	done
}

# Start the interface
gui
