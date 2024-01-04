import os
from datetime import datetime, timedelta
import string

# Define colors
RED = '\033[1;31m'
GRE = '\033[1;32m'
CYAN = '\033[1;36m'
c0 = '\033[0m'

def create_directory(path):
    try:
        os.makedirs(path, exist_ok=True)
        print(f"{GRE}📁 Directory created: {path}{c0}")
        return True
    except OSError:
        print(f"{RED}❌ Error: Creating directory {path} failed.{c0}")
        return False

def validate_input(input_string, pattern, input_type="path"):
    if not re.match(pattern, input_string):
        print(f"{CYAN}⚠️ Invalid {input_type}. Please try again.{RESET}")
        return False
    return True

def get_valid_input(prompt, pattern, input_type="path"):
    while True:
        user_input = input(f"{CYAN}{prompt}{RESET}")
        if validate_input(user_input, pattern, input_type):
            return user_input

def create_datetime_structure(base_path, years=2):
    for year in range(datetime.now().year, datetime.now().year + years):
        for month in range(1, 13):
            for day in range(1, (datetime(year, month + 1, 1) - timedelta(days=1)).day + 1):
                path = os.path.join(base_path, f"{year}", f"{month:02d}", f"{day:02d}")
                create_directory(path)

def create_alphabetical_structure(base_path):
    for letter in string.ascii_uppercase:
        path = os.path.join(base_path, letter)
        create_directory(path)

def create_numerical_structure(base_path):
    for num in range(1, 101):
        path = os.path.join(base_path, str(num))
        create_directory(path)

def create_custom_tag_structure(base_path):
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
    parent_directory = get_valid_input("Enter the parent directory (e.g., ~/Build/projects): ", r'^[\\\/\w\s-]+$', "path")
    project_name = get_valid_input("Enter the project name: ", r'^[\w\s-]+$', "name")
    project_directory = os.path.join(parent_directory, project_name)
    if create_directory(project_directory):
        subfolders = ['docs', 'src', 'test']
        for folder in subfolders:
            subfolder_path = os.path.join(project_directory, folder)
            create_directory(subfolder_path)
        print(f"{CYAN}📁 Project structure created at: {project_directory}{RESET}")

def create_category_structure(base_path):
    print(f"{CYAN}🗂 Gathering requirements for category creation.{RESET}")
    categories = gather_stakeholder_feedback()
    for category in categories:
        category_path = os.path.join(base_path, category)
        create_directory(category_path)
        for letter in string.ascii_uppercase:
            sub_path = os.path.join(category_path, letter)
            create_directory(sub_path)
        print(f"{CYAN}🗃 Category '{category}' with subdirectories created successfully in '{category_path}'.{RESET}")

def main():
    os.system('clear')
    print(f"{CYAN}====================================================={c0}")
    print(f"{CYAN}🌟 DIRECTORY STRUCTURE GENERATOR 🌟{c0}")
    print(f"{CYAN}====================================================={c0}")
    print(f"{CYAN}=============== // Main Menu // ====================={c0}")
    print(f"{CYAN}1) 📆 Date/time     3) 🔢 Numerical     5) 🏷 Tag{c0}")
    print(f"{CYAN}2) 🔤 Alphabetical  4) 📂 Category      6) 📚 Project{c0}")
    print(f"{CYAN}7) 🚪 Exit{c0}")
    print(f"{CYAN}====================================================={c0}")
        command = input(f"{CYAN}👉 By your command: {c0}")

        if command == '7':
            print(f"{RED}Exiting the program.{c0}")
            break

        if command in build_options:
            if command != "6":
                base_path = get_valid_input("Enter the base path for the directory structure: ", r'^[\\\/\w\s-]+$', "path")
                if not os.path.isdir(base_path):
                    print(f"{CYAN}The provided path does not exist.{c0}")
                    continue
                build_options[command](base_path)
                print(f"{CYAN}Structure created successfully in '{base_path}'.{c0}")
            else:
                build_options[command]()
        else:
            print(f"{RED}Invalid command.{c0}")

if __name__ == "__main__":
    main()
