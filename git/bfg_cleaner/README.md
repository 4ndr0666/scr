## 🚀 **Automating the Cleaning Process with a Script**

To streamline the process of removing large files from your Git history, you can use the following **Bash script**. This script automates cloning, running BFG, cleaning, and pushing the cleaned history.

### **Script: `clean_git_history.sh`**

```bash
#!/bin/bash

# Description:
# This script automates the process of removing a specified large file from a Git repository's history using BFG Repo-Cleaner.
# It creates a bare repository, runs BFG, cleans the repository, and force pushes the changes.

# Usage:
# ./clean_git_history.sh /path/to/bare-repo.git filename_to_remove

# Example:
# ./clean_git_history.sh /Nas/Build/git/syncing/scr.git permissions_manifest.acl

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /path/to/bare-repo.git filename_to_remove"
    exit 1
fi

BARE_REPO="$1"
FILE_TO_REMOVE="$2"

# Check if BFG is installed
if ! command -v java &> /dev/null; then
    echo "Java is not installed. Please install Java to use BFG Repo-Cleaner."
    exit 1
fi

if [ ! -f ~/bin/bfg.jar ]; then
    echo "BFG Repo-Cleaner not found at ~/bin/bfg.jar. Please download it first."
    exit 1
fi

# Check if the bare repository exists
if [ ! -d "$BARE_REPO" ]; then
    echo "Bare repository '$BARE_REPO' does not exist."
    exit 1
fi

# Create a temporary mirror clone
TEMP_DIR=$(mktemp -d)
echo "Cloning the bare repository to temporary directory..."
git clone --mirror "$BARE_REPO" "$TEMP_DIR"

# Run BFG to remove the specified file
echo "Running BFG to delete '$FILE_TO_REMOVE'..."
java -jar ~/bin/bfg.jar --delete-files "$FILE_TO_REMOVE" "$TEMP_DIR"

# Navigate to the temporary clone
cd "$TEMP_DIR" || exit

# Perform garbage collection
echo "Performing garbage collection..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push the cleaned history back to the bare repository
echo "Force pushing the cleaned history back to '$BARE_REPO'..."
git push --force --mirror "$BARE_REPO"

# Cleanup
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "Cleaning process completed successfully."

exit 0
```

### **How to Use the Script:**

1. **Save the Script:**

   Save the above script as `clean_git_history.sh` in a directory of your choice, for example, `~/scripts/`.

   ```bash
   nano ~/scripts/clean_git_history.sh
   ```

   *(Paste the script content and save.)*

2. **Make the Script Executable:**

   ```bash
   chmod +x ~/scripts/clean_git_history.sh
   ```

3. **Run the Script:**
   
   Provide the path to your bare repository and the filename you want to remove.

   ```bash
   ~/scripts/clean_git_history.sh /Nas/Build/git/syncing/scr.git permissions_manifest.acl
   ```

   **Script Flow:**
   - **Clones** the bare repository to a temporary directory.
   - **Runs BFG Repo-Cleaner** to remove the specified file.
   - **Performs Git garbage collection** to clean up.
   - **Force pushes** the cleaned history back to the bare repository.
   - **Cleans up** the temporary directory.

4. **Post-Script Steps:**
   
   After running the script, **reset your local working repository** to align with the cleaned remote.

   ```bash
   # Navigate to your local repository
   cd /Nas/Build/git/syncing/scr/

   # Fetch the latest changes
   git fetch origin

   # Reset your local main branch to match the remote
   git reset --hard origin/main
   ```

5. **Verify the Cleanup:**
   
   Ensure the large file has been removed from history.

   ```bash
   git log --stat | grep permissions_manifest.acl
   ```

   **Expected Output:** No results, indicating successful removal.

6. **(Optional) Push to GitHub:**
   
   If you maintain a GitHub remote and wish to push the cleaned history.

   ```bash
   # Add GitHub as a remote if not already added
   git remote add github git@github.com:4ndr0666/scr.git

   # Push the cleaned history to GitHub
   command git push --mirror github
   ```

   **Note:** Ensure that the GitHub repository is **bare** to prevent push conflicts.
