import os
import sys
import subprocess
import shutil
import zstandard as zstd

# Define ANSI color codes for output
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
NC = '\033[0m'  # No Color

def is_root():
    """Check if the current user is root."""
    return os.geteuid() == 0

def restart_with_sudo():
    """Attempt to restart the script with sudo if not running as root."""
    if not is_root():
        try:
            print(f"{YELLOW}Restarting script with root privileges...{NC}")
            subprocess.check_call(['sudo', sys.executable] + sys.argv)
        except subprocess.CalledProcessError as e:
            print(f"{RED}Script failed to restart with sudo: {e}{NC}")
            sys.exit(e.returncode)

def check_dependencies():
    """Check for required dependencies and inform the user if any are missing."""
    dependencies_met = True
    messages = []
    
    for tool in ["jdupes", "zstd", "cpio"]:
        if shutil.which(tool) is None:
            messages.append(f"{tool} is not available. Please install {tool}.")
            dependencies_met = False
    
    return dependencies_met, messages

def run_optimized_jdupes(directory):
    """Run jdupes with optimized settings for the given directory."""
    if not os.path.isdir(directory):
        print(f"{RED}Invalid directory: {directory}{NC}")
        return
    
    cmd = ['jdupes', directory, '-rM', '-S1M']
    print(f"{YELLOW}Running jdupes on {directory}...{NC}")
    result = subprocess.run(cmd)
    
    if result.returncode == 0:
        print(f"{GREEN}jdupes operation completed successfully.{NC}")
    else:
        print(f"{RED}Error running jdupes.{NC}")

def bulk_delete_duplicates(directory):
    """Delete duplicates in the specified directory using jdupes."""
    if not os.path.isdir(directory):
        print(f"{RED}Invalid directory: {directory}{NC}")
        return
    
    confirmation = input(f"{YELLOW}Are you sure you want to delete duplicates in {directory}? (y/N): {NC}")
    if confirmation.lower() != 'y':
        print(f"{YELLOW}Bulk delete operation cancelled.{NC}")
        return
    
    cmd = ['jdupes', '-r', '-d', '-N', directory]
    result = subprocess.run(cmd)
    
    if result.returncode == 0:
        print(f"{GREEN}Duplicates deleted successfully.{NC}")
    else:
        print(f"{RED}Error deleting duplicates.{NC}")

def list_duplicates(directory):
    """List duplicates in the specified directory using jdupes."""
    if not os.path.isdir(directory):
        print(f"{RED}Invalid directory: {directory}{NC}")
        return
    
    cmd = ['jdupes', '-r', directory]
    result = subprocess.run(cmd)
    
    if result.returncode == 0:
        print(f"{GREEN}Duplicate listing completed successfully.{NC}")
    else:
        print(f"{RED}Error listing duplicates.{NC}")

def compress_with_zstd(file_paths, destination):
    """Compress given file paths using zstd and save them in the specified destination directory."""
    if not file_paths:
        print(f"{RED}No files provided for compression.{NC}")
        return
    
    if not os.path.isdir(destination):
        print(f"{RED}Invalid destination directory: {destination}{NC}")
        return
    
    compressor = zstd.ZstdCompressor()
    for file_path in file_paths:
        if os.path.isfile(file_path):
            dest_file = os.path.join(destination, os.path.basename(file_path) + '.zst')
            with open(file_path, 'rb') as src, open(dest_file, 'wb') as dst:
                compressor.copy_stream(src, dst)
            print(f"{GREEN}Compressed {file_path} to {dest_file}.{NC}")
        else:
            print(f"{YELLOW}Warning: {file_path} does not exist and will be skipped.{NC}")

def compress_with_cpio(file_paths, destination_archive):
    """Compress given file paths to a destination archive using cpio."""
    existing_files = [file_path for file_path in file_paths if os.path.isfile(file_path)]
    if not existing_files:
        print(f"{RED}No existing files provided for cpio compression.{NC}")
        return
    
    file_paths_str = '\n'.join(existing_files)
    cmd = ['cpio', '-ov', '--format=newc', '--file', destination_archive]
    result = subprocess.run(cmd, input=file_paths_str, text=True)
    
    if result.returncode == 0:
        print(f"{GREEN}Files compressed and archived to {destination_archive} using cpio.{NC}")
    else:
        print(f"{RED}cpio compression failed.{NC}")

def main_menu():
    """Display the main menu and handle user input for different operations."""
    operations = {
        '1': ('Find Duplicates with jdupes', run_optimized_jdupes),
        '2': ('Bulk Delete Duplicates', bulk_delete_duplicates),
        '3': ('List Duplicates with Details', list_duplicates),
        '4': ('Compress Duplicates using zstd', compress_with_zstd),
        '5': ('Compress Duplicates using cpio', compress_with_cpio),
        '6': ('Exit', lambda: print(f"{GREEN}Exiting...{NC}"))
    }

    dependencies_met, dependency_messages = check_dependencies()
    if not dependencies_met:
        for message in dependency_messages:
            print(f"{RED}{message}{NC}")
        return

    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{GREEN}==== // Jdupes Main Menu // ===={NC}")
        for key, (description, _) in operations.items():
            print(f"{key}) {description}")
        
        choice = input("Select an option: ").strip()
        operation = operations.get(choice)

        if operation:
            _, func = operation
            if choice == '6':
                func()
                break
            elif choice in ['1', '2', '3']:
                directory = input("Enter the directory: ").strip()
                func(directory)
            elif choice in ['4', '5']:
                files = input("Enter the list of files to compress separated by commas: ").split(',')
                destination = input("Enter the destination path for the compressed file: ").strip()
                func(files, destination)
        else:
            print(f"{RED}Invalid option selected.{NC}")
        
        input(f"{YELLOW}Press Enter to continue...{NC}")

if __name__ == "__main__":
    restart_with_sudo()
    main_menu()
