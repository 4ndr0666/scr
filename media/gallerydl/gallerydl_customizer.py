#!/usr/bin/env python3

import json
import os
import subprocess
import re
import sys
from getpass import getpass

# Preset custom headers for common websites
HEADER_PRESETS = {
    "reddit": {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    "twitter": {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
    "pixiv": {"User-Agent": "PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)"},
    "deviantart": {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    },
}


def validate_url(url):
    """Validate the base URL using regex."""
    regex = re.compile(
        r"^(?:http|https)://"  # http:// or https://
        r"(?:www\.)?"  # optional www.
        r"[a-zA-Z0-9.-]+"  # domain
        r"(?:\.[a-zA-Z]{2,})"  # TLD
        r"/(?:(?:\S+/)?)*"  # path
        r"\S+\.\w{2,}$"  # file with extension
    )
    if not re.match(regex, url):
        print(f"{LIGHTRED}Error: Invalid URL format.{NC}")
        sys.exit(1)


def validate_numeric_input(value, name):
    """Ensure the input is a positive integer or float (for timeouts)."""
    if re.match(r"^\d+$", value):
        return int(value)
    elif re.match(r"^\d+(\.\d+)?$", value):
        return float(value)
    else:
        print(f"{LIGHTRED}Error: {name} must be a positive integer or float.{NC}")
        sys.exit(1)


def generate_gallery_dl_config(
    base_url,
    start_num,
    end_num,
    zero_padding,
    rate,
    retries,
    timeout,
    postprocessors,
    sleep_interval,
    proxy,
    no_part,
    no_skip,
    write_log,
    write_unsupported,
    write_pages,
    resolve_urls,
    get_urls,
    cookies,
    headers,
    additional_options,
    output_directory,
    config_file,
):
    """
    Generate the gallery-dl configuration JSON.
    """
    # Replace the placeholder with formatting
    template_url = base_url.replace("{num}", "{num:0" + str(zero_padding) + "d}")

    config = {
        "extractor": {
            "template": {
                "type": "url",
                "url": template_url,
                "range": {"num": [start_num, end_num]},
                "format": "int",
            },
            "sleep-request": sleep_interval,  # Set sleep interval between requests
        },
        "downloader": {
            "rate": rate,  # Restrict download speed
            "retries": retries,  # Number of retries for failed downloads
            "timeout": timeout,  # Time before considering download failed
            "proxy": proxy,  # Proxy settings
            "part-directory": (
                "/tmp/.download/" if not no_part else ""
            ),  # Store partial downloads temporarily
            "skip": not no_skip,  # Skip existing files based on flag
        },
        "output": {
            "directory": output_directory,  # Set download directory
            "log": {
                "level": "info",  # Set log level
                "logfile": {
                    "path": os.path.expanduser(write_log) if write_log else None,
                    "mode": "w",  # Write mode for logs
                    "level": "debug",
                },
            },
            "unsupportedfile": {
                "path": (
                    os.path.expanduser(write_unsupported) if write_unsupported else None
                ),
                "mode": "a",
                "format": "{asctime} {message}",
                "format-date": "%Y-%m-%d-%H-%M-%S",
            },
            "shorten": "eaw",  # Shorten filenames for terminal display
            "ansi": True,  # Enable ANSI escape sequences on Windows
        },
        "http": {"timeout": timeout, "proxy": proxy},  # HTTP timeout  # Proxy settings
    }

    # Add post-processors if provided
    if postprocessors:
        config["postprocessor"] = postprocessors

    # Add additional options
    if additional_options:
        for key, value in additional_options.items():
            config[key] = value

    # Add write-pages option
    if write_pages:
        config["output"]["write-pages"] = True

    # Add resolve-urls and get-urls options
    if resolve_urls:
        config["output"]["resolve-urls"] = True
    if get_urls:
        config["output"]["get-urls"] = True

    # Add cookies if provided
    if cookies:
        config["extractor"]["cookies"] = cookies

    # Add custom headers if provided
    if headers:
        config["extractor"]["headers"] = headers

    # Clean up None values
    def clean_dict(d):
        if isinstance(d, dict):
            return {k: clean_dict(v) for k, v in d.items() if v is not None}
        return d

    clean_config = clean_dict(config)

    return clean_config


def save_config_to_file(config, filename="gallery-dl-config.json"):
    """Save the gallery-dl configuration to a JSON file."""
    try:
        expanded_filename = os.path.expanduser(filename)
        dirname = os.path.dirname(expanded_filename)
        if dirname:  # Only attempt to create directories if a path is specified
            os.makedirs(dirname, exist_ok=True)
        with open(expanded_filename, "w") as json_file:
            json.dump(config, json_file, indent=4)
        print(f"{LIGHTGREEN}Configuration saved to {filename}{NC}")
    except Exception as e:
        print(f"{LIGHTRED}Error saving configuration: {e}{NC}")
        sys.exit(1)


def run_gallery_dl(config_file, url):
    """Execute the gallery-dl command with the generated configuration."""
    # Construct and execute the gallery-dl command with the generated config
    command = ["gallery-dl", "--config", config_file, url]
    print(f"Running gallery-dl with command: {' '.join(command)}")

    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as e:
        print(f"{LIGHTRED}Error running gallery-dl: {e}{NC}")
        sys.exit(1)


def prompt_for_postprocessors():
    """Prompt the user to add post-processors."""
    postprocessors = []
    while True:
        add_postprocessor = (
            input("Do you want to add a post-processor? (y/n): ").strip().lower()
        )
        if add_postprocessor == "n":
            break
        elif add_postprocessor != "y":
            print("Please enter 'y' or 'n'.")
            continue

        name = input(
            "Enter post-processor name (e.g., 'metadata', 'ugoira-mp4'): "
        ).strip()
        extension = input(
            "Enter file extension (e.g., 'mp4', 'cbz') [Leave blank for default]: "
        ).strip()

        if not name:
            print("Post-processor name cannot be empty.")
            continue

        postprocessor = {"name": name}
        if extension:
            postprocessor["extension"] = extension

        postprocessors.append(postprocessor)

    return postprocessors if postprocessors else None


def choose_header_preset():
    """Allow the user to choose a preset header or provide custom headers."""
    print("\nChoose a preset header or provide your own:")
    print("1. Reddit")
    print("2. Twitter")
    print("3. Pixiv")
    print("4. DeviantArt")
    print("5. Custom headers")
    print("6. No headers")

    choice = input("Select a preset (1-6): ").strip()

    if choice == "1":
        return HEADER_PRESETS["reddit"]
    elif choice == "2":
        bearer_token = getpass("Enter your Twitter Bearer Token: ")
        if not bearer_token:
            print(f"{LIGHTRED}Error: Twitter Bearer Token cannot be empty.{NC}")
            sys.exit(1)
        return {
            "Authorization": f"Bearer {bearer_token}",
            "User-Agent": HEADER_PRESETS["twitter"]["User-Agent"],
        }
    elif choice == "3":
        bearer_token = getpass("Enter your Pixiv Bearer Token: ")
        if not bearer_token:
            print(f"{LIGHTRED}Error: Pixiv Bearer Token cannot be empty.{NC}")
            sys.exit(1)
        return {
            "Authorization": f"Bearer {bearer_token}",
            "User-Agent": HEADER_PRESETS["pixiv"]["User-Agent"],
        }
    elif choice == "4":
        client_id = getpass("Enter your DeviantArt Client ID: ")
        if not client_id:
            print(f"{LIGHTRED}Error: DeviantArt Client ID cannot be empty.{NC}")
            sys.exit(1)
        return {
            "Authorization": f"Client-ID {client_id}",
            "User-Agent": HEADER_PRESETS["deviantart"]["User-Agent"],
        }
    elif choice == "5":
        custom_headers_input = input(
            'Enter custom headers in JSON format (e.g., {"Header-Name": "Header-Value"}): '
        ).strip()
        if not custom_headers_input:
            print("No headers provided. Proceeding without custom headers.")
            return None
        try:
            custom_headers = json.loads(custom_headers_input)
            return custom_headers
        except json.JSONDecodeError:
            print(f"{LIGHTRED}Error: Invalid JSON format for headers.{NC}")
            sys.exit(1)
    elif choice == "6":
        return None
    else:
        print("Invalid choice. No headers will be used.")
        return None


def prompt_for_additional_options():
    """Prompt the user to add additional key-value options."""
    additional_options = {}
    while True:
        add_option = (
            input("Do you want to add an additional option? (y/n): ").strip().lower()
        )
        if add_option == "n":
            break
        elif add_option != "y":
            print("Please enter 'y' or 'n'.")
            continue

        key = input("Enter the option key (e.g., 'no-colors'): ").strip()
        value = input("Enter the option value (e.g., 'True' or '1M'): ").strip()

        if not key:
            print("Option key cannot be empty.")
            continue

        # Handle boolean flags without values
        if value.lower() in ["true", "false", ""]:
            additional_options[key] = value.capitalize() if value else True
        else:
            additional_options[key] = value

    return additional_options if additional_options else None


def main():
    print("Gallery-dl JSON Config Generator with Extended Options and Preset Headers\n")

    # Define color codes for error messages
    global LIGHTRED, LIGHTGREEN, WHT, NC
    LIGHTGREEN = "\033[1;32m"
    LIGHTRED = "\033[1;31m"
    ORANGE = "\033[0;33m"
    CYAN = "\033[0;36m"
    WHT = "\033[0m"
    NC = "\033[0J"

    # Prompt for the base URL with placeholder
    base_url = input(
        "Enter the base URL (with a placeholder for numbering, e.g., 'https://www.x.com/image{num}.jpg'): "
    ).strip()

    # Validate base URL
    validate_url(base_url)

    # Ensure the placeholder exists in the base URL
    if "{num}" not in base_url:
        print(
            f"{LIGHTRED}Error: The base URL must contain the placeholder '{{num}}' for numbering.{NC}"
        )
        sys.exit(1)

    # Prompt for the start and end number for the sequence
    start_num_input = input("Enter the starting number (default: 1): ").strip() or "1"
    start_num = validate_numeric_input(start_num_input, "Starting number")

    end_num_input = input("Enter the ending number (default: 100): ").strip() or "100"
    end_num = validate_numeric_input(end_num_input, "Ending number")

    if end_num < start_num:
        print(
            f"{LIGHTRED}Error: Ending number ({end_num}) cannot be less than starting number ({start_num}).{NC}"
        )
        sys.exit(1)

    # Ask for zero-padding size (e.g., 01, 02, ...)
    zero_padding_input = (
        input("Enter the zero-padding size (default: 2): ").strip() or "2"
    )
    zero_padding = validate_numeric_input(zero_padding_input, "Zero-padding size")

    # Optional downloader settings
    rate = (
        input(
            "Enter the download rate limit (e.g., 1M for 1 MB/s, default: 1M): "
        ).strip()
        or "1M"
    )
    retries_input = (
        input("Enter the number of retries for failed downloads (default: 3): ").strip()
        or "3"
    )
    retries = validate_numeric_input(retries_input, "Number of retries")

    timeout_input = (
        input(
            "Enter the timeout for a download to be considered failed (default: 8.0 seconds): "
        ).strip()
        or "8.0"
    )
    timeout = validate_numeric_input(timeout_input, "Timeout")

    # Proxy settings
    proxy = (
        input(
            "Enter proxy URL if needed (e.g., http://proxyserver:port) [Leave blank to skip]: "
        ).strip()
        or None
    )

    # Flags for downloader options
    no_part_input = (
        input("Do you want to disable .part files? (y/n, default: n): ").strip().lower()
        or "n"
    )
    no_part = True if no_part_input == "y" else False

    no_skip_input = (
        input("Do you want to disable skipping existing files? (y/n, default: n): ")
        .strip()
        .lower()
        or "n"
    )
    no_skip = True if no_skip_input == "y" else False

    # Post-processing
    postprocessors = prompt_for_postprocessors()

    # Sleep intervals
    min_sleep_input = (
        input(
            "Enter minimum sleep interval between requests (default: 2.0 seconds): "
        ).strip()
        or "2.0"
    )
    min_sleep = validate_numeric_input(min_sleep_input, "Minimum sleep interval")

    max_sleep_input = (
        input(
            "Enter maximum sleep interval between requests (default: 4.8 seconds): "
        ).strip()
        or "4.8"
    )
    max_sleep = validate_numeric_input(max_sleep_input, "Maximum sleep interval")

    if max_sleep < min_sleep:
        print(
            f"{LIGHTRED}Error: Maximum sleep interval ({max_sleep}) cannot be less than minimum sleep interval ({min_sleep}).{NC}"
        )
        sys.exit(1)

    sleep_interval = [min_sleep, max_sleep]

    # Prompt for optional cookies (leave blank to skip)
    cookies_input = input(
        "Enter cookies (in JSON format) if needed [Leave blank to skip]: "
    ).strip()
    if cookies_input:
        try:
            cookies = json.loads(cookies_input)
        except json.JSONDecodeError:
            print(f"{LIGHTRED}Error: Invalid JSON format for cookies.{NC}")
            sys.exit(1)
    else:
        cookies = None

    # Choose preset or custom headers
    headers = choose_header_preset()

    # Additional output options
    write_log = (
        input(
            "Enter log file path if you want to write logs [Leave blank to skip]: "
        ).strip()
        or None
    )
    write_unsupported = (
        input("Enter unsupported URLs log file path [Leave blank to skip]: ").strip()
        or None
    )
    write_pages_input = (
        input(
            "Do you want to write downloaded intermediary pages for debugging? (y/n, default: n): "
        )
        .strip()
        .lower()
        or "n"
    )
    write_pages = True if write_pages_input == "y" else False

    # Resolve URLs and Get URLs options
    resolve_urls_input = (
        input("Do you want to resolve intermediary URLs? (y/n, default: n): ")
        .strip()
        .lower()
        or "n"
    )
    resolve_urls = True if resolve_urls_input == "y" else False

    get_urls_input = (
        input("Do you want to print URLs instead of downloading? (y/n, default: n): ")
        .strip()
        .lower()
        or "n"
    )
    get_urls = True if get_urls_input == "y" else False

    # Additional options
    additional_options = prompt_for_additional_options()

    # Output directory
    output_directory = (
        input(
            "Enter the download directory path (default: current directory): "
        ).strip()
        or "."
    )

    # Configuration file name
    config_file = (
        input(
            "Enter the configuration file name (default: gallery-dl-config.json): "
        ).strip()
        or "gallery-dl-config.json"
    )

    # Generate the config based on user input
    config = generate_gallery_dl_config(
        base_url,
        start_num,
        end_num,
        zero_padding,
        rate,
        retries,
        timeout,
        postprocessors,
        sleep_interval,
        proxy,
        no_part,
        no_skip,
        write_log,
        write_unsupported,
        write_pages,
        resolve_urls,
        get_urls,
        cookies,
        headers,
        additional_options,
        output_directory,
        config_file,
    )

    # Save the config to a JSON file
    save_config_to_file(config, config_file)

    # Prompt to run gallery-dl
    run_now_input = (
        input(
            "Do you want to run gallery-dl immediately with the generated configuration? (y/n, default: y): "
        )
        .strip()
        .lower()
        or "y"
    )
    if run_now_input == "y":
        url = input("Enter the target URL to download: ").strip()
        if not url:
            print(f"{LIGHTRED}Error: Target URL cannot be empty.{NC}")
            sys.exit(1)
        run_gallery_dl(config_file, url)
    else:
        print(
            "Configuration generation completed. You can run gallery-dl manually when ready."
        )


if __name__ == "__main__":
    main()
