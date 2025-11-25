def fetch_predefined_dorks() -> list[str]:
    """Fetches predefined Google dorks from a URL, with a local fallback."""
    try:
        print(f"{BLUE}Fetching predefined dorks from {CONFIG['PREDEFINED_DORKS_URL']}...{RESET}")
        response = requests.get(CONFIG["PREDEFINED_DORKS_URL"], timeout=10)
        response.raise_for_status()
        dorks = [d for d in response.text.strip().splitlines() if d]
        if dorks:
            print(f"{GREEN}Successfully fetched {len(dorks)} dorks.{RESET}")
            return dorks
    except requests.exceptions.RequestException as e:
        print(f"{RED}Failed to fetch predefined dorks: {e}{RESET}")
        log_message(f"Error fetching predefined dorks: {e}", "ERROR")

    print(f"{YELLOW}Using local fallback dorks instead.{RESET}")
    return LOCAL_FALLBACK_DORKS

def select_predefined_dork(dorks: list[str]) -> None:
    """Allows the user to select a predefined Google dork from a provided list."""
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
            print(f"\nHere is your selected dork:\n{GREEN}{selected_dork}{RESET}")
            copy_to_clipboard(selected_dork)
            _prompt_and_open_browser(selected_dork)
        else:
            print(f"{RED}Invalid choice.{RESET}")
    except ValueError:
        print(f"{RED}Invalid input. Please enter a number.{RESET}")

def build_custom_dork_from_intent(intent: str) -> None:
    """Builds a Google dork based on the user's plain English intent."""
    optimized_intent = process_search_intent(intent)
    final_query = probe_additional_parameters(optimized_intent)
    if not final_query:
        print(f"{YELLOW}No valid search parameters provided. Exiting.{RESET}")
        return

    print(f"\nHere is your optimized Google search query:\n{GREEN}{final_query}{RESET}")
    copy_to_clipboard(final_query)
    _prompt_and_open_browser(final_query)

# --- Automated 4chan Archive Automation Functions ---
class ThreadResult:
    """Represents a parsed thread from 4chan archive search results."""
    def __init__(self, thread_id: str, board: str, subject: str, post_excerpt: str, image_count: int, thread_url: str):
        self.thread_id = thread_id
        self.board = board
        self.subject = subject
        self.post_excerpt = post_excerpt
        self.image_count = image_count
        self.thread_url = thread_url
        self.external_links: list[str] = []
        self.passwords: list[str] = []

    def display(self, index: int = -1) -> None:
        """Prints the formatted thread information."""
        idx_str = f"[{index}] " if index != -1 else ""
        print(f"\n{CYAN}{idx_str}Thread ID: {self.thread_id}{RESET} ({BLUE}Board: /{self.board}/{RESET})")
        print(f"  Subject: {self.subject}")
        print(f"  Images: {self.image_count}")
        print(f"  Excerpt: {self.post_excerpt[:150]}...")
        print(f"  URL: {self.thread_url}")
        if self.external_links:
            print(f"  {GREEN}Detected External Links ({len(self.external_links)}):{RESET}")
            for i, link in enumerate(self.external_links):
                print(f"    - [{i+1}] {link}")
        if self.passwords:
            print(f"  {YELLOW}Detected Passwords ({len(self.passwords)}):{RESET}")
            for pwd in self.passwords:
                print(f"    - '{pwd}'")

def get_session() -> requests.Session:
    """Returns a requests session with a custom User-Agent."""
    session = requests.Session()
    session.headers.update({'User-Agent': CONFIG["USER_AGENT"]})
    return session

