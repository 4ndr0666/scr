#!/usr/bin/env python3

import re
import subprocess
import sys
import requests
import os
import shutil
import json

# Terminal colors
CYAN = "\033[38;5;51m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
RESET = "\033[0m"

# Constants
PREDEFINED_DORKS_URL = "https://pastebin.com/raw/RFYt8U22"  # Replace with your actual URL
LOG_FILE = os.path.expanduser("~/.searchmaster.log")

def log_message(message):
    """Log messages to a file."""
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{message}\n")

def ask_user(prompt):
    """Prompt the user for input and return the trimmed response."""
    try:
        return input(f"{prompt}\n> ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\nOperation cancelled by user.")
        sys.exit(0)

def display_help():
    """Display the help information for building a Google dork using a pager."""
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
    # Use a pager to display the help text
    pager = os.getenv('PAGER', 'less')
    try:
        with subprocess.Popen(pager, stdin=subprocess.PIPE, shell=True) as proc:
            proc.stdin.write(help_text.encode('utf-8'))
            proc.stdin.close()
            proc.wait()
    except Exception as e:
        print(f"{RED}Failed to display help: {e}{RESET}")

def validate_date_format(date_string):
    """Validate the date string to ensure it matches expected formats."""
    date_formats = [
        r'\d{2}\.\d{2}\.\d{4}',  # DD.MM.YYYY
        r'\d{4}-\d{2}-\d{2}',    # YYYY-MM-DD
        r'\d{2}/\d{2}/\d{4}'     # MM/DD/YYYY
    ]
    return any(re.fullmatch(fmt, date_string) for fmt in date_formats)

def validate_site_format(site_string):
    """Validate that the site format matches a proper domain name."""
    return re.fullmatch(r'(?:site:)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}', site_string) is not None

def process_search_intent(intent):
    """
    Process the user's search intent, detecting and applying appropriate Google search operators.
    This function handles basic patterns such as 'after', 'before', and 'site'.
    """
    date_after = re.findall(r'\bafter\s+(\S+)', intent, re.IGNORECASE)
    date_before = re.findall(r'\bbefore\s+(\S+)', intent, re.IGNORECASE)
    site = re.findall(r'\bsite:(\S+)', intent, re.IGNORECASE)

    operators = []

    if date_after:
        for date in date_after:
            if validate_date_format(date):
                operators.append(f"after:{date}")
            else:
                print(f"{YELLOW}Warning: Invalid date format for 'after': {date}{RESET}")

    if date_before:
        for date in date_before:
            if validate_date_format(date):
                operators.append(f"before:{date}")
            else:
                print(f"{YELLOW}Warning: Invalid date format for 'before': {date}{RESET}")

    if site:
        for s in site:
            if validate_site_format(s):
                operators.append(f"site:{s}")
            else:
                print(f"{YELLOW}Warning: Invalid site format: {s}{RESET}")

    # Remove the processed parts from intent
    intent = re.sub(r'\b(after|before)\s+\S+\b', '', intent, flags=re.IGNORECASE)
    intent = re.sub(r'\bsite:\S+\b', '', intent, flags=re.IGNORECASE)

    final_intent = ' '.join(operators + [intent]).strip()
    return final_intent

def probe_additional_parameters(intent):
    """
    Probe the user for additional search parameters such as date range, site limitation, file type,
    and exclusion criteria, then append these parameters to the search intent.
    """
    print("\n### Additional Search Parameters ###\n")
    date_range = ask_user("Do you want to specify a date range? If yes, provide 'after' and/or 'before' dates (e.g., after 21.05.2023 or before 2023-05-21). If no, press Enter.")
    site = ask_user("Do you want to limit your search to a specific website? If yes, provide the site (e.g., site:nytimes.com). If no, press Enter.")
    filetype = ask_user("Are you looking for a specific file type (e.g., PDF)? If yes, specify the file type (e.g., pdf). If no, press Enter.")
    exclude = ask_user("Do you want to exclude any words from the search results? If yes, list them separated by spaces (e.g., politics economy). If no, press Enter.")

    if date_range:
        # Extract after and before dates
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
        if validate_site_format(site):
            intent += f" site:{site}"
        else:
            print(f"{YELLOW}Warning: Invalid site format: {site}{RESET}")

    if filetype:
        # Validate filetype (basic validation)
        if re.fullmatch(r'[a-zA-Z0-9]+', filetype):
            intent += f" filetype:{filetype}"
        else:
            print(f"{YELLOW}Warning: Invalid filetype format: {filetype}{RESET}")

    if exclude:
        # Prefix each word with '-'
        excluded_terms = ' '.join([f"-{term}" for term in exclude.split()])
        intent += f" {excluded_terms}"

    return intent.strip()

