#!/usr/bin/env python3

import sys, os, re, shutil, subprocess, webbrowser
from collections import deque
from prompt_toolkit import prompt
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.styles import Style

style = Style.from_dict({
    "":            "ansicyan",
    "prompt":      "fg:#15FFFF bold",
    "menu":        "fg:#FFD700 bold",
    "success":     "fg:#00FFAF bold",
    "error":       "fg:#FF5F5F bold",
})

CYAN = "\033[38;5;51m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
RESET = "\033[0m"
BOLD = "\033[1m"

MAX_RECENTS = 8

# ---- Modal-like Category/Pattern Structure ----

DORK_CATEGORIES = [
    ("Direct Domain Patterns", [
        ("Primary .com",      '"{company}.com"'),
        ("Primary .net",      '"{company}.net"'),
        ("Primary .org",      '"{company}.org"'),
        ("Primary .io",       '"{company}.io"'),
    ]),
    ("Subdomain Discovery", [
        ("All .com subdomains", 'site:*.{company}.com'),
        ("All .net subdomains", 'site:*.{company}.net'),
        ("All .org subdomains", 'site:*.{company}.org'),
    ]),
    ("Domain Variations", [
        ("Company + domain", '"{company}" "domain" ".com"'),
        ("Company plural", '"{company}s.com"'),
        ("Company with the", '"the{company}.com"'),
        ("Company in URL", '"{company}" inurl:{company}'),
    ]),
    ("File & Document Discovery", [
        ("PDF documents", '"{company}" filetype:pdf site:*.com'),
        ("Word documents", '"{company}" filetype:doc site:*.com'),
    ]),
    ("Brand Variations", [
        ("No spaces", '"{company_nospaces}.com"'),
        ("With dashes", '"{company_dash}.com"'),
    ]),
    ("International Domains", [
        ("UK domains", '"{company}" site:*.co.uk'),
        ("Canadian domains", '"{company}" site:*.ca'),
    ]),
    ("Social & Email Discovery", [
        ("Email domains", '"@{company}.com"'),
        ("Contact emails", '"contact@{company}"'),
    ]),
    ("Advanced Discovery", [
        ("Redirects to", '"{company}" "redirects to"'),
    ]),
    ("WHOIS", [
        ("Registrant Organization", '"Registrant Organization" "{company}"'),
        ("DomainTools WHOIS", '"{company}" site:whois.domaintools.com'),
    ]),
    ("Security & Threat", [
        ("VirusTotal", '"{company}" site:virustotal.com'),
    ]),
]

def sanitize_domain(domain):
    return re.sub(r"^(https?://)?(www\.)?", "", domain.strip().lower()).split("/")[0]

def copy_to_clipboard(text):
    try:
        if shutil.which('wl-copy'):
            subprocess.run(['wl-copy'], input=text.encode('utf-8'), check=True)
        elif shutil.which('xclip'):
            subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode('utf-8'), check=True)
        elif shutil.which('pbcopy'):
            subprocess.run(['pbcopy'], input=text.encode('utf-8'), check=True)
        else:
            return False
        return True
    except Exception:
        return False

def open_browser(query):
    url = f"https://www.google.com/search?q={query.replace(' ', '+')}"
    try:
        webbrowser.open(url)
        print(f"{GREEN}Opened in browser:{RESET} {url}")
    except Exception:
        print(f"{YELLOW}Failed to open browser. Copy the URL manually.{RESET}")