def perform_4plebs_search(
    session: requests.Session,
    board: str,
    keywords: str,
    date_from: str = "",
    date_to: str = "",
    exclude_terms: str = ""
) -> list[ThreadResult]:
    """Performs a search on 4plebs.org for the specified board and keywords."""
    search_url = f"{CONFIG['ARCHIVE_BASE_URL']}/{board}/search/"
    results: list[ThreadResult] = []

    full_query = f"{keywords} {' '.join([f'-{t}' for t in exclude_terms.split()])}".strip()
    payload = {'q': full_query, 'board': board, 'start': date_from, 'end': date_to, 'image_only': 'on'}

    print(f"{BLUE}Searching /{board}/ for '{full_query}'...{RESET}")
    try:
        response = session.post(search_url, data=payload, timeout=30)
        response.raise_for_status()
        time.sleep(CONFIG["REQUEST_DELAY_SECONDS"])

        soup = BeautifulSoup(response.text, 'lxml')
        threads = soup.find_all('div', class_='search_thread')

        if not threads:
            log_message(f"No threads found for query on /{board}/: {full_query}", "INFO")
            return []

        for thread_div in threads:
            thread_link_tag = thread_div.find('a', class_='thread_link')
            if not (thread_link_tag and thread_link_tag.has_attr('href')):
                continue
            
            thread_url = urljoin(CONFIG["ARCHIVE_BASE_URL"], thread_link_tag['href'])
            thread_id = re.search(r'thread/(\d+)', thread_url).group(1) if re.search(r'thread/(\d+)', thread_url) else "N/A"
            subject = (thread_div.find('span', class_='subject') or BeautifulSoup("<span>No Subject</span>", "lxml")).get_text(strip=True)
            post_excerpt = (thread_div.find('div', class_='text') or BeautifulSoup("<div>No excerpt.</div>", "lxml")).get_text(separator=' ', strip=True)
            
            image_count_tag = thread_div.find('span', class_='post_file_count')
            image_count = int(re.search(r'\[(\d+) Images\]', image_count_tag.get_text()).group(1)) if image_count_tag and re.search(r'\[(\d+) Images\]', image_count_tag.get_text()) else 0
            
            results.append(ThreadResult(thread_id, board, subject, post_excerpt, image_count, thread_url))
        return results

    except requests.exceptions.RequestException as e:
        print(f"{RED}Network error for /{board}/ search: {e}{RESET}")
        log_message(f"Network error for /{board}/ search: {e}", "ERROR")
    return []

def parse_thread_for_details(session: requests.Session, thread_result: ThreadResult) -> None:
    """Fetches a thread page and parses it for external links and passwords."""
    print(f"{BLUE}Investigating thread: {thread_result.thread_url}{RESET}")
    log_message(f"Investigating thread: {thread_result.thread_url}", "INFO")

    try:
        response = session.get(thread_result.thread_url, timeout=30)
        response.raise_for_status()
        time.sleep(CONFIG["REQUEST_DELAY_SECONDS"])
        soup = BeautifulSoup(response.text, 'lxml')
        
        patterns = {
            "mega": re.compile(r'https?://(?:www\.)?mega\.nz/(?:file|folder)/[a-zA-Z0-9_-]+(?:#.+)?', re.IGNORECASE),
            "gdrive": re.compile(r'https?://drive\.google\.com/(?:file/d/|open\?id=)[a-zA-Z0-9_-]+', re.IGNORECASE),
            "torrent": re.compile(r'magnet:\?xt=urn:[a-zA-Z0-9:]+', re.IGNORECASE),
            "direct_dl": re.compile(r'https?://[^\s"<>()]+?\.(?:zip|rar|7z|mp4|mkv|webm|jpg|png|gif|webp|pdf)(?:\?[^\s"<>()]*)?', re.IGNORECASE),
            "password_explicit": re.compile(r'(?:password|pass|pwd|key|decryption)\s*[:=]\s*([a-zA-Z0-9!@#$%^&*()_+=\-{}\[\]|;:\'",.<>/?`~]+)', re.IGNORECASE),
            "password_generic": re.compile(r'(?:pass|pwd|key)\s*(?:is|:)\s*(\S+)', re.IGNORECASE)
        }
        
        post_content_divs = soup.find_all('div', class_=['op', 'post_text'])
        for post_tag in post_content_divs:
            post_content = post_tag.get_text(separator=' ', strip=True)
            
            for link_type in ["mega", "gdrive", "torrent", "direct_dl"]:
                for link in patterns[link_type].findall(post_content):
                    cleaned_link = re.sub(r'[\.,;\'"]+$', '', link)
                    if cleaned_link not in thread_result.external_links:
                        thread_result.external_links.append(cleaned_link)
            
            for pass_type in ["password_explicit", "password_generic"]:
                for pwd in patterns[pass_type].findall(post_content):
                    if len(pwd) > 3 and "protected" not in pwd.lower() and "required" not in pwd.lower() and pwd not in thread_result.passwords:
                        thread_result.passwords.append(pwd)

        if not thread_result.external_links and not thread_result.passwords:
            print(f"{YELLOW}No explicit external links or passwords detected in thread {thread_result.thread_id}.{RESET}")

    except requests.exceptions.RequestException as e:
        print(f"{RED}Network error for {thread_result.thread_url}: {e}{RESET}")
        log_message(f"Network error parsing {thread_result.thread_url}: {e}", "ERROR")

