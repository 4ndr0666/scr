#!/usr/bin/env python3

import json
import os
import re
import shutil
import subprocess
import sys
import webbrowser  # Moved to top as it's used multiple times

import requests

# Terminal colors
CYAN = "\033[38;5;51m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
RESET = "\033[0m"

# Constants
PREDEFINED_DORKS_URL = "https://pastebin.com/raw/RFYt8U22"
LOG_FILE = os.path.expanduser("~/.searchmaster.log")

# Define dork operators for easier iteration in build_google_dork
# Each dictionary contains:
# - name: The Google dork operator keyword (e.g., "inurl")
# - prompt: The user-facing prompt for this operator
# - format: The f-string format for the dork part (e.g., 'inurl:"{}"')
# - validator (optional): A lambda function for specific input validation
DORK_OPERATORS = [
    {"name": "inurl", "prompt": "Enter a path or parameter to look for in the URL (e.g., admin).", "format": 'inurl:"{}"'},
    {"name": "allinurl", "prompt": "Enter multiple terms to look for in the URL (separated by spaces).", "format": 'allinurl:"{}"'},
    {"name": "intext", "prompt": "Enter a string to search for within the page's content (e.g., password).", "format": 'intext:"{}"'},
    {"name": "allintext", "prompt": "Enter multiple terms to search for within the page's content (separated by spaces).", "format": 'allintext:"{}"'},
    {"name": "intitle", "prompt": "Enter a string to search for within the page's title (e.g., login).", "format": 'intitle:"{}"'},
    {"name": "allintitle", "prompt": "Enter multiple terms to search for within the page's title (separated by spaces).", "format": 'allintitle:"{}"'},
    {"name": "inanchor", "prompt": "Enter a string to search for within the page's anchor text (e.g., download).", "format": 'inanchor:"{}"'},
    {"name": "allinanchor", "prompt": "Enter multiple terms to search for within the page's anchor text (separated by spaces).", "format": 'allinanchor:"{}"'},
    {"name": "filetype", "prompt": "Enter the file type you're searching for (e.g., pdf).", "format": 'filetype:{}', "validator": lambda x: bool(re.fullmatch(r'[a-zA-Z0-9]+', x))},
    {"name": "site", "prompt": "Limit the search to a specific site (e.g., example.com).", "format": 'site:{}', "validator": lambda x: validate_site_format(f"site:{x}")},
    {"name": "define", "prompt": "Enter a term to define (e.g., Python).", "format": 'define:{}'},
    {"name": "link", "prompt": "Enter a URL to find pages linking to it (e.g., example.com).", "format": 'link:{}'},
    {"name": "related", "prompt": "Enter a URL to find pages related to it (e.g., example.com).", "format": 'related:{}'},
    {"name": "cache", "prompt": "Enter a URL to view Google's cached version (e.g., example.com).", "format": 'cache:{}'},
]


def log_message(message: str) -> None:
    """
    Logs messages to a file.

    Args:
        message: The string message to log.
    """
    try:
        with open(LOG_FILE, "a") as log_file:
            log_file.write(f"{message}\n")
    except IOError as e:
        print(f"{RED}Error writing to log file {LOG_FILE}: {e}{RESET}")


def ask_user(prompt: str) -> str:
    """
    Prompts the user for input and returns the trimmed response.
    Handles EOFError and KeyboardInterrupt to gracefully exit.

    Args:
        prompt: The string prompt to display to the user.

    Returns:
        The user's input string, stripped of leading/trailing whitespace.
    """
    try:
        return input(f"{prompt}\n> ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\nOperation cancelled by user.")
        sys.exit(0)


