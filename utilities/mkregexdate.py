#!/usr/bin/env python3
"""
Custom Date and Time Formatter with Enhanced UI and Clipboard Integration

A minimalist and powerful tool for formatting dates and times using predefined
or custom format strings. Provides both interactive and command-line interfaces,
supports clipboard copying via wl-copy, and displays previews with cyan styling.

Features:
- Predefined date and time formats
- Guided custom format builder with dynamic previews
- Automatically copies the result to the clipboard using wl-copy
- Intuitive CLI system for integration into larger workflows
- Adheres to the suckless philosophy of simplicity and program quality

Usage:
    Interactive Mode:
        Run the script without arguments and follow the prompts.

    Non-Interactive Mode:
        Provide date and time along with desired formats via command-line arguments.

        Example:
            ./date_formatter.py --date "2023-12-31" --time "23:59" --date-format 2 --time-format 3

Author: OpenAI ChatGPT
Date: 2024-04-27
"""

import datetime
import subprocess
import sys
import shutil
import argparse

# ANSI escape codes for colored output
CYAN = "\033[96m"
RESET = "\033[0m"


class DateTimeFormatter:
    """Handles formatting of date and time based on user-selected formats."""

    PREDEFINED_STYLES = {
        '1': ('YYYY-MM-DD', '%Y-%m-%d'),
        '2': ('MM/DD/YYYY', '%m/%d/%Y'),
        '3': ('DD/MM/YYYY', '%d/%m/%Y'),
        '4': ('DD.MM.YYYY', '%d.%m.%Y'),
    }

    TIME_FORMATS = {
        '1': ('12-Hour Format', '%I:%M %p'),
        '2': ('24-Hour Format', '%H:%M'),
        '3': ('24-Hour with Seconds', '%H:%M:%S'),
        '4': ('Short 12-Hour', '%I:%M%p'),
    }

    DATE_COMPONENTS = {
        'Year': ['%Y', '%y'],
        'Month': ['%m', '%b', '%B'],
        'Day': ['%d', '%-d'],
        'Weekday': ['%A', '%a'],
    }

    TIME_COMPONENTS = {
        'Hour': ['%H', '%I'],
        'Minute': ['%M'],
        'Second': ['%S'],
        'AM/PM': ['%p'],
    }

    def __init__(self):
        self.date_format = None
        self.time_format = None
        self.ui_tool = self.detect_ui_tool()

    def detect_ui_tool(self):
        """Detects available UI tool: currently focuses on terminal-based UI."""
        # For simplicity and minimalism, we focus on terminal-based UI.
        return 'terminal'

    def list_styles_terminal(self):
        """Lists predefined styles in terminal and prompts user to select."""
        print("\nSelect a style:")
        for key, (desc, fmt) in self.PREDEFINED_STYLES.items():
            example = datetime.datetime.now().strftime(fmt)
            print(f"{key}) {desc} -> Example:")
            print(f"{CYAN}{self.create_box(example)}{RESET}")
        print("5) Custom Format: Build your own format string.")

        while True:
            choice = input("\nEnter the style number (1-5): ").strip()
            if choice in self.PREDEFINED_STYLES:
                return self.PREDEFINED_STYLES[choice][1]
            elif choice == '5':
                return self.build_custom_format()
            else:
                print("Invalid choice. Please select a valid style number (1-5).")

    def list_time_formats_terminal(self):
        """Lists predefined time formats in terminal and prompts user to select."""
        print("\nSelect a time format:")
        for key, (desc, fmt) in self.TIME_FORMATS.items():
            example = datetime.datetime.now().strftime(fmt)
            print(f"{key}) {desc} -> Example:")
            print(f"{CYAN}{self.create_box(example)}{RESET}")
        print("5) Custom Format: Build your own time format string.")

        while True:
            choice = input("\nEnter the time format number (1-5): ").strip()
            if choice in self.TIME_FORMATS:
                return self.TIME_FORMATS[choice][1]
            elif choice == '5':
                return self.build_custom_time_format()
            else:
                print("Invalid choice. Please select a valid time format number (1-5).")

    def list_styles(self):
        """Delegates style selection based on available UI tool."""
        if self.ui_tool == 'terminal':
            return self.list_styles_terminal()
        # Placeholder for other UI tools like 'fzf' or 'yad'
        else:
            return self.list_styles_terminal()

    def list_time_formats(self):
        """Delegates time format selection based on available UI tool."""
        if self.ui_tool == 'terminal':
            return self.list_time_formats_terminal()
        # Placeholder for other UI tools like 'fzf' or 'yad'
        else:
            return self.list_time_formats_terminal()

    def build_custom_format(self):
        """Guides the user through building a custom date format string."""
        print("\n### Custom Date Format Builder ###")
        format_str = ""

        # Select Date Components
        for component, options in self.DATE_COMPONENTS.items():
            print(f"\nSelect {component} format:")
            for idx, opt in enumerate(options, 1):
                # Generate a sample formatted output
                sample = datetime.datetime.now().strftime(opt)
                print(f"  {idx}) {opt} -> Example:")
                print(f"      {CYAN}{self.create_box(sample)}{RESET}")
            print("  0) Skip this component")

            while True:
                choice = input(f"Choose {component} format (1-{len(options)} or 0 to skip): ").strip()
                if choice.isdigit():
                    choice = int(choice)
                    if 1 <= choice <= len(options):
                        format_str += options[choice - 1]
                        self.display_preview(format_str)
                        break
                    elif choice == 0:
                        break
                print("Invalid choice. Please try again.")

        if not format_str:
            print("No date components selected. Using default '%Y-%m-%d'")
            return '%Y-%m-%d'

        print(f"\nFinal Date Format String: \"{format_str}\"")
        return format_str

    def build_custom_time_format(self):
        """Guides the user through building a custom time format string."""
        print("\n### Custom Time Format Builder ###")
        format_str = ""

        # Select Time Components
        for component, options in self.TIME_COMPONENTS.items():
            print(f"\nSelect {component} format:")
            for idx, opt in enumerate(options, 1):
                # Generate a sample formatted output
                sample = datetime.datetime.now().strftime(opt)
                print(f"  {idx}) {opt} -> Example:")
                print(f"      {CYAN}{self.create_box(sample)}{RESET}")
            print("  0) Skip this component")

            while True:
                choice = input(f"Choose {component} format (1-{len(options)} or 0 to skip): ").strip()
                if choice.isdigit():
                    choice = int(choice)
                    if 1 <= choice <= len(options):
                        format_str += options[choice - 1]
                        self.display_preview(format_str)
                        break
                    elif choice == 0:
                        break
                print("Invalid choice. Please try again.")

        if not format_str:
            print("No time components selected. Using default '%H:%M:%S'")
            return '%H:%M:%S'

        print(f"\nFinal Time Format String: \"{format_str}\"")
        return format_str

    def display_preview(self, format_str):
        """Displays the current preview of the format string in cyan within a box."""
        try:
            preview = datetime.datetime.now().strftime(format_str)
            box = self.create_box(preview)
            print(f"\nPreview:\n{CYAN}{box}{RESET}\n")
        except Exception as e:
            print(f"Invalid format string: {e}")

    def create_box(self, text):
        """Creates a box around the given text."""
        lines = text.split('\n')
        max_length = max(len(line) for line in lines)
        border = '+' + '-' * (max_length + 2) + '+'
        boxed_text = [border]
        for line in lines:
            boxed_text.append(f"| {line.ljust(max_length)} |")
        boxed_text.append(border)
        return '\n'.join(boxed_text)

    def parse_input_datetime(self, date_str, time_str):
        """Parses user input into a datetime object using multiple formats."""
        datetime_formats = [
            '%Y-%m-%d %H:%M',
            '%Y-%m-%d %I:%M %p',
            '%m/%d/%Y %H:%M',
            '%m/%d/%Y %I:%M %p',
            '%d/%m/%Y %H:%M',
            '%d/%m/%Y %I:%M %p',
            '%d.%m.%Y %H:%M',
            '%d.%m.%Y %I:%M %p',
        ]
        combined = f"{date_str} {time_str}"
        for fmt in datetime_formats:
            try:
                return datetime.datetime.strptime(combined, fmt)
            except ValueError:
                continue
        raise ValueError("Invalid date or time format. Please refer to the examples.")

    def copy_to_clipboard(self, text):
        """Copies the given text to the clipboard using wl-copy."""
        try:
            if shutil.which('wl-copy'):
                process = subprocess.Popen(['wl-copy'], stdin=subprocess.PIPE)
                process.communicate(text.encode())
            else:
                print("wl-copy not found. Please install wl-clipboard package.")
        except Exception as e:
            print(f"Failed to copy to clipboard: {e}")

    def preview_format(self, dt):
        """Displays the formatted date and time along with format strings."""
        formatted_date = dt.strftime(self.date_format)
        formatted_time = dt.strftime(self.time_format)
        combined_format = f"{self.date_format} {self.time_format}"
        combined_formatted = f"{formatted_date} {formatted_time}"

        box = self.create_box(combined_formatted)
        print(f"\nFormatted Date and Time:\n{CYAN}{box}{RESET}")
        print(f"Date Format String: \"{self.date_format}\"")
        print(f"Time Format String: \"{self.time_format}\"")
        print(f"Combined Format String: \"{combined_format}\"")

    def custom_format_preview(self, dt):
        """Allows users to experiment with custom format strings in real-time."""
        print("\n### Custom Format Preview ###")
        print("Type 'exit' to quit the preview.\n")
        while True:
            user_fmt = input("Enter a custom format string (or type 'exit' to quit): ").strip()
            if user_fmt.lower() == 'exit':
                break
            try:
                preview = dt.strftime(user_fmt)
                box = self.create_box(preview)
                print(f"Preview:\n{CYAN}{box}{RESET}\n")
            except Exception as e:
                print(f"Invalid format string: {e}\n")

    def run_interactive(self, date_str, time_str):
        """Runs the interactive workflow."""
        try:
            dt = self.parse_input_datetime(date_str, time_str)
        except ValueError as e:
            print(f"\nError: {e}")
            sys.exit(1)

        self.date_format = self.list_styles()
        self.time_format = self.list_time_formats()

        self.preview_format(dt)
        formatted_output = f"{dt.strftime(self.date_format)} {dt.strftime(self.time_format)}"
        self.copy_to_clipboard(formatted_output)
        print(f"\n{CYAN}The formatted date and time have been copied to your clipboard.{RESET}")
        self.custom_format_preview(dt)

    def run_non_interactive(self, date_str, time_str, date_format_key, time_format_key):
        """Runs the non-interactive workflow."""
        try:
            dt = self.parse_input_datetime(date_str, time_str)
        except ValueError as e:
            print(f"\nError: {e}")
            sys.exit(1)

        # Handle date format
        if date_format_key:
            if date_format_key == '5':
                date_format = self.build_custom_format()
            elif date_format_key in self.PREDEFINED_STYLES:
                date_format = self.PREDEFINED_STYLES[date_format_key][1]
            else:
                print(f"Invalid date format key: {date_format_key}")
                sys.exit(1)
        else:
            date_format = '%Y-%m-%d'  # Default format

        # Handle time format
        if time_format_key:
            if time_format_key == '5':
                time_format = self.build_custom_time_format()
            elif time_format_key in self.TIME_FORMATS:
                time_format = self.TIME_FORMATS[time_format_key][1]
            else:
                print(f"Invalid time format key: {time_format_key}")
                sys.exit(1)
        else:
            time_format = '%H:%M:%S'  # Default format

        formatted_date = dt.strftime(date_format)
        formatted_time = dt.strftime(time_format)
        combined_format = f"{date_format} {time_format}"
        combined_formatted = f"{formatted_date} {formatted_time}"

        box = self.create_box(combined_formatted)
        print(f"\nFormatted Date and Time:\n{CYAN}{box}{RESET}")
        print(f"Date Format String: \"{date_format}\"")
        print(f"Time Format String: \"{time_format}\"")
        print(f"Combined Format String: \"{combined_format}\"")

        self.copy_to_clipboard(combined_formatted)
        print(f"\n{CYAN}The formatted date and time have been copied to your clipboard.{RESET}")

    def run(self, args):
        """Executes the formatter workflow based on provided arguments."""
        if args.date and args.time:
            self.run_non_interactive(args.date, args.time, args.date_format, args.time_format)
        else:
            # Interactive mode with current date and time
            current_date = datetime.datetime.now().strftime('%Y-%m-%d')
            current_time = datetime.datetime.now().strftime('%H:%M')
            print(f"\nUsing current date and time: {CYAN}{current_date} {current_time}{RESET}")
            self.run_interactive(current_date, current_time)


def parse_arguments():
    """Parses command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Custom Date and Time Formatter with Clipboard Integration"
    )
    parser.add_argument('--date', type=str, help='Date string (e.g., "2023-12-31")')
    parser.add_argument('--time', type=str, help='Time string (e.g., "23:59" or "11:59 PM")')
    parser.add_argument('--date-format', type=str, choices=['1', '2', '3', '4', '5'],
                        help='Desired date format number (1-5)')
    parser.add_argument('--time-format', type=str, choices=['1', '2', '3', '4', '5'],
                        help='Desired time format number (1-5)')
    return parser.parse_args()


def main():
    """Main entry point for the formatter."""
    args = parse_arguments()
    formatter = DateTimeFormatter()
    formatter.run(args)


if __name__ == "__main__":
    main()
