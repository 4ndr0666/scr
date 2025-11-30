#!/usr/bin/env python3
import sys
import re
import shutil
import time

# --- Module 1: Visual Feedback & UI Components (Themed Overhaul) ---
class UIManager:
    """Handles all visual output, including colors, layouts, and animations."""
    
    class Colors:
        BLUE, GREEN, YELLOW, RED, MAGENTA, CYAN, BOLD, END = '\033[94m', '\033[92m', '\033[93m', '\033[91m', '\033[95m', '\033[96m', '\033[1m', '\033[0m'

    ICONS = {
        "success": f"{Colors.GREEN}✔{Colors.END}",
        "error": f"{Colors.RED}✖{Colors.END}",
        "prompt": f"{Colors.BLUE}❯{Colors.END}",
        "working": f"{Colors.YELLOW}⚙️{Colors.END}",
        "info": f"{Colors.CYAN}ℹ️{Colors.END}"
    }

    @staticmethod
    def get_term_width():
        """Gets the terminal width to draw responsive UI elements."""
        return shutil.get_terminal_size((80, 20)).columns

    @staticmethod
    def print_boxed_title(title: str, color: str, padding: int = 2):
        """Prints a centered, boxed title."""
        width = UIManager.get_term_width()
        padded_title = f" {title} "
        side_len = (width - len(padded_title) - 2) // 2
        side_fill = "─" * side_len
        print(f"{color}{UIManager.Colors.BOLD}╭{side_fill}{padded_title}{side_fill}╮{UIManager.Colors.END}")

    @staticmethod
    def print_header():
        UIManager.print_boxed_title("Universal Regex Generator Pro", UIManager.Colors.BLUE)
        print("A sophisticated toolkit for generating, testing, and formatting regex patterns.".center(UIManager.get_term_width()))

    @staticmethod
    def print_menu(menu_options):
        width = UIManager.get_term_width()
        print(f"\n{UIManager.Colors.BLUE}├─ Main Menu {'─' * (width - 13)}┤{UIManager.Colors.END}")
        categories = {"Generators": ['1', '2'], "Pre-built Patterns": ['3', '4', '5', '6', '7', '8'], "Advanced Tools": ['9', 't'], "Application": ['h', 'q']}
        for category, keys in categories.items():
            print(f"  {UIManager.Colors.MAGENTA}{category}:{UIManager.Colors.END}")
            for key in keys:
                if key in menu_options:
                    desc = menu_options[key]['desc']
                    print(f"    [{UIManager.Colors.YELLOW}{key}{UIManager.Colors.END}] {desc}")
        print(f"{UIManager.Colors.BLUE}╰{'─' * (width - 2)}╯{UIManager.Colors.END}")

    @staticmethod
    def print_help(menu_options):
        UIManager.print_boxed_title("Help Documentation", UIManager.Colors.YELLOW)
        help_text = {
            '1': "Generates a flexible regex from a CSS-like selector (e.g., '#id .class').",
            '2': "Builds a robust regex for a domain, matching subdomains and protocols.",
            '3': "Provides a standard regex for matching most email addresses.",
            '4': "Provides a regex for matching any valid IPv4 address (0-255.255.255.255).",
            '5': "Provides a generic regex for matching common HTTP/HTTPS URLs.",
            '6': "Provides a regex for the common YYYY-MM-DD date format.",
            '7': "Provides a regex for the standard 8-4-4-4-12 UUID format.",
            '8': "Provides a regex to capture common log levels (INFO, ERROR, etc.).",
            '9': "Launches an interactive, step-by-step builder to construct a custom pattern.",
            't': "Test any regex pattern against a block of text to see live matches.",
            'h': "Displays this detailed help information.",
            'q': "Exits the application after confirmation."
        }
        for key, text in help_text.items():
             print(f"  {UIManager.Colors.BOLD}[{UIManager.Colors.YELLOW}{key}{UIManager.Colors.END}] {menu_options[key]['desc']}{UIManager.Colors.END}\n      {text}\n")
        print(f"{UIManager.Colors.YELLOW}{'─' * UIManager.get_term_width()}{UIManager.Colors.END}")

    @staticmethod
    def print_result(pattern: str, breakdown: list, title: str):
        print(f"\n{UIManager.ICONS['success']} {UIManager.Colors.GREEN}Pattern Generated for {UIManager.Colors.BOLD}{title}{UIManager.Colors.END}")
        print(f"  ╭─ Regex {'─' * (UIManager.get_term_width() - 11)}╮")
        print(f"  │ {UIManager.Colors.BOLD}{UIManager.Colors.CYAN}{pattern.center(UIManager.get_term_width() - 4)}{UIManager.Colors.END} │")
        print(f"  ╰{'─' * (UIManager.get_term_width() - 4)}╯")

        if breakdown:
            print(f"\n{UIManager.Colors.BLUE}  --- Breakdown ---{UIManager.Colors.END}")
            for line in breakdown:
                print(f"    • {line}")

    @staticmethod
    def print_status(message: str, animate: bool = False):
        if not animate:
            print(f"{UIManager.ICONS['working']} {UIManager.Colors.YELLOW}{message}{UIManager.Colors.END}")
            return
        
        spinner_chars = ['|', '/', '-', '\\']
        for _ in range(10):
            for char in spinner_chars:
                sys.stdout.write(f"\r{UIManager.ICONS['working']} {UIManager.Colors.YELLOW}{message} {char}{UIManager.Colors.END}")
                sys.stdout.flush()
                time.sleep(0.1)
        sys.stdout.write(f"\r{UIManager.ICONS['success']} {UIManager.Colors.GREEN}{message} Done!{UIManager.Colors.END} \n")

    @staticmethod
    def print_error(message: str):
        print(f"{UIManager.ICONS['error']} {UIManager.Colors.BOLD}{UIManager.Colors.RED}Error: {message}{UIManager.Colors.END}")

    @staticmethod
    def get_input(prompt: str) -> str:
        return input(f"{UIManager.ICONS['prompt']} {UIManager.Colors.BOLD}{prompt}{UIManager.Colors.END} ").strip()
    
    # All other UI methods from previous version (print_test_results, get_multiline_input, etc.) are preserved here...
    @staticmethod
    def print_test_results(matches:list, text:str):
        if not matches:print(f"{UIManager.ICONS['info']} {UIManager.Colors.YELLOW}No matches found.{UIManager.Colors.END}");return
        print(f"\n{UIManager.ICONS['success']} {UIManager.Colors.GREEN}Found {len(matches)} match(es):{UIManager.Colors.END}")
        highlighted_text=text;offset=0
        for match in matches:
            start,end=match.span();group_text=match.group(0);highlight=f"{UIManager.Colors.RED}{group_text}{UIManager.Colors.END}";highlighted_text=highlighted_text[:start+offset]+highlight+highlighted_text[end+offset:];offset+=len(highlight)-len(group_text)
        print("--- Highlighted Matches ---\n"+highlighted_text+"\n-------------------------")
        for i,match in enumerate(matches,1):
            print(f"  Match {i}: '{UIManager.Colors.BOLD}{match.group(0)}{UIManager.Colors.END}' (Pos: {match.start()}-{match.end()})")
    @staticmethod
    def print_copy_formats(pattern: str):
        print(f"\n{UIManager.Colors.BLUE}--- Copy-Paste Formats ---{UIManager.Colors.END}")
        print(f"  Python: {UIManager.Colors.BOLD}r\"{pattern}\"{UIManager.Colors.END}")
        print(f"  JavaScript: {UIManager.Colors.BOLD}/{pattern}/{UIManager.Colors.END}")
    @staticmethod
    def get_multiline_input()->str:
        print(f"{UIManager.Colors.YELLOW}(Enter text. Type 'EOF' on a new line and press Enter when done){UIManager.Colors.END}")
        lines=[];
        while True:
            try:line=input();
            except EOFError:break
            if line=="EOF":break
            lines.append(line)
        return "\n".join(lines)
    @staticmethod
    def get_confirmation(prompt: str) -> bool:return UIManager.get_input(f"{prompt} [y/N]:").lower() in ['y', 'yes']