def manage_download_or_instruction(link: str, password: str = None) -> None:
    """Provides detailed instructions or attempts direct download for a given link."""
    print(f"\n{BLUE}--- Managing Link: {link} ---{RESET}")
    print(f"**{RED}CRITICAL SECURITY WARNINGS:{RESET}**")
    print(f"**1. ALWAYS use a {YELLOW}VPN or Tor Browser{RESET} for anonymity.**")
    print(f"**2. Consider using a {YELLOW}Virtual Machine (VM){RESET} to isolate downloads.**")
    print(f"**3. Comply with your local laws regarding content acquisition.**")

    link_type = "Unknown"
    if "mega.nz" in link: link_type = "Mega.nz"
    elif "drive.google.com" in link: link_type = "Google Drive"
    elif "magnet:?" in link: link_type = "Torrent/Magnet"
    elif any(ext in link.lower() for ext in ['.zip', '.rar', '.7z', '.mp4', '.mkv', '.pdf']): link_type = "Direct File Link"

    print(f"\nDetected Link Type: {CYAN}{link_type}{RESET}")
    if password: print(f"**{YELLOW}Associated Password:{RESET} '{password}'**")

    if link_type == "Mega.nz":
        print(f"\n{GREEN}Recommended:{RESET} Use `megadl` (megatools) command-line client.")
        print(f"    {GREEN}Example: `megadl '{link}' --path='{CONFIG['DOWNLOAD_DIR']}'`{RESET}")
    elif link_type == "Google Drive":
        print(f"\n{GREEN}Browser Recommended:{RESET} Copy the link and paste it into your (Tor) browser.")
    elif link_type == "Torrent/Magnet":
        print(f"\n{GREEN}Use a Torrent Client:{RESET} Copy the magnet link and add it to your client (e.g., qBittorrent).")
    elif link_type == "Direct File Link":
        if ask_user(f"Attempt direct download to '{CONFIG['DOWNLOAD_DIR']}'? (y/n):").lower() == 'y':
            try:
                print(f"{BLUE}Attempting direct download...{RESET}")
                file_name = os.path.basename(urlparse(link).path)
                file_path = os.path.join(CONFIG["DOWNLOAD_DIR"], file_name)
                with get_session().get(link, stream=True, timeout=60) as r:
                    r.raise_for_status()
                    total_size = int(r.headers.get('content-length', 0))
                    with open(file_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=8192): f.write(chunk)
                print(f"\n{GREEN}Downloaded: {file_name} to {CONFIG['DOWNLOAD_DIR']}{RESET}")
                if file_name.lower().endswith(('.zip', '.rar', '.7z')) and password:
                    print(f"{YELLOW}This is a password-protected archive. Use the password: '{password}'{RESET}")
            except requests.exceptions.RequestException as e:
                print(f"{RED}Failed to download: {e}{RESET}")
    else:
        print(f"\n{GREEN}Browser Recommended:{RESET} Copy the link and paste it into your (Tor) browser for manual inspection.")

    print(f"\n{BLUE}Link copied to clipboard.{RESET}")
    copy_to_clipboard(link)