def dork_modal_session(company):
    recents = deque(maxlen=MAX_RECENTS)
    discovered = set()
    company_nospaces = company.replace(" ", "")
    company_dash = company.replace(" ", "-")
    subst = {"company": company, "company_nospaces": company_nospaces, "company_dash": company_dash}

    while True:
        # CATEGORY PANEL
        print(f"\n{CYAN}{BOLD}Dork Modal: Categories{RESET}\n")
        for i, (cat, _) in enumerate(DORK_CATEGORIES):
            print(f"{YELLOW}{i+1}{RESET}. {cat}")
        print(f"{YELLOW}0{RESET}. Quit (or [A]dd domain / [R]ecents)")

        cat_in = prompt(HTML('<prompt>Select category (number), [A]dd domain, [R]ecents, or 0 to quit:</prompt> '), style=style).strip()
        if cat_in.lower() == '0':
            print(f"{CYAN}Bye.{RESET}")
            sys.exit(0)
        if cat_in.lower() == 'a':
            new_domain = prompt(HTML('<prompt>Enter discovered domain (sanitized):</prompt> '), style=style)
            dom = sanitize_domain(new_domain)
            if dom:
                discovered.add(dom)
                print(f"{GREEN}Added:{RESET} {dom}")
            continue
        if cat_in.lower() == 'r':
            print(f"\n{CYAN}Recent dorks:{RESET}")
            for d in recents:
                print(f"{GREEN}{d}{RESET}")
            print(f"{CYAN}Discovered domains:{RESET}")
            for d in discovered:
                print(f"{GREEN}{d}{RESET}")
            input(f"{CYAN}Press Enter to continue...{RESET}")
            continue
        if not cat_in.isdigit() or not (1 <= int(cat_in) <= len(DORK_CATEGORIES)):
            print(f"{RED}Invalid category.{RESET}")
            continue

        cat_idx = int(cat_in) - 1
        cat_name, patterns = DORK_CATEGORIES[cat_idx]
        # PATTERN PANEL
        while True:
            print(f"\n{CYAN}{BOLD}{cat_name}{RESET}")
            for j, (name, pattern) in enumerate(patterns):
                dork = pattern.format(**subst)
                print(f"{YELLOW}{j+1}{RESET}. {name} {CYAN}{dork}{RESET}")
            print(f"{YELLOW}0{RESET}. Back to Categories")
            pat_in = prompt(HTML('<prompt>Pick dork pattern (number), [C]opy, [O]pen, or 0 to go back:</prompt> '), style=style).strip()
            if pat_in.lower() == '0':
                break
            if pat_in.lower() == 'c':
                dork = prompt(HTML('<prompt>Enter exact dork to copy (or paste it):</prompt> '), style=style)
                if copy_to_clipboard(dork):
                    print(f"{GREEN}Copied to clipboard!{RESET}")
                else:
                    print(f"{YELLOW}Clipboard utility not found.{RESET}")
                continue
            if pat_in.lower() == 'o':
                dork = prompt(HTML('<prompt>Enter exact dork to open (or paste it):</prompt> '), style=style)
                open_browser(dork)
                continue
            if not pat_in.isdigit() or not (1 <= int(pat_in) <= len(patterns)):
                print(f"{RED}Invalid pattern.{RESET}")
                continue
            patt_name, patt = patterns[int(pat_in)-1]
            dork = patt.format(**subst)
            recents.appendleft(dork)
            print(f"\n{GREEN}Your dork:{RESET} {dork}")
            if copy_to_clipboard(dork):
                print(f"{GREEN}Copied to clipboard!{RESET}")
            else:
                print(f"{YELLOW}Clipboard utility not found.{RESET}")
            if prompt(HTML('<prompt>Open in browser? (y/n):</prompt> '), style=style).strip().lower().startswith("y"):
                open_browser(dork)
            else:
                print(f"{YELLOW}Not opening browser. Copy/paste dork manually if needed.{RESET}")
            # After one use, stay on pattern list for more actions

def batch_mode(company, category=None, dork=None):
    # Non-interactive direct mode for scripting, automation, fzf-pipe
    company_nospaces = company.replace(" ", "")
    company_dash = company.replace(" ", "-")
    subst = {"company": company, "company_nospaces": company_nospaces, "company_dash": company_dash}
    if dork:
        dork_str = dork.format(**subst)
        print(f"{GREEN}{dork_str}{RESET}")
        copy_to_clipboard(dork_str)
        open_browser(dork_str)
        return
    if category:
        cats = [c for c, _ in DORK_CATEGORIES]
        if category not in cats:
            print(f"{RED}No such category: {category}{RESET}")
            return
        patterns = dict(DORK_CATEGORIES)[category]
        for name, patt in patterns:
            dork_str = patt.format(**subst)
            print(f"{GREEN}{name}:{RESET} {dork_str}")
    else:
        print(f"{YELLOW}No category/dork specified for batch mode.{RESET}")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Dork Modal Terminal Tool")
    parser.add_argument('--company', type=str, help='Company name for dork interpolation')
    parser.add_argument('--category', type=str, help='Category to dump all patterns (for scripting)')
    parser.add_argument('--dork', type=str, help='Directly specify dork pattern (for scripting)')
    args = parser.parse_args()
    if args.company and (args.category or args.dork):
        batch_mode(args.company, args.category, args.dork)
        sys.exit(0)
    # else: interactive modal
    company = args.company or prompt(HTML('<prompt>Enter company name for dorking:</prompt> '), style=style)
    dork_modal_session(company)

if __name__ == "__main__":
    main()
