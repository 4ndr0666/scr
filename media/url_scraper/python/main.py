#!/usr/bin/env python3
import sys
import argparse
import enumerator
import integration


def show_help():
    """
    Display usage instructions for this script.
    """
    print("Usage: main.py [options]\n")
    print("Options:")
    print("  -h, --help                    Show this help message and exit.")
    print(
        "  -u <URL>                      Enumerate images starting at the specified image URL."
    )
    print("  -m, --menu                    Launch interactive menu.")
    print("  --open-browser                Open enumerated images in new browser tabs.")
    print("  --download-aria2 <DOWNLOAD_DIR>  Download enumerated images using aria2.")
    print(
        "  --store <FILENAME>            Store enumerated images to a local text file (idempotent)."
    )
    print("")
    print("Examples:")
    print("  main.py -u https://example.com/39.jpg --open-browser")
    print("  main.py -u https://example.com/39.jpg --download-aria2 /path/to/downloads")
    print("  main.py -u https://example.com/39.jpg --store found_urls.txt")
    print("  main.py -m")


def menu_mode():
    """
    Interactive menu mode, allowing the user to choose an action.
    """
    while True:
        enumerator.color_print("\n--- Image Enumeration Menu ---", enumerator.CYAN)
        print("1) Enumerate images from a URL")
        print("2) Show help/usage")
        print("3) Quit")
        choice = input("Enter choice: ").strip()
        if choice == "1":
            url = input(
                "Enter an image URL (with numeric portion, e.g., 39.jpg): "
            ).strip()
            if url:
                # Perform enumeration
                enumerated_list = enumerator.auto_enumerate_images(url)
                # Submenu for next steps
                submenu(enumerated_list)
        elif choice == "2":
            show_help()
        elif choice == "3":
            print("Goodbye.")
            sys.exit(0)
        else:
            enumerator.color_print(
                "Unrecognized choice. Please try again.", enumerator.LIGHT_RED
            )


def submenu(enumerated_list):
    """
    Presents additional options after enumerating the images (opening in browser,
    downloading via aria2, storing to a file, etc.).
    """
    while True:
        enumerator.color_print("\n--- Post-Enumeration Options ---", enumerator.CYAN)
        print("1) Open enumerated images in browser tabs")
        print("2) Download enumerated images via aria2")
        print("3) Store enumerated images to a text file")
        print("4) Return to main menu")
        choice = input("Enter choice: ").strip()
        if choice == "1":
            integration.open_in_browser(enumerated_list)
            enumerator.color_print(
                "Opened enumerated images in browser tabs.", enumerator.LIGHT_GREEN
            )
        elif choice == "2":
            out_dir = input("Enter download directory: ").strip()
            integration.download_with_aria2(enumerated_list, out_dir)
        elif choice == "3":
            out_file = input("Enter output file name: ").strip()
            appended_count = integration.store_urls(enumerated_list, out_file)
            enumerator.color_print(
                f"Stored {appended_count} new URLs to file: {out_file}",
                enumerator.LIGHT_GREEN,
            )
        elif choice == "4":
            # Return to main menu
            break
        else:
            enumerator.color_print(
                "Unrecognized choice. Please try again.", enumerator.LIGHT_RED
            )


def main():
    """
    Parses command-line arguments and dispatches to the correct function.
    """
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-h", "--help", action="store_true", help="Show help message.")
    parser.add_argument(
        "-m", "--menu", action="store_true", help="Launch interactive menu."
    )
    parser.add_argument(
        "-u", metavar="URL", type=str, help="Enumerate images from the given image URL."
    )
    parser.add_argument(
        "--open-browser",
        action="store_true",
        help="Open enumerated images in new browser tabs.",
    )
    parser.add_argument(
        "--download-aria2",
        metavar="DOWNLOAD_DIR",
        type=str,
        help="Download enumerated images using aria2 to the specified directory.",
    )
    parser.add_argument(
        "--store",
        metavar="FILENAME",
        type=str,
        help="Store enumerated images in a local text file (idempotent).",
    )
    args = parser.parse_args()
    # If no arguments, launch the menu
    if len(sys.argv) == 1:
        menu_mode()
        return
    # Handle help
    if args.help:
        show_help()
        sys.exit(0)
    # Handle menu
    if args.menu:
        menu_mode()
        return
    # Must have a URL to enumerate if not in menu mode
    if not args.u:
        enumerator.color_print(
            "Error: No URL provided. Use -u <URL> or -m for the menu.",
            enumerator.LIGHT_RED,
        )
        show_help()
        sys.exit(1)
    # Perform enumeration
    enumerated_list = enumerator.auto_enumerate_images(args.u)
    # If user wants to open in browser
    if args.open_browser:
        integration.open_in_browser(enumerated_list)
    # If user wants to download via aria2
    if args.download_aria2:
        integration.download_with_aria2(enumerated_list, args.download_aria2)
    # If user wants to store enumerated URLs to a file
    if args.store:
        appended_count = integration.store_urls(enumerated_list, args.store)
        enumerator.color_print(
            f"Stored {appended_count} new URLs to file: {args.store}",
            enumerator.LIGHT_GREEN,
        )


if __name__ == "__main__":
    main()
