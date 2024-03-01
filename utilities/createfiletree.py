import os
import re
import string
from datetime import datetime, timedelta
import subprocess
import logging

# Define colors
RED = '\033[1;31m'
GRE = '\033[1;32m'
CYAN = '\033[1;36m'
c0 = '\033[0m'

def run_command(command):
    """
    Run a command and capture its output.

    Args:
        command (list): List containing the command and its arguments.

    Returns:
        CompletedProcess: CompletedProcess object with the result of the command.
    """
    try:
        return subprocess.run(command, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command '{e.cmd}' failed with error: {e.stderr.strip()}")
        raise

def validate_input(input_string, pattern, input_type="path"):
    """
    Validate user input based on a specified pattern.

    Args:
        input_string (str): The input string to be validated.
        pattern (str): Regular expression pattern for validation.
        input_type (str): Type of input (e.g., "path" or "name").

    Returns:
        bool: True if the input matches the pattern, False otherwise.
    """
    if not re.match(pattern, input_string):
        print(f"{CYAN}⚠️ Invalid {input_type}. Please try again.{c0}")
        return False
    return True

def get_valid_input(prompt, pattern, input_type="path"):
    """
    Prompt the user for valid input based on a specified pattern.

    Args:
        prompt (str): The prompt message to display to the user.
        pattern (str): Regular expression pattern for validation.
        input_type (str): Type of input (e.g., "path" or "name").

    Returns:
        str: Valid user input.
    """
    while True:
        user_input = input(f"{CYAN}{prompt}{c0}").strip()  # Trim leading/trailing spaces
        if validate_input(user_input, pattern, input_type):
            return user_input

def create_directory(path):
    """
    Create a directory at the specified path.

    Args:
        path (str): The path where the directory should be created.

    Returns:
        bool: True if the directory creation is successful, False otherwise.
    """
    try:
        os.makedirs(path, exist_ok=True)
        print(f"{GRE}📁 Directory created: {path}{c0}")
        return True
    except OSError:
        print(f"{RED}❌ Error: Creating directory {path} failed.{c0}")
        return False

def create_datetime_structure(base_path, years=2):
    """
    Create a directory structure based on date and time.

    Args:
        base_path (str): The base path where the structure should be created.
        years (int): Number of years to include in the structure.

    Returns:
        None
    """
    for year in range(datetime.now().year, datetime.now().year + years):
        for month in range(1, 13):
            for day in range(1, (datetime(year, month + 1, 1) - timedelta(days=1)).day + 1):
                path = os.path.join(base_path, f"{year}", f"{month:02d}", f"{day:02d}")
                create_directory(path)

def create_alphabetical_structure(base_path):
    """
    Create an alphabetical directory structure.

    Args:
        base_path (str): The base path where the structure should be created.

    Returns:
        None
    """
    for letter in string.ascii_uppercase:
        path = os.path.join(base_path, letter)
        create_directory(path)

def create_numerical_structure(base_path):
    """
    Create a numerical directory structure.

    Args:
        base_path (str): The base path where the structure should be created.

    Returns:
        None
    """
    for num in range(1, 101):
        path = os.path.join(base_path, str(num))
        create_directory(path)

def create_custom_tag_structure(base_path):
    """
    Create a custom tag-based directory structure.

    Args:
        base_path (str): The base path where the structure should be created.

    Returns:
        None
    """
    tags = {
        'todo': ['urgent', 'medium', 'low'],
        'status': ['in-progress', 'completed', 'on-hold'],
        'priority': ['high', 'normal', 'low']
    }
    for category, sub_tags in tags.items():
        for sub_tag in sub_tags:
            path = os.path.join(base_path, category, sub_tag)
            create_directory(path)

def create_project_structure():
    """
    Create a project directory structure with subfolders (docs, src, test).

    Args:
        None

    Returns:
        None
    """
    parent_directory = get_valid_input("Enter the parent directory (e.g., ~/Build/projects): ",
                                        r'^[\\\/\w\s-]+$', "path")
    project_name = get_valid_input("Enter the project name: ", r'^[\w\s-]+$', "name")
    project_directory = os.path.join(parent_directory, project_name)
    if create_directory(project_directory):
        subfolders = ['docs', 'src', 'test']
        for folder in subfolders:
            subfolder_path = os.path.join(project_directory, folder)
            create_directory(subfolder_path)
        print(f"{CYAN}📁 Project structure created at: {project_directory}{c0}")

def create_category_structure(base_path):
    """
    Create a category-based directory structure with subdirectories.

    Args:
        base_path (str): The base path where the structure should be created.

    Returns:
        None
    """
    print(f"{CYAN}🗂 Gathering requirements for category creation.{c0}")
    categories = gather_stakeholder_feedback()  # You can define the logic for gathering categories
    for category in categories:
        category_path = os.path.join(base_path, category)
        create_directory(category_path)
        for letter in string.ascii_uppercase:
            sub_path = os.path.join(category_path, letter)
            create_directory(sub_path)
        print(f"{CYAN}🗃 Category '{category}' with subdirectories created successfully in '{category_path}'.{c0}")

def main():
    os.system('clear')
    print(f"{CYAN}====================================================={c0}")
    print(f"{CYAN}🌟 DIRECTORY STRUCTURE GENERATOR 🌟{c0}")
    print(f"{CYAN}====================================================={c0}")

    build_options = {
        "1": create_datetime_structure,
        "2": create_alphabetical_structure,
        "3": create_numerical_structure,
        "4": create_category_structure,
        "5": create_custom_tag_structure,
        "6": create_project_structure
    }

    while True:
        print(f"{CYAN}=============== // Main Menu // ====================={c0}")
        print(f"{CYAN}1) 📆 Date/time     3) 🔢 Numerical     5) 🏷 Tag{c0}")
        print(f"{CYAN}2) 🔤 Alphabetical  4) 📂 Category      6) 📚 Project{c0}")
        print(f"{CYAN}7) 🚪 Exit{c0}")
        print(f"{CYAN}====================================================={c0}")
        command = input(f"{CYAN}👉 By your command: {c0}").strip().lower()  # Trimming and making input lower case

        if command == '7':
            print(f"{RED}Exiting the program.{c0}")
            break

        if command in build_options:
            if command != "6":
                base_path = get_valid_input("Enter the base path for the directory structure: ",
                                            r'^[\\\/\w\s-]+$', "path")
                if not os.path.isdir(base_path):
                    print(f"{CYAN}Paths provided does not exist. The Directory structure can not be created.{c0}")
                    continue
                build_options[command](base_path)
                print(f"{CYAN}Structure created successfully in '{base_path}'.{c0}")
            else:
                build_options[command]()
        else:
            print(f"{RED}Invalid command.{c0}")

if __name__ == "__main__":
    main()