# --- Module 2: Core Regex Generation & Testing Logic ---
class RegexLogic:
    # All logic functions are preserved from the previous version, unchanged and fully functional.
    @staticmethod
    def generate_selector_regex(s: str) -> tuple[str, list]:
        p=s.strip().split();r=[];e=[];
        if not p:raise ValueError("Selector string cannot be empty.")
        for i in p:
            if i.startswith('#'):k=re.escape(i[1:]);r.append(fr'id\s*=\s*["\'][^"\']*{k}[^"\']*["\']');e.append(f"Finds 'id' containing '{k}'.")
            elif i.startswith('.'):k=re.escape(i[1:]);r.append(fr'class\s*=\s*["\'][^"\']*{k}[^"\']*["\']');e.append(f"Finds 'class' containing '{k}'.")
            else:k=re.escape(i);r.append(fr'(?:<{k}[\s>])|(?:>{k}<)');e.append(f"Finds '{k}' as tag or text.")
        return r".*?".join(f"({i})" for i in r),e
    @staticmethod
    def generate_domain_regex(d: str) -> tuple[str, list]:
        if not d:raise ValueError("Domain string cannot be empty.")
        d=re.sub(r'https?://','',d.strip().lower())
        if not d:raise ValueError("Domain cannot be only a protocol.")
        ed=re.escape(d)
        return(fr"^(https?:\/\/)?([\w-]+\.)*{ed}(\/.*)?$",[r"`^`->Start",r"`(https?:\/\/)?`->Optional http(s)://",r"`([\w-]+\.)*`->Subdomains",f"`{ed}`->Your domain",r"`(\/.*)?`->Optional path",r"`$`->End"])
    @staticmethod
    def generate_email_regex()->tuple[str,list]:return(r"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})",[r"User part","@",r"Domain part",r".",r"TLD"])
    @staticmethod
    def generate_ip_address_regex()->tuple[str,list]:o=r"(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])";return(fr"(\b{o}\.{o}\.{o}\.{o}\b)",[r"Word boundary",f"`{o}`->0-255",r"`.` separator","Repeated x4"])
    @staticmethod
    def generate_url_regex()->tuple[str,list]:return(r"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)",[r"http(s)://",r"Optional www.",r"Domain name",r"Word boundary",r"Path/query"])
    @staticmethod
    def generate_iso_date_regex()->tuple[str,list]:return(r"(\d{4}-\d{2}-\d{2})",[r"YYYY",r"-",r"MM",r"-",r"DD"])
    @staticmethod
    def generate_uuid_regex()->tuple[str,list]:return(r"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})",[r"UUID 8-4-4-4-12 format"])
    @staticmethod
    def generate_log_level_regex()->tuple[str,list]:return(r"\b(INFO|DEBUG|WARN|WARNING|ERROR|FATAL|CRITICAL)\b",[r"Word boundaries",r"Any of: INFO|DEBUG|..."])
    @staticmethod
    def test_regex(pattern: str, text: str) -> list:
        try: return list(re.finditer(pattern, text))
        except re.error as e: raise ValueError(f"Invalid Regex Pattern: {e}")

