#!/usr/bin/python3

import re
import subprocess
import sys
import requests
import os
# Terminal colors
CYAN = "\033[38;5;51m"
RESET = "\033[0m"

def ask_user(prompt):
    """Prompt the user for input and return the trimmed response."""
    return input(prompt + "\n> ").strip()

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
    
    Example Dork:
    inurl:"login" intext:"password" intitle:"admin" filetype:pdf site:example.com
    
    - Explanation: This dork searches for:
      - URLs containing "login".
      - Pages that mention "password" in the content.
      - Pages with "admin" in the title.
      - Files of type PDF.
      - Within the example.com domain.
    """
    # Use a pager to display the help text
    pager = os.getenv('PAGER', 'less')
    with subprocess.Popen(pager, stdin=subprocess.PIPE, shell=True) as proc:
        proc.stdin.write(help_text.encode('utf-8'))
        proc.stdin.close()
        proc.wait()

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
    return re.fullmatch(r'site:\S+\.\S+', site_string) is not None

def process_search_intent(intent):
    """
    Process the user's search intent, detecting and applying appropriate Google search operators.
    This function handles basic patterns such as 'after', 'before', and 'site'.
    """
    date_after = re.search(r'\bafter (\S+)\b', intent, re.IGNORECASE)
    date_before = re.search(r'\bbefore (\S+)\b', intent, re.IGNORECASE)

    if date_after and validate_date_format(date_after.group(1)):
        intent = re.sub(r'\bafter \S+\b', '', intent, flags=re.IGNORECASE)
        intent += f" after:{date_after.group(1)}"
    
    if date_before and validate_date_format(date_before.group(1)):
        intent = re.sub(r'\bbefore \S+\b', '', intent, flags=re.IGNORECASE)
        intent += f" before:{date_before.group(1)}"

    site = re.search(r'\bsite:(\S+)\b', intent, re.IGNORECASE)
    if site and validate_site_format(site.group(0)):
        intent = re.sub(r'\bsite:\S+\b', '', intent, flags=re.IGNORECASE)
        intent += f" site:{site.group(1)}"

    return intent.strip()

def probe_additional_parameters(intent):
    """
    Probe the user for additional search parameters such as date range, site limitation, file type,
    and exclusion criteria, then append these parameters to the search intent.
    """
    date_range = ask_user("Do you want to specify a date range? If yes, provide 'after' and/or 'before' dates (e.g., after 21.05.2023 or before 2023-05-21). If no, press Enter.")
    site = ask_user("Do you want to limit your search to a specific website? If yes, provide the site (e.g., site:nytimes.com). If no, press Enter.")
    filetype = ask_user("Are you looking for a specific file type (e.g., PDF)? If yes, specify the file type (e.g., filetype:pdf). If no, press Enter.")
    exclude = ask_user("Do you want to exclude any words from the search results? If yes, list them (e.g., -politics -economy). If no, press Enter.")
    
    if date_range and validate_date_format(date_range.split()[-1]):
        intent += " " + date_range
    if site and validate_site_format(site):
        intent += " " + site
    if filetype:
        intent += f" filetype:{filetype}"
    if exclude:
        intent += " " + exclude

    return intent.strip()

def copy_to_clipboard(text):
    """
    Copy the given text to the clipboard using wl-copy.
    """
    try:
        subprocess.run(['wl-copy'], input=text.encode('utf-8'), check=True)
        print("\nYour query has been copied to the clipboard.")
    except Exception as e:
        print(f"\nFailed to copy to clipboard: {e}")

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
    inurl = ask_user("Enter a path or parameter to look for in the URL (e.g., inurl:admin):")
    if inurl:
        dork_parts.append(f'inurl:"{inurl}"')

    # Prompt for intext operator
    intext = ask_user("Enter a string to search for within the page's content (e.g., intext:password):")
    if intext:
        dork_parts.append(f'intext:"{intext}"')

    # Prompt for intitle operator
    intitle = ask_user("Enter a string to search for within the page's title (e.g., intitle:login):")
    if intitle:
        dork_parts.append(f'intitle:"{intitle}"')

    # Prompt for filetype operator
    filetype = ask_user("Enter the file type you're searching for (e.g., filetype:pdf):")
    if filetype:
        dork_parts.append(f'filetype:{filetype}')

    # Prompt for site operator
    site = ask_user("Limit the search to a specific site (e.g., site:example.com):")
    if site:
        dork_parts.append(f'site:{site}')

    # Combine all parts
    google_dork = ' '.join(dork_parts)

    print("\nHere is your dork:")
    print(google_dork)

    # Copy the dork to the clipboard
    copy_to_clipboard(google_dork)

def fetch_predefined_dorks():
    """Fetch the predefined Google dorks from the provided URL."""
    url = "https://pastebin.com/raw/RFYt8U22"  # Direct link to the raw paste
    try:
        response = requests.get(url)
        response.raise_for_status()
        dorks = response.text.strip().splitlines()
        return dorks
    except Exception as e:
        print(f"\nFailed to fetch predefined dorks: {e}")
        return []

def select_predefined_dork(dorks):
    """Allow the user to select a predefined Google dork."""
    print("\nSelect a dork from the list below:\n")
    for i, dork in enumerate(dorks, start=1):
        print(f"{i}. {dork}")
    
    choice = ask_user("\nEnter the number of the dork you want to use:")
    try:
        index = int(choice) - 1
        if 0 <= index < len(dorks):
            selected_dork = dorks[index]
            print("\nHere is your selected dork:")
            print(selected_dork)
            copy_to_clipboard(selected_dork)
        else:
            print("Invalid choice. Please restart the program and select a valid number.")
    except ValueError:
        print("Invalid input. Please enter a number corresponding to the dork.")

def main():
    """
    Main function to interact with the user, process their search intent,
    build Google dorks, and provide an optimized search query.
    """
    while True:
        print(f"{CYAN}Searchmaster!{RESET}")
        print(f"({CYAN}1{RESET}) Optimize ({CYAN}2{RESET}) Build ({CYAN}3{RESET}) Choose ({CYAN}4{RESET}) Help")
        choice = ask_user(f"Enter {CYAN}1{RESET}, {CYAN}2{RESET}, {CYAN}3{RESET}, or {CYAN}4{RESET}:")

        if choice == '1':
            intent = handle_arguments() or ask_user("Describe your search query in plain English.")
            optimized_intent = process_search_intent(intent)
            final_query = probe_additional_parameters(optimized_intent)

            print("\nHere is your optimized search query:")
            print(f'"{final_query}"')

            copy_to_clipboard(final_query)

            print("\nExplanation:")
            print("Your query has been optimized with advanced search operators to improve the relevance of results.")
            print("You can use this query directly in your browser to perform your search.")
        elif choice == '2':
            build_google_dork()
        elif choice == '3':
            predefined_dorks = fetch_predefined_dorks()
            if predefined_dorks:
                select_predefined_dork(predefined_dorks)
            else:
                print("Could not fetch the predefined dorks. Please check your internet connection and try again.")
        elif choice == '4':
            display_help()
        else:
            print("Invalid choice. Please restart the program and choose 1, 2, 3, or 4.")

if __name__ == "__main__":
    main()