def automated_4chan_archive_search() -> None:
    """Automates searching 4plebs.org, displays results, and allows interactive investigation."""
    print(f"\n### {CYAN}Automated 4chan Archive Search (Powered by Ψ-4ndr0){RESET} ###")
    print(f"{RED}!!! DISCLAIMER: You are responsible for your actions. Use strong OpSec (VPN, Tor, VM). !!!{RESET}")

    boards_input = ask_user("Which board(s) do you want to search (e.g., s, gif, hr)? Separate with commas.")
    if not boards_input:
        print(f"{YELLOW}Board selection is required. Aborting.{RESET}")
        return
    boards = [b.strip().lower().replace('/', '') for b in boards_input.split(',')]

    keywords = ask_user("Enter primary search keywords (e.g., 'celebrity name', 'dump', 'mega', 'UHD'):")
    if not keywords:
        print(f"{YELLOW}Keywords are required. Aborting.{RESET}")
        return

    date_from = ask_user("Optional: 'From' date (YYYY-MM-DD):")
    date_to = ask_user("Optional: 'To' date (YYYY-MM-DD):")
    exclude_terms = ask_user("Optional: Exclude words (e.g., 'AI fakes'):")

    all_threads: list[ThreadResult] = []
    session = get_session()
    for board in boards:
        found_threads = perform_4plebs_search(session, board, keywords, date_from, date_to, exclude_terms)
        all_threads.extend(found_threads)
        if found_threads:
            print(f"{GREEN}Found {len(found_threads)} threads on /{board}/.{RESET}")
        else:
            print(f"{YELLOW}No threads found on /{board}/.{RESET}")
    
    if not all_threads:
        print(f"\n{YELLOW}No relevant dump threads found matching your criteria across all searched boards.{RESET}")
        return

    all_threads.sort(key=lambda x: x.image_count, reverse=True)
    print(f"\n{GREEN}--- Found {len(all_threads)} total potential dump threads (sorted by image count) ---{RESET}")
    for i, thread in enumerate(all_threads):
        thread.display(i + 1)
        print("-" * 50)

    while True:
        action_choice = ask_user(f"\nEnter a thread number to {CYAN}[I]nvestigate{RESET} or {CYAN}[O]pen in browser{RESET}. Type {CYAN}[B]ack{RESET} to return to main menu:")
        if action_choice.lower() == 'b':
            break
        try:
            is_open_action = action_choice.lower() == 'o'
            if is_open_action:
                thread_num_str = ask_user("Enter thread number to open:")
                idx = int(thread_num_str) - 1
            else: # Investigate action
                idx = int(action_choice) - 1

            if not (0 <= idx < len(all_threads)):
                print(f"{RED}Invalid thread number.{RESET}")
                continue

            selected_thread = all_threads[idx]
            if is_open_action:
                print(f"{BLUE}Opening {selected_thread.thread_url} in your default browser...{RESET}")
                webbrowser.open(selected_thread.thread_url)
                continue

            # Investigation logic
            parse_thread_for_details(session, selected_thread)
            selected_thread.display(idx + 1)

            if selected_thread.external_links:
                if ask_user(f"Manage a link from this thread? (y/n)").lower() == 'y':
                    for i, link in enumerate(selected_thread.external_links): print(f"  [{i+1}] {link}")
                    link_choice = ask_user("Enter the number of the link to manage:")
                    link_idx = int(link_choice) - 1
                    if 0 <= link_idx < len(selected_thread.external_links):
                        password_to_use = selected_thread.passwords[0] if selected_thread.passwords else None
                        manage_download_or_instruction(selected_thread.external_links[link_idx], password_to_use)
                    else:
                        print(f"{RED}Invalid link number.{RESET}")

        except ValueError:
            print(f"{RED}Invalid input. Please enter a number, 'o', or 'b'.{RESET}")

def main_menu() -> None:
    """Displays the main menu and handles user choices."""
    while True:
        print(f"\n{CYAN}--- Searchmaster v1.1.0 (Ψ-4ndr0) ---{RESET}")
        print("(1) Optimize Google Search Intent (Plain English)")
        print("(2) Build Custom Google Dork (Step-by-step)")
        print("(3) Choose Predefined Google Dork")
        print("(4) Automated 4chan Archive Search")
        print("(5) Help & Operational Details")
        print("(6) Exit")
        choice = ask_user("Enter your choice (1-6):")

        if choice == '1':
            intent = ask_user("Describe your Google search query in plain English:")
            build_custom_dork_from_intent(intent)
        elif choice == '2':
            build_google_dork()
        elif choice == '3':
            predefined_dorks = fetch_predefined_dorks()
            select_predefined_dork(predefined_dorks)
        elif choice == '4':
            automated_4chan_archive_search()
        elif choice == '5':
            display_help()
        elif choice == '6':
            print(f"{BLUE}Exiting Searchmaster. Goodbye!{RESET}")
            sys.exit(0)
        else:
            print(f"{RED}Invalid choice.{RESET}")

def main() -> None:
    """Main function to run the Searchmaster tool."""
    log_message("Searchmaster started.", "INFO")
    if len(sys.argv) > 1:
        intent_from_args = ' '.join(sys.argv[1:])
        print(f"{CYAN}Processing command-line intent: '{intent_from_args}'{RESET}")
        build_custom_dork_from_intent(intent_from_args)
    else:
        main_menu()

if __name__ == "__main__":
    main()
