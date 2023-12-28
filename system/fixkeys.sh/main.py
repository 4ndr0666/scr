'''
This is the main script to control and fix everything related to repos and keyrings.
'''
from repo_manager import RepoManager
from keyring_manager import KeyringManager
repo_manager = RepoManager()
keyring_manager = KeyringManager()
repo_manager.add_repo("repo_url")
repo_manager.remove_repo("repo_url")
repo_manager.update_repo("repo_url")
repo_manager.adjust_signature_levels()
keyring_manager.add_keyring("keyring_name")
keyring_manager.remove_keyring("keyring_name")
keyring_manager.update_keyring("keyring_name")