import os
import re
import calendar
from datetime import datetime
import subprocess
import logging
import json
import shutil
from pathlib import Path

# Setup logging configuration
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

# Define colors for terminal output
RED = "\033[1;31m"
GRE = "\033[1;32m"
CYAN = "\033[1;36m"
c0 = "\033[0m"

# Default configuration for the script
DEFAULT_CONFIG = {
    "log_level": "INFO",
    "default_structure": "project",
    "base_path": str(Path.home() / "Build/projects"),
}


def load_config(config_file="config.json"):
    """
    Load configuration from a JSON file. If the file does not exist, use default configuration.

    Args:
        config_file (str): Path to the configuration file.

    Returns:
        dict: Configuration settings.
    """
    try:
        with open(config_file, "r") as file:
            config = json.load(file)
        logging.info(f"Configuration loaded from {config_file}")
        return config
    except FileNotFoundError:
        logging.warning(f"{config_file} not found. Using default configuration.")
        return DEFAULT_CONFIG


def save_config(config, config_file="config.json"):
    """
    Save the current configuration to a JSON file.

    Args:
        config (dict): Configuration settings to save.
        config_file (str): Path to the configuration file.

    Returns:
        None
    """
    try:
        with open(config_file, "w") as file:
            json.dump(config, file, indent=4)
        logging.info(f"Configuration saved to {config_file}")
    except Exception as e:
        logging.error(f"Failed to save configuration: {e}")


def run_command(command):
    """
    Execute a shell command and capture its output.

    Args:
        command (list): List of command and arguments.

    Returns:
        CompletedProcess: The result of the command execution.
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
        input_string (str): The input string to validate.
        pattern (str): Regular expression pattern for validation.
        input_type (str): Type of input (e.g., "path" or "name").

    Returns:
        bool: True if input is valid, False otherwise.
    """
    if not re.match(pattern, input_string):
        print(f"{CYAN}⚠️ Invalid {input_type}. Please try again.{c0}")
        return False
    return True


def get_valid_input(prompt, pattern, input_type="path"):
    """
    Prompt the user for valid input based on a specified pattern.

    Args:
        prompt (str): The message to display to the user.
        pattern (str): Regular expression pattern for validation.
        input_type (str): Type of input (e.g., "path" or "name").

    Returns:
        str: Validated user input.
    """
    while True:
        user_input = input(f"{CYAN}{prompt}{c0}").strip()
        if validate_input(user_input, pattern, input_type):
            return user_input


def create_directory(path):
    """
    Create a directory at the specified path if it doesn't already exist.

    Args:
        path (str): The directory path to create.

    Returns:
        bool: True if directory is created successfully or already exists, False otherwise.
    """
    try:
        os.makedirs(path, exist_ok=True)
        print(f"{GRE}📁 Directory created or already exists: {path}{c0}")
        return True
    except OSError as e:
        print(f"{RED}❌ Error: Creating directory {path} failed. {e}{c0}")
        return False


def create_datetime_structure(base_path, years=2):
    """
    Create a directory structure based on year, month, and day.

    Args:
        base_path (str): The base path where the structure will be created.
        years (int): Number of years to include in the structure.

    Returns:
        None
    """
    current_year = datetime.now().year
    for year in range(current_year, current_year + years):
        for month in range(1, 13):
            for day in range(1, calendar.monthrange(year, month)[1] + 1):
                path = os.path.join(base_path, f"{year}", f"{month:02d}", f"{day:02d}")
                create_directory(path)


def create_alphabetical_structure(base_path):
    """
    Create a directory structure with one directory for each letter of the alphabet.

    Args:
        base_path (str): The base path where the structure will be created.

    Returns:
        None
    """
    for letter in string.ascii_uppercase:
        path = os.path.join(base_path, letter)
        create_directory(path)


def create_numerical_structure(base_path):
    """
    Create a directory structure with directories numbered 1 to 100.

    Args:
        base_path (str): The base path where the structure will be created.

    Returns:
        None
    """
    for num in range(1, 101):
        path = os.path.join(base_path, str(num))
        create_directory(path)


def create_custom_tag_structure(base_path):
    """
    Create a directory structure based on predefined tags and categories.

    Args:
        base_path (str): The base path where the structure will be created.

    Returns:
        None
    """
    tags = {
        "todo": ["urgent", "medium", "low"],
        "status": ["in-progress", "completed", "on-hold"],
        "priority": ["high", "normal", "low"],
    }
    for category, sub_tags in tags.items():
        for sub_tag in sub_tags:
            path = os.path.join(base_path, category, sub_tag)
            create_directory(path)


