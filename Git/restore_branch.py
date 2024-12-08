import subprocess
import sys

def get_commit_history():
    """Retrieve and display the commit history."""
    proc = subprocess.Popen(['git', 'log', '--oneline'], stdout=subprocess.PIPE)
    output, _ = proc.communicate()
    commits = output.decode().splitlines()
    for i, commit in enumerate(commits):
        print(f"{i + 1}: {commit}")
    return commits

def select_commit(commits):
    """Allow user to select a commit."""
    while True:
        try:
            choice = int(input("Select a commit by number: ")) - 1
            if 0 <= choice < len(commits):
                return commits[choice].split()[0]
            else:
                print("Invalid selection. Please try again.")
        except ValueError:
            print("Invalid input. Please enter a number.")

def checkout_commit(commit_hash):
    """Checkout to a new branch based on the selected commit."""
    branch_name = "restore-branch"
    subprocess.call(['git', 'checkout', commit_hash])
    subprocess.call(['git', 'checkout', '-b', branch_name])
    return branch_name

def merge_and_push(branch_name, main_branch):
    """Merge changes into the main branch and push to remote repository."""
    subprocess.call(['git', 'checkout', main_branch])
    subprocess.call(['git', 'merge', branch_name])
    subprocess.call(['git', 'push', 'origin', main_branch])

def main():
    print("Retrieving commit history...")
    commits = get_commit_history()
    selected_commit = select_commit(commits)
    branch_name = checkout_commit(selected_commit)
    print(f"Checked out to new branch '{branch_name}' based on commit {selected_commit}.")

    # Ask user if they want to merge and push changes
    merge_choice = input(f"Do you want to merge changes into your main branch and push to remote? (y/n): ").lower()
    if merge_choice == 'y':
        main_branch = input("Enter the name of your main branch (e.g., 'main' or 'master'): ")
        merge_and_push(branch_name, main_branch)
        print(f"Changes merged into {main_branch} and pushed to remote repository.")
    else:
        print("Skipping merge and push to remote repository.")

if __name__ == "__main__":
    main()