def display_help() -> None:
    """
    Displays the help information for building a Google dork using a pager.
    Uses 'less' by default, falling back to other pagers or printing directly.
    """
    help_text = """
    ### Searchmaster Dork Building

    The `inurl` operator is used to search for pages where the URL contains a specific word or phrase.
    This is useful for finding certain types of pages, like login pages, admin panels, or specific file types.

    ### Example 1: Finding Login Pages
    - Prompt: Enter a path or parameter to look for in the URL (e.g., inurl:admin):
    - User Input: login
    - Explanation: If you want to find URLs that contain the word "login", this is how you would start.
    - Resulting Dork: inurl:"login"

    ### Example 2: Searching for Files in the URL
    - Prompt: Enter a path or parameter to look for in the URL (e.g., inurl:admin):
    - User Input: jpeg
    - Explanation: If you're trying to find URLs that include the word "jpeg", perhaps to locate images or directories of images, this input is appropriate.
    - Resulting Dork: inurl:"jpeg"

    ### Example 3: Searching for Video Files
    - Prompt: Enter a path or parameter to look for in the URL (e.g., inurl:admin):
    - User Input: mp4
    - Explanation: This input helps find URLs that have "mp4" in them, potentially leading to video files.
    - Resulting Dork: inurl:"mp4"

    ### Step 2: Adding the `intext` Operator

    Next, the script will ask for content you want to find within the page's text.

    ### Example 1: Finding Password Mentions
    - Prompt: Enter a string to search for within the page's content (e.g., intext:password):
    - User Input: password
    - Explanation: This might be used to find pages that mention passwords, often leading to sensitive information.
    - Resulting Dork: intext:"password"

    ### Example 2: Searching for Image Descriptions
    - Prompt: Enter a string to search for within the page's content (e.g., intext:password):
    - User Input: sunset
    - Explanation: If you're looking for web pages that describe or discuss sunsets, you might use this input.
    - Resulting Dork: intext:"sunset"

    ### Example 3: Finding Mentions of Specific Formats
    - Prompt: Enter a string to search for within the page's content (e.g., intext:password):
    - User Input: high resolution
    - Explanation: This could be used to find pages discussing high-resolution images or videos.
    - Resulting Dork: intext:"high resolution"

    ### Step 3: Adding the `intitle` Operator

    After that, the script will ask for a term you want to find in the page's title.

    ### Example 1: Searching for Admin Pages
    - Prompt: Enter a string to search for within the page's title (e.g., intitle:login):
    - User Input: admin
    - Explanation: Use this to find pages with "admin" in the title, which often indicates an admin panel.
    - Resulting Dork: intitle:"admin"

    ### Example 2: Locating Indexes of Files
    - Prompt: Enter a string to search for within the page's title (e.g., intitle:login):
    - User Input: index of
    - Explanation: This is useful for finding directory listings or file indexes.
    - Resulting Dork: intitle:"index of"

    ### Example 3: Searching for Dashboard Titles
    - Prompt: Enter a string to search for within the page's title (e.g., intitle:login):
    - User Input: dashboard
    - Explanation: Helps find pages with "dashboard" in the title, likely leading to some form of control panel or admin interface.
    - Resulting Dork: intitle:"dashboard"

    ### Step 4: Adding the `filetype` Operator

    Next, the script will ask for the type of file you want to find.

    ### Example 1: Searching for PDF Files
    - Prompt: Enter the file type you're searching for (e.g., filetype:pdf):
    - User Input: pdf
    - Explanation: Useful when looking for PDF documents, such as reports or manuals.
    - Resulting Dork: filetype:pdf

    ### Example 2: Finding JPEG Images
    - Prompt: Enter the file type you're searching for (e.g., filetype:pdf):
    - User Input: jpeg
    - Explanation: Use this to find JPEG images, perhaps in directories or galleries.
    - Resulting Dork: filetype:jpeg

    ### Example 3: Locating MP4 Videos
    - Prompt: Enter the file type you're searching for (e.g., filetype:pdf):
    - User Input: mp4
    - Explanation: This will help you find MP4 video files across various websites.
    - Resulting Dork: filetype:mp4

    ### Step 5: Adding the `site` Operator

    Finally, the script asks if you want to restrict the search to a specific site.

    ### Example 1: Searching Within a Specific Domain
    - Prompt: Limit the search to a specific site (e.g., site:example.com):
    - User Input: example.com
    - Explanation: This restricts the search to example.com.
    - Resulting Dork: site:example.com

    ### Example 2: Searching Across Educational Sites
    - Prompt: Limit the search to a specific site (e.g., site:example.com):
    - User Input: edu
    - Explanation: Restricting your search to educational domains, useful for academic resources.
    - Resulting Dork: site:edu

    ### Example 3: Limiting to Government Sites
    - Prompt: Limit the search to a specific site (e.g., site:example.com):
    - User Input: gov
    - Explanation: This limits the search to government websites, useful for official documents or data.
    - Resulting Dork: site:gov

    ### Step 6: Combining and Using the Dork

    After you've entered all the components, the script combines them to create the final Google dork.

    **Example Dork:**
    ```
    inurl:"login" intext:"password" intitle:"admin" filetype:pdf site:example.com
    ```

    **Explanation:**
    - **inurl:"login"**: Searches for URLs containing "login".
    - **intext:"password"**: Finds pages mentioning "password" in their content.
    - **intitle:"admin"**: Looks for pages with "admin" in the title.
    - **filetype:pdf**: Restricts results to PDF files.
    - **site:example.com**: Limits the search to the example.com domain.
    """
    pager = os.getenv('PAGER', 'less')
    try:
        # Pass arguments as a list to avoid shell=True security risks.
        # -R: raw control characters (for colors)
        # -F: quit if entire file fits on one screen
        pager_args = [pager, '-R', '-F'] if pager == 'less' else [pager]
        with subprocess.Popen(pager_args, stdin=subprocess.PIPE) as proc:
            proc.stdin.write(help_text.encode('utf-8'))
            proc.stdin.close()
            proc.wait()
    except FileNotFoundError:
        print(f"{RED}Error: Pager '{pager}' not found. Please ensure it's installed and in your PATH.{RESET}")
    except subprocess.CalledProcessError as e:
        print(f"{RED}Error displaying help with pager: {e}{RESET}")
    except Exception as e:
        print(f"{RED}An unexpected error occurred while displaying help: {e}{RESET}")


