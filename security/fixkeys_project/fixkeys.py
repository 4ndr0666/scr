import os
import shutil
import subprocess
import re

# --- // UTILITY_FUNCTIONS:
def confirm_action(prompt):
    response = input(prompt + " (y/n): ").lower()
    return response == 'y'

# --- // CONFIG:
def switch_pacman_conf(repo_name, config_dir="config"):
    try:
        conf_path = os.path.join(config_dir, f"pacman.conf.{repo_name}")
        if confirm_action(f"Switch to {repo_name} configuration?"):
            shutil.copy(conf_path, "/etc/pacman.conf")
            print(f"Switched to {repo_name} configuration.")
    except FileNotFoundError:
        print(f"Configuration for {repo_name} not found.")
    except Exception as e:
        print(f"Error occurred: {e}")

def reset_to_factory_conf(config_dir="config"):
    try:
        factory_conf = os.path.join(config_dir, "pacman.conf.default")
        if confirm_action("Reset to factory configuration?"):
            shutil.copy(factory_conf, "/etc/pacman.conf")
            print("Reset to factory configuration.")
    except FileNotFoundError:
        print("Factory configuration not found.")
    except Exception as e:
        print(f"Error occurred: {e}")

# --- // KEYRING:
class KeyringManager:
    def run_command(self, command):
        try:
            subprocess.run(command, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Command failed: {e}")

    def add_keyring(self, keyring_name):
        if confirm_action(f"Add keyring: {keyring_name}?"):
            self.run_command(['sudo', 'pacman-key', '--recv-keys', keyring_name])
            print(f"Keyring {keyring_name} added.")

    def remove_keyring(self, keyring_name):
        if confirm_action(f"Remove keyring: {keyring_name}?"):
            self.run_command(['sudo', 'pacman-key', '--delete-keys', keyring_name])
            print(f"Keyring {keyring_name} removed.")

    def update_keyring(self, keyring_name):
        if confirm_action(f"Update keyring: {keyring_name}?"):
            self.run_command(['sudo', 'pacman-key', '--refresh-keys', keyring_name])
            print(f"Keyring {keyring_name} updated.")

# --- // REPO:
class RepoManager:
    def __init__(self, pacman_conf_path="/etc/pacman.conf"):
        self.pacman_conf_path = pacman_conf_path

    def run_command(self, command):
        try:
            subprocess.run(command, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Command failed: {e}")

    def add_repo(self, repo_name, repo_url):
        if confirm_action(f"Add repository: {repo_name}?"):
            with open(self.pacman_conf_path, 'a') as conf_file:
                conf_file.write(f"\n[{repo_name}]\nServer = {repo_url}\n")
            print(f"Repository {repo_name} added.")

    def remove_repo(self, repo_name):
        if confirm_action(f"Remove repository: {repo_name}?"):
            with open(self.pacman_conf_path, 'r+') as conf_file:
                lines = conf_file.readlines()
                conf_file.seek(0)
                repo_pattern = re.compile(r'^\[' + re.escape(repo_name) + r'\]$')
                inside_repo_block = False
                for line in lines:
                    if repo_pattern.match(line.strip()):
                        inside_repo_block = True
                        continue
                    if inside_repo_block and line.strip().startswith('Server'):
                        inside_repo_block = False
                        continue
                    conf_file.write(line)
                conf_file.truncate()
            print(f"Repository {repo_name} removed.")

    def update_repos(self):
        if confirm_action("Update all repositories?"):
            self.run_command(['sudo', 'pacman', '-Syu'])
            print("Repositories updated.")

    def adjust_signature_levels(self, level="Required DatabaseOptional"):
        if confirm_action(f"Adjust signature levels to {level}?"):
            with open(self.pacman_conf_path, 'r+') as conf_file:
                lines = conf_file.readlines()
                conf_file.seek(0)
                for line in lines:
                    if line.strip().startswith('SigLevel'):
                        conf_file.write(f"SigLevel = {level}\n")
                    else:
                        conf_file.write(line)
                conf_file.truncate()
            print(f"Signature levels adjusted to {level}.")

# --- // MENU:
def main_menu():
    repo_manager = RepoManager()
    keyring_manager = KeyringManager()
    options = {
        '1': ("Switch Pacman Configuration", switch_pacman_conf),
        '2': ("Reset to Factory Configuration", reset_to_factory_conf),
        '3': ("Add Keyring", keyring_manager.add_keyring),
        '4': ("Remove Keyring", keyring_manager.remove_keyring),
        '5': ("Update Keyring", keyring_manager.update_keyring),
        '6': ("Add Repository", repo_manager.add_repo),
        '7': ("Remove Repository", repo_manager.remove_repo),
        '8': ("Update Repositories", repo_manager.update_repos),
        '9': ("Adjust Signature Levels", repo_manager.adjust_signature_levels)
    }

    while True:
        print("\n--- Pacman Configuration Manager ---")
        for key, (desc, _) in options.items():
            print(f"{key}. {desc}")
        print("0. Exit")

        choice = input("Select an option: ")
        if choice == '0':
            break
        if choice in options:
            func = options[choice][1]
            if choice in ['6', '7']:
                repo_name = input("Enter repository name: ")
                if choice == '6':
                    repo_url = input("Enter repository URL: ")
                    func(repo_name, repo_url)
                else:
                    func(repo_name)
            elif choice in ['3', '4', '5']:
                keyring_name = input("Enter keyring name: ")
                func(keyring_name)
            else:
                func()

if __name__ == "__main__":
    main_menu()
