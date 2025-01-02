#!/usr/bin/env python3

import os
import sys
import subprocess
import logging
import shutil
from time import sleep
from halo import Halo

# Setup logging
logging.basicConfig(filename='duplicate_files_management.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# ANSI color codes for output
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BLUE = '\033[94m'
NC = '\033[0m'  # No Color

def print_header():
    """Prints the script header."""
    header = f"{BLUE}Duplicate File Management{NC}"
    print("\n" + "=" * len(header) + "\n" + header + "\n" + "=" * len(header) + "\n")

def is_root():
    """Check if the current user is root."""
    return os.geteuid() == 0

def restart_with_sudo():
    """Attempts to restart the script with sudo if not running as root."""
    if not is_root():
        try:
            print(f"{YELLOW}Restarting script with root privileges...{NC}")
            os.execvp('sudo', ['sudo', 'python3'] + sys.argv)
        except Exception as e:
            print(f"{RED}Failed to restart script with sudo. Error: {e}{NC}")
            sys.exit(1)

def check_jdupes_installed():
    """Checks if jdupes is installed."""
    try:
        subprocess.run(['jdupes', '--version'], check=True, stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print(f"{RED}jdupes is not installed. Please install it before running this script.{NC}")
        sys.exit(1)

def manage_duplicates(duplicate_list):
    """Offers options to manage found duplicates."""
    print(f"{YELLOW}Options for managing duplicates:{NC}")
    print(f"{GREEN}1.{NC} Delete duplicates")
    print(f"{GREEN}2.{NC} Move duplicates to a specific directory")
    print(f"{GREEN}3.{NC} Generate a report and exit")
    choice = input("> ").strip()

    if choice == '1':
        for file in duplicate_list:
            try:
                os.remove(file)
                print(f"{GREEN}Deleted {file}{NC}")
            except Exception as e:
                print(f"{RED}Failed to delete {file}. Error: {e}{NC}")
    elif choice == '2':
        target_directory = input("Enter the target directory for moving duplicates: ").strip()
        if not os.path.exists(target_directory):
            os.makedirs(target_directory)
        for file in duplicate_list:
            try:
                shutil.move(file, target_directory)
                print(f"{GREEN}Moved {file} to {target_directory}{NC}")
            except Exception as e:
                print(f"{RED}Failed to move {file}. Error: {e}{NC}")
    elif choice == '3':
        report_path = "duplicate_report.txt"
        with open(report_path, "w") as report_file:
            for file in duplicate_list:
                report_file.write(file + "\n")
        print(f"{GREEN}Report generated at {report_path}{NC}")
    else:
        print(f"{RED}Invalid choice. Please try again.{NC}")

def find_duplicates(search_directory):
    """Uses jdupes to find and list duplicate files, then offers management options."""
    spinner = Halo(text='Searching for duplicate files...', spinner='dots', color='yellow')
    spinner.start()
    try:
        # Adjusted call to subprocess.run without capture_output to keep the spinner visible.
        result = subprocess.run(['jdupes', '-r', '-o', 'name', search_directory], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        spinner.stop()
        duplicates = result.stdout.strip()
        if duplicates:
            duplicate_list = duplicates.split("\n")
            print(f"{GREEN}Duplicate files found:\n{duplicates}{NC}")
            logging.info(f"Duplicate files found in {search_directory}:\n{duplicates}")
            manage_duplicates(duplicate_list)
        else:
            print(f"{YELLOW}No duplicate files found.{NC}")
    except subprocess.CalledProcessError as e:
        spinner.stop()
        print(f"{RED}Error finding duplicates: {e}{NC}")
        logging.error(f"Error finding duplicates in {search_directory}: {e}")

def show_menu():
    """Displays the menu with options."""
    print_header()
    print(f"{GREEN}1.{NC} Find and manage duplicate files in a directory")
    print(f"{GREEN}2.{NC} Exit")
    print("\nPlease choose an option:")

def handle_menu_option():
    """Handles the user's menu selection."""
    option = input("> ").strip()
    if option == '1':
        search_directory = input("Enter the directory to search for duplicates: ").strip()
        find_duplicates(search_directory)
    elif option == '2':
        print(f"{BLUE}Exiting...{NC}")
        sys.exit(0)
    else:
        print(f"{RED}Invalid option, please try again.{NC}")

def main():
    """Main script execution flow."""
    if not is_root():
        restart_with_sudo()
    check_jdupes_installed()

    while True:
        show_menu()
        handle_menu_option()
        sleep(2)

if __name__ == "__main__":
    main()
