import os
import subprocess
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

if os.geteuid() != 0:
      try:
          print("Attempting to escalate privileges...")
          subprocess.check_call(['sudo', sys.executable] + sys.argv)
          sys.exit()
      except subprocess.CalledProcessError as e:
          print(f"Error escalating privileges: {e}")
          sys.exit(e.returncode)

# Function to create system user and group
def create_system_user(user, uid, gid, description, groups=None, home_dir=None, shell='/bin/bash', sudo_privileges=False, apply_preset=False):
    """
    Create a system user and group if they do not already exist. 
    Add the user to additional groups if specified. Optionally grant sudo privileges and apply standard presets.
    
    Parameters:
    user (str): The username to create.
    uid (int): The user ID to assign.
    gid (int): The group ID to assign.
    description (str): A brief description of the user.
    groups (list): A list of additional groups to add the user to.
    home_dir (str): The home directory for the user. Defaults to system default if None.
    shell (str): The login shell for the user. Defaults to /bin/bash.
    sudo_privileges (bool): Whether to grant sudo privileges to the user. Defaults to False.
    apply_preset (bool): Whether to apply a standard preset of groups. Defaults to False.
    """
    try:
        # Check if group already exists
        result = subprocess.run(['getent', 'group', user], capture_output=True, text=True)
        if result.returncode == 0:
            logging.info(f"Group '{user}' already exists.")
        else:
            subprocess.run(['groupadd', '-g', str(gid), user], check=True)
        
        # Check if user already exists
        result = subprocess.run(['id', user], capture_output=True, text=True)
        if result.returncode == 0:
            logging.info(f"User '{user}' already exists.")
        else:
            user_add_cmd = ['useradd', '-u', str(uid), '-g', str(gid), '-c', description]
            if home_dir:
                user_add_cmd.extend(['-d', home_dir])
            if shell:
                user_add_cmd.extend(['-s', shell])
            user_add_cmd.append(user)
            subprocess.run(user_add_cmd, check=True)
            logging.info(f"Created user '{user}' with UID {uid} and GID {gid}.")
        
        # Add user to additional groups
        if groups:
            for group in groups:
                result = subprocess.run(['getent', 'group', group], capture_output=True, text=True)
                if result.returncode != 0:
                    subprocess.run(['groupadd', group], check=True)
                    logging.info(f"Created additional group '{group}'.")
                subprocess.run(['usermod', '-aG', group, user], check=True)
                logging.info(f"Added user '{user}' to group '{group}'.")

        # Apply standard preset groups
        if apply_preset:
            standard_groups = ["adm", "users", "disk", "wheel", "cdrom", "audio", "video", "usb", "optical", "storage", "scanner", "lp", "network", "power"]
            logging.info(f"Applying standard preset groups to {user}...")
            for group in standard_groups:
                result = subprocess.run(['getent', 'group', group], capture_output=True, text=True)
                if result.returncode == 0:
                    subprocess.run(['usermod', '-aG', group, user], check=True)
                    logging.info(f"Added {user} to {group}.")
                else:
                    logging.warning(f"Group {group} does not exist. Skipping...")

        # Grant sudo privileges if specified
        if sudo_privileges:
            subprocess.run(['usermod', '-aG', 'sudo', user], check=True)
            logging.info(f"Granted sudo privileges to user '{user}'.")

    except subprocess.CalledProcessError as e:
        logging.error(f"Error creating user {user}: {e}")

# Reload system manager configuration
def reload_system_manager():
    """
    Reload the system manager configuration.
    """
    try:
        logging.info("Starting system manager configuration reload.")
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        logging.info("Reloaded system manager configuration successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error reloading system manager configuration: {e}")

# Arm ConditionNeedsUpdate (fixed)
def arm_condition_needs_update():
    """
    Arm the ConditionNeedsUpdate.
    """
    try:
        logging.info("Starting to arm ConditionNeedsUpdate.")
        subprocess.run(['systemctl', 'isolate', 'default.target'], check=True)
        logging.info("Armed ConditionNeedsUpdate successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error arming ConditionNeedsUpdate: {e}")