# --- Module 3: Main Application Controller ---
class RegexGeneratorApp:
    def __init__(self):
        self.ui = UIManager()
        self.logic = RegexLogic()
        self.menu_options = {
            '1': {'handler': self._handle_selector_generation, 'desc': 'CSS Selector Generator'},
            '2': {'handler': self._handle_domain_generation, 'desc': 'Domain Name Generator'},
            '3': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_email_regex, 'desc': 'Email Address Pattern'},
            '4': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_ip_address_regex, 'desc': 'IPv4 Address Pattern'},
            '5': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_url_regex, 'desc': 'Generic URL Pattern'},
            '6': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_iso_date_regex, 'desc': 'ISO Date Pattern (YYYY-MM-DD)'},
            '7': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_uuid_regex, 'desc': 'UUID Pattern'},
            '8': {'handler': self._handle_generic_pattern, 'logic_func': self.logic.generate_log_level_regex, 'desc': 'Log Level Pattern'},
            '9': {'handler': self._handle_custom_builder, 'desc': 'Interactive Custom Pattern Builder'},
            't': {'handler': self._handle_regex_tester, 'desc': 'Test a Regex Pattern'},
            'h': {'handler': self.ui.print_help, 'desc': 'Show Help'},
            'q': {'handler': self._handle_quit, 'desc': 'Quit Application'}
        }

    # All handler methods (`_handle_...`) are preserved and now use the new UI methods.
    def _post_generation_handler(self, pattern: str, breakdown: list, title: str):
        self.ui.print_result(pattern, breakdown, title)
        while True:
            choice = self.ui.get_input("\nAction: [T]est Pattern, [C]opy Formats, [M]ain Menu:").lower()
            if choice == 't':self._handle_regex_tester(prefilled_pattern=pattern);break
            elif choice == 'c':self.ui.print_copy_formats(pattern)
            elif choice == 'm':break
            else:self.ui.print_error("Invalid choice.")
    def _handle_selector_generation(self):
        term = self.ui.get_input("Enter selector string (e.g., '#id .class'):")
        if term:
            try:self.ui.print_status("Generating pattern...", animate=False);p,b=self.logic.generate_selector_regex(term);self._post_generation_handler(p, b, "CSS Selector")
            except ValueError as e:self.ui.print_error(str(e))
        else:self.ui.print_error("Input cannot be empty.")
    def _handle_domain_generation(self):
        term = self.ui.get_input("Enter domain name (e.g., 'example.com'):")
        if term:
            try:self.ui.print_status("Generating pattern...", animate=False);p,b=self.logic.generate_domain_regex(term);self._post_generation_handler(p, b, "Domain Name")
            except ValueError as e:self.ui.print_error(str(e))
        else:self.ui.print_error("Input cannot be empty.")
    def _handle_generic_pattern(self, logic_func, desc):
        self.ui.print_status(f"Generating pattern for {desc}...", animate=False)
        p,b=logic_func()
        self._post_generation_handler(p, b, desc)
    def _handle_regex_tester(self, prefilled_pattern: str = ""):
        try:
            pattern = prefilled_pattern or self.ui.get_input("Enter Regex Pattern to Test:")
            if not pattern: self.ui.print_error("Pattern cannot be empty."); return
            self.ui.print_status("Enter text to test against the pattern.")
            text_to_test = self.ui.get_multiline_input()
            self.ui.print_status("Testing pattern...", animate=False)
            matches = self.logic.test_regex(pattern, text_to_test)
            self.ui.print_test_results(matches, text_to_test)
        except ValueError as e: self.ui.print_error(str(e))
    def _handle_custom_builder(self):
        # This handler logic is preserved but now uses the new UI methods.
        self.ui.print_status("Entering Interactive Pattern Builder...")
        components = []
        while True:
            current_pattern = "".join(c for c,d in components)
            print(f"\n--- Current Pattern: {current_pattern if current_pattern else '(empty)'} ---")
            choice = self.ui.get_input("Add: [1]Literal, [2]Char Class, [3]Custom Set [...] | [F]inish, [C]ancel:").lower()
            if choice == '1':
                literal = self.ui.get_input("Enter literal string:")
                if literal: components.append((re.escape(literal), f"literal '{literal}'"))
            elif choice == '2':
                c = self.ui.get_input("[d]igit, [w]ord, [s]pace, [a]lpha:")
                char_map = {'d': (r'\d', 'digit'), 'w': (r'\w', 'word char'), 's': (r'\s', 'whitespace'), 'a': (r'[a-zA-Z]', 'alpha char')}
                if c in char_map:
                    q = self.ui.get_input("Quantifier: [1]One, [+]One+, [*]Zero+, [?]Optional, {n}Exact:")
                    quant_map = {'+':'+', '*': '*', '?':'?', '1':''}
                    quant = quant_map.get(q, f"{{{q}}}" if q.isdigit() else '')
                    components.append((char_map[c][0] + quant, f"{char_map[c][1]} repeated {q if q else 'once'}"))
            elif choice == '3':
                charset = self.ui.get_input("Enter characters for set (e.g., a-z_):")
                if charset: components.append((f"[{re.escape(charset)}]+", f"one or more from set '[{charset}]'"))
            elif choice == 'f':
                if not components: self.ui.print_error("Cannot build an empty pattern."); continue
                p = "".join(c for c,d in components); b = [d for c,d in components]
                self._post_generation_handler(p, b, "Custom Built Pattern"); break
            elif choice == 'c': self.ui.print_status("Builder cancelled."); break
            else: self.ui.print_error("Invalid choice.")
    def _handle_quit(self):
        if self.ui.get_confirmation("Are you sure you want to quit?"):
            print("Exiting application."); sys.exit(0)
    
    def run(self, args):
        self.ui.print_header()
        if '-h' in args or '--help' in args:
            self.ui.print_help(self.menu_options); return

        while True:
            self.ui.print_menu(self.menu_options)
            choice = self.ui.get_input("Your choice:")
            action = self.menu_options.get(choice.lower())
            
            if action:
                if choice.lower() in ['h']: action['handler'](self.menu_options)
                elif choice.lower() in ['1', '2', '9', 't', 'q']: action['handler']()
                else: action['handler'](action['logic_func'], action['desc'])
            else:
                self.ui.print_error("Unrecognized command.")
                self.ui.print_help(self.menu_options)

# --- Main Logic Section ---
def main():
    try:
        app = RegexGeneratorApp()
        app.run(sys.argv[1:])
    except KeyboardInterrupt:
        print("\n\nUser interrupted session. Exiting gracefully.")
        sys.exit(1)

if __name__ == "__main__":
    main()
