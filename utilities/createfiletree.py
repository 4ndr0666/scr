import os
from datetime import datetime, timedelta
import string
import re

def create_directory(path):
    try:
        os.makedirs(path, exist_ok=True)
        return True
    except OSError:
        print(f"Error: Creating directory {path} failed.")
        return False

def validate_input(input_string, pattern, input_type="path"):
    if not re.match(pattern, input_string):
        print(f"Invalid {input_type}. Please try again.")
        return False
    return True

def get_valid_input(prompt, pattern, input_type="path"):
    while True:
        user_input = input(prompt)
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
            create_directory(os.path.join(base_path, category, sub_tag))

def create_project_structure():
    parent_directory = get_valid_input("Enter the parent directory (e.g., ~/Build/projects): ", r'^[\\\/\w\s-]+$', "path")
    project_name = get_valid_input("Enter the project name: ", r'^[\w\s-]+$', "name")

    project_directory = os.path.join(parent_directory, project_name)

    if create_directory(project_directory):
        subfolders = ['docs', 'src', 'test']
        for folder in subfolders:
            create_directory(os.path.join(project_directory, folder))

        print(f"Project structure created at: {project_directory}")

def create_category_structure(base_path):
    print("Gathering requirements for category creation.")
    categories = gather_stakeholder_feedback()

    for category in categories:
        category_path = os.path.join(base_path, category)
        create_directory(category_path)
        # Creating alphabetical subdirectories for each category
        for letter in string.ascii_uppercase:
            create_directory(os.path.join(category_path, letter))
        print(f"Category '{category}' with subdirectories created successfully in '{category_path}'.")

def gather_stakeholder_feedback():
    print("Please provide your preferred categories (e.g., Finance, HR, IT):")
    categories = input("Enter categories separated by comma: ").split(',')
    return [category.strip() for category in categories]

def main():
    print("=====================================================================")
    print("DIRECTORY STRUCTURE GENERATOR")
    print("=====================================================================")

    build_options = {
        "1": create_datetime_structure,
        "2": create_alphabetical_structure,
        "3": create_numerical_structure,
        "4": create_category_structure,
        "5": create_custom_tag_structure,
        "6": create_project_structure
    }

    print("=============== // Main Menu // =====================")
    print("1) Date/time     3) Numerical     5) Tag")
    print("2) Alphabetical  4) Category      6) Project")
    print("=====================================================")
    command = get_valid_input("By your command: ", r'^[1-6]$', "choice")

    if command in build_options:
        if command != "6":
            base_path = get_valid_input("Enter the base path for the directory structure: ", r'^[\\\/\w\s-]+$', "path")
            if not os.path.isdir(base_path):
                print("The provided path does not exist.")
                return
            build_options[command](base_path)
            print(f"Structure created successfully in '{base_path}'.")
        else:
            build_options[command]()

if __name__ == "__main__":
    main()