def validate_date_format(date_string: str) -> bool:
    """
    Validates the date string to ensure it matches expected formats (DD.MM.YYYY, YYYY-MM-DD, MM/DD/YYYY).

    Args:
        date_string: The date string to validate.

    Returns:
        True if the date string matches any of the valid formats, False otherwise.
    """
    date_formats = [
        r'\d{2}\.\d{2}\.\d{4}',  # DD.MM.YYYY
        r'\d{4}-\d{2}-\d{2}',    # YYYY-MM-DD
        r'\d{2}/\d{2}/\d{4}'     # MM/DD/YYYY
    ]
    return any(re.fullmatch(fmt, date_string) for fmt in date_formats)


def validate_site_format(site_string: str) -> bool:
    """
    Validates that the site format matches a proper domain name or TLD.
    Handles 'site:example.com' or just 'example.com', and TLDs like 'edu', 'gov'.

    Args:
        site_string: The site string to validate.

    Returns:
        True if the site string is a valid domain/TLD format, False otherwise.
    """
    # More robust regex for domain names, including subdomains and common TLDs
    # Allows for 'site:example.com' or just 'example.com'
    # Also handles TLDs like 'edu', 'gov'
    # This regex is a common pattern for valid hostnames/domains.
    return re.fullmatch(r'(?:site:)?(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}', site_string) is not None