def copy_to_clipboard(text):
    """
    Copy the given text to the clipboard using available tools.
    Supports wl-copy, xclip, and pbcopy.
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
    except Exception as e:
        print(f"\n{RED}❌  Failed to copy to clipboard: {e}{RESET}")

def handle_arguments():
    """Handle command-line arguments for flexibility in usage."""
    if len(sys.argv) > 1:
        return ' '.join(sys.argv[1:])
    return None

def build_google_dork():
    """Prompt the user to build a Google dork using common operators."""
    print("\nLet's build a dork using available search operators.\n")
    dork_parts = []

    # Prompt for inurl operator
    inurl = ask_user("Enter a path or parameter to look for in the URL (e.g., admin). If none, press Enter:")
    if inurl:
        dork_parts.append(f'inurl:"{inurl}"')

    # Prompt for allinurl operator
    allinurl = ask_user("Enter multiple terms to look for in the URL (separated by spaces). If none, press Enter:")
    if allinurl:
        dork_parts.append(f'allinurl:"{" ".join(allinurl.split())}"')

    # Prompt for intext operator
    intext = ask_user("Enter a string to search for within the page's content (e.g., password). If none, press Enter:")
    if intext:
        dork_parts.append(f'intext:"{intext}"')

    # Prompt for allintext operator
    allintext = ask_user("Enter multiple terms to search for within the page's content (separated by spaces). If none, press Enter:")
    if allintext:
        dork_parts.append(f'allintext:"{" ".join(allintext.split())}"')

    # Prompt for intitle operator
    intitle = ask_user("Enter a string to search for within the page's title (e.g., login). If none, press Enter:")
    if intitle:
        dork_parts.append(f'intitle:"{intitle}"')

    # Prompt for allintitle operator
    allintitle = ask_user("Enter multiple terms to search for within the page's title (separated by spaces). If none, press Enter:")
    if allintitle:
        dork_parts.append(f'allintitle:"{" ".join(allintitle.split())}"')

    # Prompt for inanchor operator
    inanchor = ask_user("Enter a string to search for within the page's anchor text (e.g., download). If none, press Enter:")
    if inanchor:
        dork_parts.append(f'inanchor:"{inanchor}"')

    # Prompt for allinanchor operator
    allinanchor = ask_user("Enter multiple terms to search for within the page's anchor text (separated by spaces). If none, press Enter:")
    if allinanchor:
        dork_parts.append(f'allinanchor:"{" ".join(allinanchor.split())}"')

    # Prompt for filetype operator
    filetype = ask_user("Enter the file type you're searching for (e.g., pdf). If none, press Enter:")
    if filetype:
        dork_parts.append(f'filetype:{filetype}')

    # Prompt for site operator
    site = ask_user("Limit the search to a specific site (e.g., example.com). If none, press Enter:")
    if site:
        if not site.startswith("site:"):
            site = f"site:{site}"
        if validate_site_format(site):
            dork_parts.append(site)
        else:
            print(f"{YELLOW}Warning: Invalid site format: {site}{RESET}")

    # Prompt for define operator
    define = ask_user("Enter a term to define (e.g., Python). If none, press Enter:")
    if define:
        dork_parts.append(f'define:{define}')

    # Prompt for link operator
    link = ask_user("Enter a URL to find pages linking to it (e.g., example.com). If none, press Enter:")
    if link:
        dork_parts.append(f'link:{link}')

    # Prompt for related operator
    related = ask_user("Enter a URL to find pages related to it (e.g., example.com). If none, press Enter:")
    if related:
        dork_parts.append(f'related:{related}')

    # Prompt for cache operator
    cache = ask_user("Enter a URL to view Google's cached version (e.g., example.com). If none, press Enter:")
    if cache:
        dork_parts.append(f'cache:{cache}')

    # Combine all parts
    google_dork = ' '.join(dork_parts)

    if not google_dork:
        print(f"{YELLOW}No operators selected. Exiting dork builder.{RESET}")
        return

    print("\nHere is your dork:")
    print(f"{GREEN}{google_dork}{RESET}")

    # Copy the dork to the clipboard
    copy_to_clipboard(google_dork)

    # Optionally, open the search in the default web browser
    open_browser = ask_user("Do you want to perform the search in your default web browser? (y/n):")
    if open_browser.lower() == 'y':
        try:
            import webbrowser
            webbrowser.open(f"https://www.google.com/search?q={google_dork}")
            print(f"{GREEN}Opened search in your default web browser.{RESET}")
        except Exception as e:
            print(f"{RED}Failed to open web browser: {e}{RESET}")

def fetch_predefined_dorks():
    """Fetch the predefined Google dorks from the provided URL."""
    try:
        response = requests.get(PREDEFINED_DORKS_URL, timeout=10)
        response.raise_for_status()
        dorks = response.text.strip().splitlines()
        if not dorks:
            print(f"{YELLOW}No predefined dorks found at the provided URL.{RESET}")
        return dorks
    except requests.exceptions.RequestException as e:
        print(f"{RED}Failed to fetch predefined dorks: {e}{RESET}")
        log_message(f"Error fetching predefined dorks: {e}")
        return []

def select_predefined_dork(dorks):
    """Allow the user to select a predefined Google dork."""
    if not dorks:
        print(f"{YELLOW}No predefined dorks available.{RESET}")
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

            # Optionally, open the search in the default web browser
            open_browser = ask_user("Do you want to perform the search in your default web browser? (y/n):")
            if open_browser.lower() == 'y':
                try:
                    import webbrowser
                    webbrowser.open(f"https://www.google.com/search?q={selected_dork}")
                    print(f"{GREEN}Opened search in your default web browser.{RESET}")
                except Exception as e:
                    print(f"{RED}Failed to open web browser: {e}{RESET}")
        else:
            print(f"{RED}Invalid choice. Please restart the program and select a valid number.{RESET}")
    except ValueError:
        print(f"{RED}Invalid input. Please enter a number corresponding to the dork.{RESET}")

def fetch_additional_dorks():
    """Fetch additional predefined dorks from another source or local file."""
    # Placeholder for fetching from another source
    # You can add more sources or local dorks as needed
    return []

def build_custom_dork_from_intent(intent):
    """Build a Google dork based on user's plain English intent."""
    optimized_intent = process_search_intent(intent)
    final_query = probe_additional_parameters(optimized_intent)

    if not final_query:
        print(f"{YELLOW}No valid search parameters provided. Exiting.{RESET}")
        return

    print("\nHere is your optimized search query:")
    print(f"{GREEN}{final_query}{RESET}")

    # Copy the dork to the clipboard
    copy_to_clipboard(final_query)

    # Optionally, open the search in the default web browser
    open_browser = ask_user("Do you want to perform the search in your default web browser? (y/n):")
    if open_browser.lower() == 'y':
        try:
            import webbrowser
            webbrowser.open(f"https://www.google.com/search?q={final_query}")
            print(f"{GREEN}Opened search in your default web browser.{RESET}")
        except Exception as e:
            print(f"{RED}Failed to open web browser: {e}{RESET}")

