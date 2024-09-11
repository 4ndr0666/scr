import json
import os
import subprocess

# Preset custom headers for common websites
HEADER_PRESETS = {
    "reddit": {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    "twitter": {
        "Authorization": "Bearer YOUR_TWITTER_BEARER_TOKEN",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    "pixiv": {
        "Authorization": "Bearer YOUR_PIXIV_BEARER_TOKEN",
        "User-Agent": "PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)"
    },
    "deviantart": {
        "Authorization": "Client-ID YOUR_CLIENT_ID",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
}

def generate_gallery_dl_config(base_url, start_num, end_num, zero_padding, rate, retries, timeout, postprocessors, sleep_interval, cookies=None, headers=None):
    # Extract file extension from the base URL (e.g., jpg, png)
    file_extension = base_url.split('.')[-1]
    
    # Replace the numeric part of the base URL with a placeholder
    placeholder_url = base_url.replace(str(start_num).zfill(zero_padding), "{num:0" + str(zero_padding) + "}")

    # Construct the JSON configuration with additional options
    config = {
        "extractor": {
            "template": {
                "type": "url",
                "url": placeholder_url,
                "range": {
                    "num": [start_num, end_num]
                },
                "format": "int"
            },
            "sleep-request": sleep_interval  # Set sleep interval between requests
        },
        "downloader": {
            "rate": rate,                # Restrict download speed
            "progress": 2.0,             # Show progress after 2 seconds
            "retries": retries,          # Number of retries for failed downloads
            "timeout": timeout,          # Time before considering download failed
            "part-directory": "/tmp/.download/"  # Store partial downloads temporarily
        },
        "output": {
            "log": {
                "level": "info",  # Set log level
                "logfile": {
                    "path": os.path.expanduser("~/gallery-dl/log.txt"),
                    "mode": "w",  # Write mode for logs
                    "level": "debug"
                }
            },
            "unsupportedfile": {
                "path": os.path.expanduser("~/gallery-dl/unsupported.txt"),
                "mode": "a",
                "format": "{asctime} {message}",
                "format-date": "%Y-%m-%d-%H-%M-%S"
            },
            "shorten": "eaw",  # Shorten filenames for terminal display
            "ansi": True       # Enable ANSI escape sequences on Windows
        },
        "postprocessor": postprocessors  # Custom post-processors added by the user
    }

    # Add cookies if provided
    if cookies:
        config["extractor"]["cookies"] = cookies

    # Add custom headers if provided
    if headers:
        config["extractor"]["headers"] = headers

    return config

def save_config_to_file(config, filename="gallery-dl-config.json"):
    with open(filename, 'w') as json_file:
        json.dump(config, json_file, indent=4)
    print(f"Configuration saved to {filename}")

def run_gallery_dl(config_file):
    # Construct and execute the gallery-dl command with the generated config
    command = ["gallery-dl", "--config", config_file]
    print(f"Running gallery-dl with command: {' '.join(command)}")
    
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running gallery-dl: {e}")

def prompt_for_postprocessors():
    postprocessors = []
    while True:
        add_postprocessor = input("Do you want to add a post-processor? (y/n): ").strip().lower()
        if add_postprocessor == 'n':
            break
        
        name = input("Enter post-processor name (e.g., 'metadata', 'ugoira-mp4'): ").strip()
        extension = input("Enter file extension (e.g., 'mp4', 'cbz') [Leave blank for default]: ").strip()
        
        postprocessor = {
            "name": name
        }
        if extension:
            postprocessor["extension"] = extension
        
        postprocessors.append(postprocessor)
    
    return postprocessors if postprocessors else None

def choose_header_preset():
    print("\nChoose a preset header or provide your own:")
    print("1. Reddit")
    print("2. Twitter")
    print("3. Pixiv")
    print("4. DeviantArt")
    print("5. Custom headers")

    choice = input("Select a preset (1-5): ").strip()
    
    if choice == '1':
        return HEADER_PRESETS["reddit"]
    elif choice == '2':
        return HEADER_PRESETS["twitter"]
    elif choice == '3':
        return HEADER_PRESETS["pixiv"]
    elif choice == '4':
        return HEADER_PRESETS["deviantart"]
    elif choice == '5':
        custom_headers = input("Enter custom headers in JSON format: ").strip()
        return json.loads(custom_headers) if custom_headers else None
    else:
        print("Invalid choice. No headers will be used.")
        return None

def main():
    print("Gallery-dl JSON Config Generator with Extended Options and Preset Headers")

    # Prompt for the base URL
    base_url = input("Enter the base URL (with the numeric part included, e.g. '...-46.jpg'): ").strip()
    
    # Prompt for the start and end number for the sequence
    start_num = int(input("Enter the starting number (e.g., 1): "))
    end_num = int(input("Enter the ending number (e.g., 99): "))
    
    # Ask for zero-padding size (e.g., 01, 02, ...)
    zero_padding = int(input("Enter the zero-padding size (e.g., 2 for '01', 3 for '001'): "))

    # Optional downloader settings
    rate = input("Enter the download rate limit (e.g., 1M for 1 MB/s, default 1M): ").strip() or "1M"
    retries = int(input("Enter the number of retries for failed downloads (default 3): ").strip() or 3)
    timeout = float(input("Enter the timeout for a download to be considered failed (default 8.0 seconds): ").strip() or 8.0)

    # Custom post-processors
    postprocessors = prompt_for_postprocessors() or []

    # Optional sleep intervals between requests
    sleep_interval = [float(input("Enter minimum sleep interval between requests (default 2.0): ").strip() or 2.0),
                      float(input("Enter maximum sleep interval between requests (default 4.8): ").strip() or 4.8)]

    # Prompt for optional cookies (leave blank to skip)
    cookies_input = input("Enter cookies (in JSON format) if needed [Leave blank to skip]: ").strip()
    cookies = json.loads(cookies_input) if cookies_input else None

    # Choose preset or custom headers
    headers = choose_header_preset()

    # Generate the config based on user input
    config = generate_gallery_dl_config(base_url, start_num, end_num, zero_padding, rate, retries, timeout, postprocessors, sleep_interval, cookies, headers)

    # Save the config to a JSON file
    config_file = "gallery-dl-config.json"
    save_config_to_file(config, config_file)

    # Run gallery-dl with the generated config
    run_gallery_dl(config_file)

if __name__ == "__main__":
    main()