# Update executables in /usr/bin
def update_executables():
    """
    Update the database of executable files in the system.
    """
    try:
        logging.info("Starting executable update in /usr/bin.")
        subprocess.run(['updatedb'], check=True)
        logging.info("Updated executables in /usr/bin successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error updating executables: {e}")

# Set system clock
def set_system_clock():
    """
    Synchronize the system clock.
    """
    try:
        logging.info("Starting system clock synchronization.")
        subprocess.run(['ntpd', '-qg'], check=True)
        logging.info("System clock synchronized successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error setting system clock: {e}")

# Check OpenSSL version and update if needed
def check_openssl_version(required_version):
    """
    Check the installed version of OpenSSL and log any mismatches. Update if necessary.
    """
    try:
        logging.info("Checking OpenSSL version.")
        result = subprocess.run(['openssl', 'version'], capture_output=True, text=True, check=True)
        current_version = result.stdout.strip().split(' ')[1]
        if current_version != required_version:
            logging.warning(f"OpenSSL version mismatch. Required: {required_version}, Found: {current_version}")
            update_openssl(required_version)
        else:
            logging.info(f"OpenSSL version is correct: {current_version}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error checking OpenSSL version: {e}")

def update_openssl(required_version):
    """
    Update OpenSSL to the required version.
    """
    try:
        logging.info(f"Updating OpenSSL to latest version.")
        subprocess.run(['pacman', '-Syy' , 'noconfirm'], check=True)
        subprocess.run(['pacman', '-S', 'openssl', '--noconfirm'], check=True)
        logging.info(f"Updated OpenSSL to the latest version")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error updating OpenSSL: {e}")

def main():
    """
    Main function to run all maintenance tasks.
    """
    users = [
        {'user': 'colord', 'uid': 957, 'gid': 957, 'desc': 'Color management daemon', 'groups': ['plugdev', 'video'], 'sudo_privileges': False},
        {'user': 'deluge', 'uid': 956, 'gid': 956, 'desc': 'Deluge BitTorrent daemon', 'groups': ['netdev'], 'sudo_privileges': True},
        {'user': 'geoclue', 'uid': 955, 'gid': 955, 'desc': 'Geoinformation service', 'groups': ['dialout', 'audio'], 'sudo_privileges': False},
        {'user': 'ntp', 'uid': 87, 'gid': 87, 'desc': 'Network Time Protocol'},
        {'user': 'redis', 'uid': 954, 'gid': 954, 'desc': 'Redis in-memory data structure store'},
        {'user': 'rtkit', 'uid': 133, 'gid': 133, 'desc': 'RealtimeKit', 'groups': ['audio', 'video'], 'sudo_privileges': False},
        {'user': 'developer', 'uid': 1001, 'gid': 1001, 'desc': 'Developer User', 'groups': ['docker', 'sudo'], 'home_dir': '/home/developer', 'shell': '/bin/zsh', 'sudo_privileges': True, 'apply_preset': True},
        {'user': 'sysadmin', 'uid': 1002, 'gid': 1002, 'desc': 'System Administrator', 'groups': ['adm', 'sudo'], 'home_dir': '/home/sysadmin', 'shell': '/bin/bash', 'sudo_privileges': True, 'apply_preset': True},
    ]

    # Create or verify system users
    for user in users:
        create_system_user(
            user['user'],
            user['uid'],
            user['gid'],
            user['desc'],
            groups=user.get('groups'),
            home_dir=user.get('home_dir'),
            shell=user.get('shell'),
            sudo_privileges=user.get('sudo_privileges', False),
            apply_preset=user.get('apply_preset', False)
        )

    # Execute maintenance tasks
    reload_system_manager()
    arm_condition_needs_update()
    update_executables()
    set_system_clock()
    check_openssl_version('1.1.1')

if __name__ == '__main__':
    main()