def build_dork_from_arguments():
    """Build a Google dork based on command-line arguments."""
    intent = handle_arguments()
    if not intent:
        print(f"{RED}No search intent provided via command-line arguments.{RESET}")
        sys.exit(1)

    optimized_intent = process_search_intent(intent)
    final_query = probe_additional_parameters(optimized_intent)

    if not final_query:
        print(f"{YELLOW}No valid search parameters provided. Exiting.{RESET}")
        sys.exit(1)

    print("\nHere is your optimized search query:")
    print(f"{GREEN}{final_query}{RESET}")

    # Copy the dork to the clipboard
    copy_to_clipboard(final_query)

    # Optionally, open the search in the default web browser
    open_browser = ask_user("Do you want to perform the search in your default web browser? (y/n):")
    if open_browser.lower() == 'y':
        try:
            import webbrowser
            webbrowser.open(f"https://www.google.com/search?q={final_query}")
            print(f"{GREEN}Opened search in your default web browser.{RESET}")
        except Exception as e:
            print(f"{RED}Failed to open web browser: {e}{RESET}")

def main_menu():
    """
    Display the main menu and handle user choices.
    """
    while True:
        print(f"\n{CYAN}Searchmaster!{RESET}")
        print(f"({CYAN}1{RESET}) Optimize Search Intent")
        print(f"({CYAN}2{RESET}) Build Custom Dork")
        print(f"({CYAN}3{RESET}) Choose Predefined Dork")
        print(f"({CYAN}4{RESET}) Help")
        print(f"({CYAN}5{RESET}) Exit")
        choice = ask_user(f"\nEnter {CYAN}1{RESET}, {CYAN}2{RESET}, {CYAN}3{RESET}, {CYAN}4{RESET}, or {CYAN}5{RESET}:")

        if choice == '1':
            intent = handle_arguments() or ask_user("Describe your search query in plain English.")
            build_custom_dork_from_intent(intent)
        elif choice == '2':
            build_google_dork()
        elif choice == '3':
            predefined_dorks = fetch_predefined_dorks()
            if predefined_dorks:
                select_predefined_dork(predefined_dorks)
            else:
                print(f"{YELLOW}Could not fetch the predefined dorks. Please check your internet connection and try again.{RESET}")
        elif choice == '4':
            display_help()
        elif choice == '5':
            print(f"{BLUE}Exiting Searchmaster. Goodbye!{RESET}")
            sys.exit(0)
        else:
            print(f"{RED}Invalid choice. Please choose a valid option.{RESET}")

def main():
    """
    Main function to interact with the user, process their search intent,
    build Google dorks, and provide an optimized search query.
    """
    # If arguments are provided, build dork from arguments
    if len(sys.argv) > 1:
        build_dork_from_arguments()
    else:
        main_menu()

if __name__ == "__main__":
    main()