def create_project_structure(base_path, project_name):
    """
    Create a standard project directory structure with subfolders (docs, src, test).

    Args:
        base_path (str): The base path where the project directory will be created.
        project_name (str): Name of the project.

    Returns:
        None
    """
    project_directory = os.path.join(base_path, project_name)
    if os.path.exists(project_directory):
        print(
            f"{RED}❌ Error: The project directory '{project_directory}' already exists.{c0}"
        )
        return
    if create_directory(project_directory):
        subfolders = ["docs", "src", "test"]
        for folder in subfolders:
            subfolder_path = os.path.join(project_directory, folder)
            create_directory(subfolder_path)
        print(f"{CYAN}📁 Project structure created at: {project_directory}{c0}")
        # Initialize Git repository
        init_git_repo(project_directory)
        # Create template files
        create_template_files(project_directory)


def init_git_repo(project_directory):
    """
    Initialize a Git repository in the specified directory.

    Args:
        project_directory (str): Path to the project directory.

    Returns:
        None
    """
    try:
        run_command(["git", "init", project_directory])
        print(f"{GRE}🔧 Git repository initialized in '{project_directory}'{c0}")
    except Exception as e:
        print(f"{RED}❌ Failed to initialize Git repository: {e}{c0}")


def create_template_files(project_directory):
    """
    Create common template files (README.md, .gitignore) in the project directory.

    Args:
        project_directory (str): Path to the project directory.

    Returns:
        None
    """
    templates = {
        "README.md": f"# {os.path.basename(project_directory)}\n\nProject description here.",
        ".gitignore": "*.pyc\n__pycache__/\n.env",
    }
    for filename, content in templates.items():
        file_path = os.path.join(project_directory, filename)
        if not os.path.exists(file_path):
            with open(file_path, "w") as file:
                file.write(content)
            print(
                f"{GRE}📝 Template file '{filename}' created in '{project_directory}'{c0}"
            )


def backup_directory(base_path):
    """
    Create a backup of the existing directory structure by copying it to a new location.

    Args:
        base_path (str): The path of the directory to back up.

    Returns:
        None
    """
    backup_path = base_path + "_backup"
    try:
        shutil.copytree(base_path, backup_path)
        print(f"{GRE}📁 Backup created at '{backup_path}'{c0}")
    except Exception as e:
        print(f"{RED}❌ Failed to create backup: {e}{c0}")


def main():
    config = load_config()

    # Set log level from configuration
    logging.getLogger().setLevel(config.get("log_level", "INFO"))

    # OS-specific clear screen
    os.system("cls" if os.name == "nt" else "clear")

    print(f"{CYAN}====================================================={c0}")
    print(f"{CYAN}🌟 DIRECTORY STRUCTURE GENERATOR 🌟{c0}")
    print(f"{CYAN}====================================================={c0}")

    build_options = {
        "1": create_datetime_structure,
        "2": create_alphabetical_structure,
        "3": create_numerical_structure,
        "4": create_custom_tag_structure,
        "5": create_project_structure,
    }

    while True:
        print(f"{CYAN}=============== // Main Menu // ====================={c0}")
        print(f"{CYAN}1) 📆 Date/time     3) 🔢 Numerical     5) 📚 Project{c0}")
        print(f"{CYAN}2) 🔤 Alphabetical  4) 🏷 Tag           6) 🚪 Exit{c0}")
        print(f"{CYAN}====================================================={c0}")
        command = input(f"{CYAN}👉 By your command: {c0}").strip().lower()

        if command == "6":
            print(f"{RED}Exiting the program.{c0}")
            break

        if command in build_options:
            base_path = get_valid_input(
                "Enter the base path for the directory structure: ",
                r"^[\\\/\w\s-]+$",
                "path",
            )
            if not os.path.isdir(base_path):
                print(
                    f"{CYAN}⚠️ The path '{base_path}' does not exist or is invalid. Please provide a valid directory path.{c0}"
                )
                continue

            if command == "5":
                project_name = get_valid_input(
                    "Enter the project name: ", r"^[\w\s-]+$", "name"
                )
                build_options[command](base_path, project_name)
            else:
                backup_directory(base_path)
                build_options[command](base_path)

            print(f"{CYAN}Structure created successfully in '{base_path}'.{c0}")
        else:
            print(f"{RED}Invalid command.{c0}")


if __name__ == "__main__":
    main()
