# Git Functions

# Clone repository with smart depth based on repository size
gclone() {
    # Check if a repository URL is provided
    if [[ -z "$1" ]]; then
        echo "Error: No repository URL provided."
        echo "Usage: gclone <repository-url>"
        return 1
    fi

    # Extract the directory name from the repository URL
    repo_name=$(basename "$1" .git)

    # Check if the directory already exists
    if [[ -d "$repo_name" ]]; then
        read -p "Directory '$repo_name' already exists. Do you want to force clone into it? [y/N]: " confirm
        if [[ "$confirm" != [yY] ]]; then
            echo "Clone operation aborted."
            return 1
        else
            echo "Warning: Existing directory will be used."
        fi
    fi

    # Fetch repository size in MB
    temp_dir=$(mktemp -d)
    git clone --depth 1 --filter=blob:none --bare "$1" "$temp_dir" > /dev/null 2>&1
    repo_size=$(du -sm "$temp_dir" | cut -f1)
    rm -rf "$temp_dir"

    # Decide on clone depth based on repository size
    if [[ "$repo_size" -le 25 ]]; then
        echo "Small repository detected ($repo_size MB). Performing a full clone."
        depth_flag=""
    else
        echo "Large repository detected ($repo_size MB). Performing a shallow clone with --depth 5."
        depth_flag="--depth 5"
    fi

    # Clone the repository with appropriate depth
    if git clone $depth_flag "$@"; then
        # Change into the newly cloned directory
        cd "$repo_name" || {
            echo "Error: Failed to change into directory '$repo_name'. Directory may not exist."
            return 1
        }
        echo "Successfully cloned and switched to '$repo_name'."

        # Prompt for fetching more history if it's a shallow clone
        if [[ -n "$depth_flag" ]]; then
            read -p "Would you like to fetch more history (convert to full clone)? [y/N]: " fetch_more
            if [[ "$fetch_more" == [yY] ]]; then
                git fetch --unshallow
                echo "Full history fetched."
            fi
        fi
    else
        echo "Error: Failed to clone the repository."
        return 1
    fi
}

# Push all changes with commit message
gpush() {
    git add .
    git commit -m "$*"
    git pull --rebase
    git push
}

# Auto Git add, commit, and push
gcomp() {
    # Check if there are any changes to commit
    if ! git diff-index --quiet HEAD --; then
        # Gather information about the changes
        added=$(git status --porcelain | grep "^A" | wc -l)
        modified=$(git status --porcelain | grep "^ M" | wc -l)
        deleted=$(git status --porcelain | grep "^D" | wc -l)

        # Generate a commit message based on changes
        commit_message="Auto-commit: ${added} added, ${modified} modified, ${deleted} deleted"

        # Add all changed files to staging
        git add --all

        # Commit the changes with the generated commit message
        if ! git commit -m "$commit_message"; then
            echo "Error: Commit failed. Aborting."
            return 1
        fi

        # Pull the latest changes from the remote repository (with rebase)
        if ! git pull --rebase; then
            echo "Error: Pull failed. Aborting."
            return 1
        fi

        # Push the changes to the remote repository
        if ! git push; then
            echo "Error: Push failed. Aborting."
            return 1
        fi

        echo "Changes committed, pulled, and pushed successfully."
        echo "Commit message: $commit_message"
    else
        echo "No changes detected. Nothing to commit."
    fi
}

# Add SSH key and test connection
gaddssh() {
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/github
    ssh -T git@github.com
}

# Search within git repository
gsearch() {
    if command -v ag &> /dev/null; then
        git exec ag "$1"
    elif command -v rg &> /dev/null; then
        git exec rg "$1"
    else
        git exec grep -r "$1"
    fi
}

# Delete Git cache
grmcache() {
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/git"
    if [[ -d "$cache_dir" ]]; then
        read -p "Are you sure you want to delete Git cache at $cache_dir? [y/N]: " confirm
        if [[ "$confirm" == [yY] ]]; then
            rm -rf "$cache_dir"
            echo "Git cache deleted."
        else
            echo "Git cache deletion aborted."
        fi
    else
        echo "No Git cache found at $cache_dir."
    fi
}

# Change to Git repository root
groot() {
    if git rev-parse --show-toplevel &> /dev/null; then
        cd "$(git rev-parse --show-toplevel)" || {
            echo "Error: Failed to change to Git repository root."
            return 1
        }
        echo "Moved to Git repository root."
    else
        echo "Error: Not inside a Git repository."
        return 1
    fi
}

# Reset git remote to user’s own repository
gremote() {
    # Check if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Not a git repository. Please navigate to a git repository and try again."
        return 1
    fi

    # Prompt for GitHub username (default to 4ndr0666 if not provided)
    read -p "Enter your GitHub username (default: 4ndr0666): " username
    username=${username:-"4ndr0666"}

    # Prompt for repository name
    read -p "Enter the repository name: " repo_name

    local url="git@github.com:${username}/${repo_name}.git"

    # Confirm before removing the current remote origin
    if git remote get-url origin &> /dev/null; then
        read -p "Are you sure you want to remove the current 'origin' remote? [y/N]: " confirm
        if [[ "$confirm" != [yY] ]]; then
            echo "Remote origin removal canceled."
            return 1
        fi
        git remote remove origin
        echo "Old 'origin' remote removed."
    fi

    # Add the new remote
    git remote add origin "$url"
    echo "New 'origin' remote set to $url."

    # Display the remote URLs
    git remote -v
}

# Initialize Git repository and push to remote
ginit() {
    local repo_name commit_msg branch_name

    # Initialize a new git repository
    git init

    # Prompt for GitHub username (default to 4ndr0666)
    read -p "Enter your GitHub username (default: 4ndr0666): " username
    username=${username:-"4ndr0666"}

    # Prompt for the repository name
    read -p "Enter the name of the GitHub repository: " repo_name

    # Add the remote origin for the specified repository
    git remote add origin "git@github.com:${username}/${repo_name}.git"

    # Stage all files
    git add .

    # Prompt for a commit message
    read -r -p "Enter a commit message for the initial commit (default: 'Initial commit'): " commit_msg
    commit_msg=${commit_msg:-"Initial commit"}

    # Commit the changes
    git commit -m "$commit_msg"

    # Prompt for the branch name (default: main)
    read -p "Enter the branch name to push to (default: main): " branch_name
    branch_name=${branch_name:-"main"}

    # Push to the specified branch
    git push -u origin "$branch_name"
}
