#!/usr/bin/env python3
"""
main.py

Main entry point for the image enumeration script.
Handles user interaction, command-line arguments, and calls enumerator.py for the core logic.

Dependencies:
    - enumerator.py (in the same directory)
    - Python 3.x
    - requests (pip install requests)
"""

import sys
import argparse
import enumerator  # Local import from enumerator.py


def show_help():
    """
    Display usage instructions for this script.
    """
    print("Usage: main.py [options]")
    print("")
    print("Options:")
    print("  -h, --help            Show this help message and exit")
    print(
        "  -u <URL>              Enumerate images starting at the specified image URL"
    )
    print("  -m, --menu            Launch interactive menu")
    print("")
    print("Examples:")
    print("  main.py -u https://example.com/39.jpg")
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
                enumerator.auto_enumerate_images(url)
        elif choice == "2":
            show_help()
        elif choice == "3":
            print("Goodbye.")
            sys.exit(0)
        else:
            enumerator.color_print(
                "Unrecognized choice. Please try again.", enumerator.LIGHT_RED
            )


def main():
    """
    Parses command-line arguments and dispatches to the correct function.
    """
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-h", "--help", action="store_true", help="Show help message")
    parser.add_argument(
        "-m", "--menu", action="store_true", help="Launch interactive menu"
    )
    parser.add_argument(
        "-u",
        metavar="URL",
        type=str,
        help="Enumerate images starting at the given image URL",
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

    # Handle enumeration via URL
    if args.u:
        enumerator.auto_enumerate_images(args.u)
        return

    # If none of the above, unrecognized usage
    enumerator.color_print("Unrecognized command. Showing help...\n", enumerator.ORANGE)
    show_help()


if __name__ == "__main__":
    main()