def process_search_intent(intent: str) -> str:
    """
    Processes the user's search intent, detecting and applying appropriate Google search operators
    like 'after', 'before', and 'site'. Removes processed parts from the original intent.

    Args:
        intent: The plain English search query provided by the user.

    Returns:
        The modified search query with recognized operators applied.
    """
    operators: list[str] = []

    # Process 'after' dates
    for match in re.finditer(r'\bafter\s+(\S+)', intent, re.IGNORECASE):
        date = match.group(1)
        if validate_date_format(date):
            operators.append(f"after:{date}")
        else:
            print(f"{YELLOW}Warning: Invalid date format for 'after': {date}{RESET}")
    # Remove all 'after' clauses from the intent
    intent = re.sub(r'\b(after)\s+\S+\b', '', intent, flags=re.IGNORECASE)

    # Process 'before' dates
    for match in re.finditer(r'\bbefore\s+(\S+)', intent, re.IGNORECASE):
        date = match.group(1)
        if validate_date_format(date):
            operators.append(f"before:{date}")
        else:
            print(f"{YELLOW}Warning: Invalid date format for 'before': {date}{RESET}")
    # Remove all 'before' clauses from the intent
    intent = re.sub(r'\b(before)\s+\S+\b', '', intent, flags=re.IGNORECASE)

    # Process 'site'
    for match in re.finditer(r'\bsite:(\S+)', intent, re.IGNORECASE):
        s = match.group(1)
        if validate_site_format(s):
            operators.append(f"site:{s}")
        else:
            print(f"{YELLOW}Warning: Invalid site format: {s}{RESET}")
    # Remove all 'site' clauses from the intent
    intent = re.sub(r'\bsite:\S+\b', '', intent, flags=re.IGNORECASE)

    # Combine operators with the remaining intent and clean up extra spaces
    final_intent = ' '.join(operators + [intent]).strip()
    final_intent = re.sub(r'\s+', ' ', final_intent).strip()  # Remove multiple spaces

    return final_intent


def probe_additional_parameters(intent: str) -> str:
    """
    Probes the user for additional search parameters (date range, site, file type, exclusion)
    and appends them to the search intent.

    Args:
        intent: The current search query string.

    Returns:
        The updated search query string with additional parameters.
    """
    print("\n### Additional Search Parameters ###\n")
    date_range = ask_user("Do you want to specify a date range? If yes, provide 'after' and/or 'before' dates (e.g., after 21.05.2023 or before 2023-05-21). If no, press Enter.")
    site = ask_user("Do you want to limit your search to a specific website? If yes, provide the site (e.g., nytimes.com). If no, press Enter.")
    filetype = ask_user("Are you looking for a specific file type (e.g., PDF)? If yes, specify the file type (e.g., pdf). If no, press Enter.")
    exclude = ask_user("Do you want to exclude any words from the search results? If yes, list them separated by spaces (e.g., politics economy). If no, press Enter.")

    if date_range:
        after_dates = re.findall(r'after\s+(\S+)', date_range, re.IGNORECASE)
        before_dates = re.findall(r'before\s+(\S+)', date_range, re.IGNORECASE)
        for date in after_dates:
            if validate_date_format(date):
                intent += f" after:{date}"
            else:
                print(f"{YELLOW}Warning: Invalid date format for 'after': {date}{RESET}")
        for date in before_dates:
            if validate_date_format(date):
                intent += f" before:{date}"
            else:
                print(f"{YELLOW}Warning: Invalid date format for 'before': {date}{RESET}")

    if site:
        # Prepend 'site:' for validation consistency if not already present
        site_for_validation = site if site.startswith("site:") else f"site:{site}"
        if validate_site_format(site_for_validation):
            intent += f" site:{site}"
        else:
            print(f"{YELLOW}Warning: Invalid site format: {site}{RESET}")

    if filetype:
        # Basic alphanumeric validation for filetype
        if re.fullmatch(r'[a-zA-Z0-9]+', filetype):
            intent += f" filetype:{filetype}"
        else:
            print(f"{YELLOW}Warning: Invalid filetype format: {filetype}. Only alphanumeric characters are allowed.{RESET}")

    if exclude:
        # Prefix each word with '-' for exclusion
        excluded_terms = ' '.join([f"-{term}" for term in exclude.split()])
        intent += f" {excluded_terms}"

    return intent.strip()


