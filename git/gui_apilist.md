### API List and Description

| Function                | Description                                                                                      |
|-------------------------|--------------------------------------------------------------------------------------------------|
| `check_and_setup_ssh`   | Checks for an existing SSH key, generates one if not found, and uploads it to GitHub.            |
| `list_and_manage_remotes`| Lists current Git remotes and offers the option to remove any.                                   |
| `switch_to_ssh`         | Converts remote URLs from HTTPS to SSH for selected Git remotes.                                 |
| `update_remote_url`     | Updates the URL of the origin remote to a new GitHub repository URL.                             |
| `fetch_from_remote`     | Fetches updates from the remote repository.                                                      |
| `pull_from_remote`      | Pulls updates from the remote repository for the current branch.                                 |
| `push_to_remote`        | Pushes the current branch to the remote repository and sets the upstream reference.              |
| `list_branches`         | Lists all local branches in the Git repository.                                                  |
| `switch_branch`         | Switches to a different branch specified by the user.                                            |
| `create_new_branch`     | Creates a new branch with a user-specified name and checks it out.                               |
| `delete_branch`         | Deletes a user-specified branch.                                                                 |
| `reconnect_old_repo`    | Adds a new origin remote with a user-specified URL or repository name.                           |
| `manage_stashes`        | Offers options to stash changes, list stashes, apply, pop, or clear stashes.                     |
| `merge_branches`        | Merges a specified branch into the current branch.                                               |
| `view_commit_history`   | Displays the commit history of the current branch with a graphical representation.              |
| `rebase_branch`         | Rebases the current branch onto a user-specified branch.                                         |
| `resolve_merge_conflicts`| Attempts to start a merge and advises on resolving merge conflicts manually if they occur.       |
| `cherry_pick_commits`   | Cherry-picks a specified commit onto the current branch. Also presents available options.       |
| `restore_branch`        | Restores a branch from its commit history using an external Python script.                       |
| `revert_to_previous_version`| Reverts the repository to a specific state based on a reflog entry specified by the user.      |
| `gui`                   | Main function presenting a menu for the user to choose from the above functionalities.          |