def copy_to_clipboard(text: str) -> None:
    """
    Copies the given text to the clipboard using available tools.
    Supports wl-copy (Wayland), xclip (X11), and pbcopy (macOS).

    Args:
        text: The string to copy to the clipboard.
    """
    try:
        if shutil.which('wl-copy'):
            subprocess.run(['wl-copy'], input=text.encode('utf-8'), check=True)
        elif shutil.which('xclip'):
            subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode('utf-8'), check=True)
        elif shutil.which('pbcopy'):
            subprocess.run(['pbcopy'], input=text.encode('utf-8'), check=True)
        else:
            print(f"{YELLOW}Warning: No clipboard utility found. Install 'wl-copy', 'xclip', or 'pbcopy' to enable clipboard functionality.{RESET}")
            return
        print(f"\n{GREEN}✔️  Your query has been copied to the clipboard.{RESET}")
    except subprocess.CalledProcessError as e:
        print(f"\n{RED}❌  Failed to copy to clipboard (process error): {e}{RESET}")
    except FileNotFoundError:
        print(f"\n{RED}❌  Clipboard utility not found. Please ensure it's installed and in your PATH.{RESET}")
    except Exception as e:
        print(f"\n{RED}❌  An unexpected error occurred while copying to clipboard: {e}{RESET}")


def _prompt_and_open_browser(query: str) -> None:
    """
    Helper function to prompt the user and open a search query in their default web browser.

    Args:
        query: The search query string to open in the browser.
    """
    open_browser = ask_user("Do you want to perform the search in your default web browser? (y/n):")
    if open_browser.lower() == 'y':
        try:
            webbrowser.open(f"https://www.google.com/search?q={query}")
            print(f"{GREEN}Opened search in your default web browser.{RESET}")
        except webbrowser.Error as e:
            print(f"{RED}Failed to open web browser: {e}. Please check your browser configuration.{RESET}")
        except Exception as e:
            print(f"{RED}An unexpected error occurred while opening web browser: {e}{RESET}")


def build_google_dork() -> None:
    """
    Prompts the user to build a Google dork step-by-step using common operators.
    Iterates through predefined operators, collects user input, validates, and constructs the dork.
    """
    print("\nLet's build a dork using available search operators.\n")
    dork_parts: list[str] = []

    for operator_info in DORK_OPERATORS:
        prompt_text = operator_info["prompt"] + " If none, press Enter:"
        user_input = ask_user(prompt_text)

        if user_input:
            # For operators that take multiple space-separated terms (e.g., allinurl),
            # join them with a single space.
            if operator_info["name"] in ["allinurl", "allintext", "allintitle", "allinanchor"]:
                formatted_input = " ".join(user_input.split())
            else:
                formatted_input = user_input

            # Apply specific validation if a validator function is defined for the operator
            validator = operator_info.get("validator")
            if validator:
                if validator(formatted_input):
                    dork_parts.append(operator_info["format"].format(formatted_input))
                else:
                    print(f"{YELLOW}Warning: Invalid format for {operator_info['name']}: '{user_input}'. This part will be skipped.{RESET}")
            else:
                # If no specific validator, just format and add
                dork_parts.append(operator_info["format"].format(formatted_input))

    google_dork = ' '.join(dork_parts)

    if not google_dork:
        print(f"{YELLOW}No operators selected. Exiting dork builder.{RESET}")
        return

    print("\nHere is your dork:")
    print(f"{GREEN}{google_dork}{RESET}")

    copy_to_clipboard(google_dork)
    _prompt_and_open_browser(google_dork)


def fetch_predefined_dorks() -> list[str]:
    """
    Fetches predefined Google dorks from the URL specified in PREDEFINED_DORKS_URL.

    Returns:
        A list of predefined dork strings, or an empty list if fetching fails.
    """
    try:
        response = requests.get(PREDEFINED_DORKS_URL, timeout=10)
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx or 5xx)
        dorks = response.text.strip().splitlines()
        if not dorks:
            print(f"{YELLOW}No predefined dorks found at the provided URL.{RESET}")
        return dorks
    except requests.exceptions.RequestException as e:
        print(f"{RED}Failed to fetch predefined dorks: {e}. Please check the URL and your internet connection.{RESET}")
        log_message(f"Error fetching predefined dorks: {e}")
        return []


def select_predefined_dork(dorks: list[str]) -> None:
    """
    Allows the user to select a predefined Google dork from a provided list.

    Args:
        dorks: A list of predefined dork strings to choose from.
    """
    if not dorks:
        print(f"{YELLOW}No predefined dorks available to select.{RESET}")
        return

    print("\nSelect a dork from the list below:\n")
    for i, dork in enumerate(dorks, start=1):
        print(f"{i}. {dork}")

    choice = ask_user("\nEnter the number of the dork you want to use:")
    try:
        index = int(choice) - 1
        if 0 <= index < len(dorks):
            selected_dork = dorks[index]
            print("\nHere is your selected dork:")
            print(f"{GREEN}{selected_dork}{RESET}")
            copy_to_clipboard(selected_dork)
            _prompt_and_open_browser(selected_dork)
        else:
            print(f"{RED}Invalid choice. Please select a valid number from the list.{RESET}")
    except ValueError:
        print(f"{RED}Invalid input. Please enter a number corresponding to the dork.{RESET}")


def build_custom_dork_from_intent(intent: str) -> None:
    """
    Builds a Google dork based on the user's plain English intent.
    This function processes the initial intent for common operators and then
    prompts for additional parameters.

    Args:
        intent: The initial plain English search query.
    """
    optimized_intent = process_search_intent(intent)
    final_query = probe_additional_parameters(optimized_intent)

    if not final_query:
        print(f"{YELLOW}No valid search parameters provided. Exiting.{RESET}")
        return

    print("\nHere is your optimized search query:")
    print(f"{GREEN}{final_query}{RESET}")

    copy_to_clipboard(final_query)
    _prompt_and_open_browser(final_query)


def main_menu() -> None:
    """
    Displays the main menu and handles user choices for different dork building modes.
    """
    while True:
        print(f"\n{CYAN}Searchmaster!{RESET}")
        print(f"({CYAN}1{RESET}) Optimize Search Intent (Plain English)")
        print(f"({CYAN}2{RESET}) Build Custom Dork (Step-by-step)")
        print(f"({CYAN}3{RESET}) Choose Predefined Dork")
        print(f"({CYAN}4{RESET}) Help")
        print(f"({CYAN}5{RESET}) Exit")
        choice = ask_user(f"\nEnter {CYAN}1{RESET}, {CYAN}2{RESET}, {CYAN}3{RESET}, {CYAN}4{RESET}, or {CYAN}5{RESET}:")

        if choice == '1':
            intent = ask_user("Describe your search query in plain English (e.g., 'find documents about AI after 2023-01-01 on site:example.com').")
            build_custom_dork_from_intent(intent)
        elif choice == '2':
            build_google_dork()
        elif choice == '3':
            predefined_dorks = fetch_predefined_dorks()
            if predefined_dorks:
                select_predefined_dork(predefined_dorks)
            else:
                print(f"{YELLOW}Could not fetch predefined dorks. Please check your internet connection and the URL.{RESET}")
        elif choice == '4':
            display_help()
        elif choice == '5':
            print(f"{BLUE}Exiting Searchmaster. Goodbye!{RESET}")
            sys.exit(0)
        else:
            print(f"{RED}Invalid choice. Please choose a valid option.{RESET}")


def main() -> None:
    """
    Main function to interact with the user, process their search intent,
    build Google dorks, and provide an optimized search query.
    Handles command-line arguments for direct dork building or starts the interactive menu.
    """
    # If arguments are provided, build dork from arguments directly
    if len(sys.argv) > 1:
        intent_from_args = ' '.join(sys.argv[1:])
        print(f"{CYAN}Processing command-line intent: '{intent_from_args}'{RESET}")
        build_custom_dork_from_intent(intent_from_args)
    else:
        # Otherwise, display the main menu for interactive use
        main_menu()


if __name__ == "__main__":
    main()
