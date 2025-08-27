#!/usr/bin/env python3
import argparse
import subprocess
import sys
import os
import base64
import codecs # For ROT13
import urllib.parse # For URL encoding
import html # For HTML entities
import signal # For process termination

# --- Global Mappings ---

# Leetspeak Map (case-insensitive for input, tries to preserve case for single-char mappings)
LEET_MAP = {
    'a': '4', 'b': '8', 'c': '(', 'd': '|)', 'e': '3', 'f': 'ph', 'g': '9', 'h': '#',
    'i': '1', 'j': '_|', 'k': '|<', 'l': '1', 'm': '/\\/\\', 'n': '/\\/', 'o': '0',
    'p': '|*', 'q': '(_,)', 'r': '|2', 's': '5', 't': '7', 'u': '|_|', 'v': '\\/',
    'w': '\\/\\/', 'x': '%', 'y': '`/', 'z': '2'
}

# Morse Code Map (simplified for common chars, lowercase conversion for lookup)
MORSE_CODE_MAP = {
    'a': '.-', 'b': '-...', 'c': '-.-.', 'd': '-..', 'e': '.',
    'f': '..-.', 'g': '--.', 'h': '....', 'i': '..', 'j': '.---',
    'k': '-.-', 'l': '.-..', 'm': '--', 'n': '-.', 'o': '---',
    'p': '.--.', 'q': '--.-', 'r': '.-.', 's': '...', 't': '-',
    'u': '..-', 'v': '...-', 'w': '.--', 'x': '-..-', 'y': '`--`',
    'z': '--..',
    '0': '-----', '1': '.----', '2': '..---', '3': '...--',
    '4': '....-', '5': '.....', '6': '-....', '7': '--...',
    '8': '---..', '9': '----.',
    ' ': '/', # Standard space separator in Morse
    '.': '.-.-.-', ',': '--..--', '?': '..--..', '!': '-.-.--'
}

# --- Obfuscation Functions (for the payload content) ---

def obfuscate_direct(text: str) -> str:
    """No obfuscation applied to the payload."""
    return text

def obfuscate_base64(text: str) -> str:
    """Applies Base64 encoding to the payload."""
    return base64.b64encode(text.encode('utf-8')).decode('utf-8')

def obfuscate_rot13(text: str) -> str:
    """Applies ROT13 cipher to the payload."""
    return codecs.encode(text, 'rot13')

def obfuscate_hex(text: str) -> str:
    """Applies Hex encoding to the payload."""
    return text.encode('utf-8').hex()

def obfuscate_leetspeak(text: str) -> str:
    """Applies Leetspeak transformation to the payload."""
    transformed_chars = []
    for char in text:
        mapped_char = LEET_MAP.get(char.lower(), char)
        # Try to preserve original casing for single-character alphabetic leet replacements
        if mapped_char != char and char.isupper() and len(mapped_char) == 1 and mapped_char.isalpha():
            transformed_chars.append(mapped_char.upper())
        else:
            transformed_chars.append(mapped_char)
    return "".join(transformed_chars)

def obfuscate_reverse(text: str) -> str:
    """Reverses the text payload."""
    return text[::-1]

def obfuscate_unicode(text: str) -> str:
    """Applies Unicode escaping to the payload (e.g., '€' -> '\\u20ac')."""
    return text.encode('unicode_escape').decode('ascii')

def obfuscate_binary(text: str) -> str:
    """Encodes each character of the payload into its 8-bit binary representation."""
    return ' '.join(format(ord(char), '08b') for char in text)

def obfuscate_url_encode(text: str) -> str:
    """Applies URL encoding to the payload."""
    return urllib.parse.quote(text)

def obfuscate_html_entities(text: str) -> str:
    """Converts special characters in the payload to HTML entities."""
    return html.escape(text)

def _caesar_cipher_char(char: str, shift: int) -> str:
    """Helper for Caesar cipher on a single character."""
    if 'a' <= char <= 'z':
        return chr(((ord(char) - ord('a') + shift) % 26) + ord('a'))
    elif 'A' <= char <= 'Z':
        return chr(((ord(char) - ord('A') + shift) % 26) + ord('A'))
    else:
        return char

def obfuscate_caesar_3(text: str) -> str:
    """Applies Caesar cipher with shift 3 to the payload."""
    return "".join(_caesar_cipher_char(char, 3) for char in text)

def obfuscate_caesar_7(text: str) -> str:
    """Applies Caesar cipher with shift 7 to the payload."""
    return "".join(_caesar_cipher_char(char, 7) for char in text)

def obfuscate_xor(text: str, key: bytes = b"obfuscator") -> str:
    """
    Applies XOR encryption with a repeating key to the payload, then returns as hex string.
    Note: For a robust XOR, proper key management is needed. This is a simple demonstration.
    """
    text_bytes = text.encode('utf-8')
    key_len = len(key)
    xor_bytes = bytearray(len(text_bytes))
    for i in range(len(text_bytes)):
        xor_bytes[i] = text_bytes[i] ^ key[i % key_len]
    return xor_bytes.hex() # Represent the XORed bytes as a hex string

def obfuscate_morse(text: str) -> str:
    """Converts payload text to Morse code."""
    morse_list = []
    for char in text.lower():
        if char in MORSE_CODE_MAP:
            morse_list.append(MORSE_CODE_MAP[char])
        elif char.isspace():
            morse_list.append(MORSE_CODE_MAP.get(' ', ' ')) # Use mapped space, default to regular space
        else:
            morse_list.append(char) # Keep unmappable chars as-is
    return ' '.join(morse_list)

def obfuscate_mixed(text: str) -> str:
    """Applies Leetspeak then Base64 encoding to the payload."""
    leeted_text = obfuscate_leetspeak(text)
    return obfuscate_base64(leeted_text)

def obfuscate_double_base64(text: str) -> str:
    """Applies Base64 encoding twice to the payload."""
    first_pass = obfuscate_base64(text)
    return obfuscate_base64(first_pass)

# --- Obfuscation Techniques Dictionary ---
obfuscation_techniques = {
    "direct": obfuscate_direct,
    "base64": obfuscate_base64,
    "rot13": obfuscate_rot13,
    "hex": obfuscate_hex,
    "leetspeak": obfuscate_leetspeak,
    "reverse": obfuscate_reverse,
    "unicode": obfuscate_unicode,
    "binary": obfuscate_binary,
    "url_encode": obfuscate_url_encode,
    "html_entities": obfuscate_html_entities,
    "caesar_3": obfuscate_caesar_3,
    "caesar_7": obfuscate_caesar_7,
    "xor": obfuscate_xor,
    "morse": obfuscate_morse,
    "mixed": obfuscate_mixed,
    "double_base64": obfuscate_double_base64,
}

# --- Display Styling (for the wrapper) ---

def create_circled_char_map():
    """Creates a mapping from standard characters to circled Unicode characters."""
    lowercase_map = {chr(ord('a') + i): chr(0x24D0 + i) for i in range(26)}
    uppercase_map = {chr(ord('A') + i): chr(0x24B6 + i) for i in range(26)}
    number_map = {
        '1': '①', '2': '②', '3': '③', '4': '④', '5': '⑤', 
        '6': '⑥', '7': '⑦', '8': '⑧', '9': '⑨', '0': '⓪'
    }
    full_map = {**lowercase_map, **uppercase_map, **number_map}
    return full_map

def apply_circled_unicode_styling(text: str, char_map: dict) -> str:
    """
    Applies circled Unicode styling to the given text string.
    This is used for the *outer display wrapper*, not the payload encoding itself.
    """
    styled_chars = [char_map.get(char, char) for char in text]
    return "".join(styled_chars)

# --- Utility Functions (Clipboard, etc.) ---

def _run_clipboard_command(cmd_args: list, text: str, timeout_seconds: int) -> bool:
    """
    Helper to run a clipboard command using Popen, with explicit timeout and termination.
    Returns True on success, False on failure.
    """
    process = None
    stdout, stderr = "", "" # Initialize to empty strings
    try:
        # Use Popen for more control over timeout and termination
        # capture_output=True pipes stdout and stderr; text=True decodes them
        process = subprocess.Popen(cmd_args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        
        # Communicate with the process, applying the timeout
        stdout, stderr = process.communicate(input=text, timeout=timeout_seconds)
        
        if process.returncode != 0:
            print(f"[ERROR] Command '{' '.join(cmd_args)}' failed with exit code {process.returncode}.")
            if stdout: print(f"       Stdout (if any): {stdout.strip()}")
            if stderr: print(f"       Stderr (if any): {stderr.strip()}")
            return False
        return True
    except FileNotFoundError:
        print(f"[ERROR] Clipboard command '{cmd_args[0]}' not found. Please ensure it's installed and in your PATH.")
        return False
    except subprocess.TimeoutExpired:
        print(f"[ERROR] Clipboard command '{' '.join(cmd_args)}' timed out after {timeout_seconds} seconds.")
        print(f"       This indicates the clipboard utility itself is hanging.")
        if stdout: print(f"       Stdout (if any, before timeout): {stdout.strip()}")
        if stderr: print(f"       Stderr (if any, before timeout): {stderr.strip()}")
        if process:
            try:
                # Terminate the process gently, then kill if it doesn't respond
                process.terminate()
                process.wait(timeout=1) # Give it 1 second to terminate
                if process.poll() is None: # Still running?
                    print("[WARNING] Clipboard command did not terminate gracefully; sending SIGKILL.")
                    process.kill()
                    process.wait(timeout=1) # Give it 1 second to die
            except Exception as e:
                print(f"[CRITICAL] Error attempting to terminate hanging clipboard process: {e}")
        return False
    except Exception as e:
        print(f"[ERROR] An unexpected error occurred while running clipboard command: {e}")
        if process:
            try:
                process.kill() # Ensure it's killed even on unexpected errors
            except Exception:
                pass
        return False
    finally:
        # Final safeguard: ensure the process is dead if it somehow wasn't caught above
        if process and process.poll() is None: 
            try:
                print("[WARNING] Clipboard process still active in finally block; sending SIGKILL.")
                process.kill()
                process.wait(timeout=1)
            except Exception:
                pass

def copy_to_clipboard(text: str, timeout_seconds: int = 5):
    """
    Copies the given text to the system clipboard using platform-specific commands.
    Includes a timeout and explicit process termination to prevent hangs.
    """
    print(f"[INFO] Attempting to copy to clipboard (platform: {sys.platform})...")

    if sys.platform == 'darwin':
        if _run_clipboard_command(['pbcopy'], text, timeout_seconds):
            print("[INFO] Obfuscated text copied to clipboard (macOS).")
        else:
            print("[ERROR] Failed to copy to clipboard on macOS. See above for details.")
    elif sys.platform.startswith('linux'):
        copied = False
        
        # 1. Try wl-copy (Wayland) if WAYLAND_DISPLAY is set
        if os.environ.get('WAYLAND_DISPLAY'):
            print("[INFO] Wayland detected. Trying 'wl-copy'...")
            if _run_clipboard_command(['wl-copy'], text, timeout_seconds):
                print("[INFO] Obfuscated text copied to clipboard (Linux Wayland - wl-copy).")
                copied = True
            else:
                print("[ERROR] 'wl-copy' attempt failed. Trying 'xclip' as fallback.")
        
        # 2. If not copied, try xclip (X11) if DISPLAY is set
        if not copied and os.environ.get('DISPLAY'):
            print("[INFO] X11 display detected or Wayland copy failed. Trying 'xclip'...")
            if _run_clipboard_command(['xclip', '-selection', 'clipboard'], text, timeout_seconds):
                print("[INFO] Obfuscated text copied to clipboard (Linux X11 - xclip).")
                copied = True
        
        if not copied:
            print("[ERROR] Failed to copy to clipboard on Linux after trying all methods.")
            print("       This often means the clipboard utility (wl-copy or xclip) is not installed,")
            print("       not configured correctly, or your display environment's clipboard service is unresponsive.")
            print("       Please ensure either 'wl-copy' (for Wayland) or 'xclip' (for X11) is installed and accessible,")
            print("       and that your clipboard service is functioning normally.")
    elif sys.platform == 'win32':
        if _run_clipboard_command(['clip'], text, timeout_seconds):
            print("[INFO] Obfuscated text copied to clipboard (Windows).")
        else:
            print("[ERROR] Failed to copy to clipboard on Windows. See above for details.")
    else:
        print(f"[WARNING] Clipboard copy not supported on '{sys.platform}'.")
        print("       The obfuscated text is printed above, please copy it manually.")

# --- Main Application Logic ---

def main():
    parser = argparse.ArgumentParser(
        description="A prompt obfuscator for red-team engagements with multiple techniques.",
        epilog="Example: python bubblefi.py \"Hello, world!\" --technique base64\n"
               "         python bubblefi.py # Runs in interactive mode"
    )
    parser.add_argument(
        "prompt",
        type=str,
        nargs='?', # Make it optional
        help="The text prompt to obfuscate. If omitted, an interactive prompt will appear."
    )
    parser.add_argument(
        "--technique",
        type=str,
        choices=list(obfuscation_techniques.keys()),
        default="direct", # Default to direct
        help="The obfuscation technique to apply to the payload. If omitted or 'direct' with no prompt, an interactive menu will appear."
    )
    
    args = parser.parse_args()

    actual_prompt = args.prompt
    actual_technique = args.technique
    
    # Determine if we should enter interactive mode
    # Interactive mode if:
    # 1. No prompt was given AND technique is default OR
    # 2. Only the script name was called (len(sys.argv) == 1)
    # AND we are running in a TTY (not piped input)
    interactive_mode = False
    if sys.stdin.isatty():
        if actual_prompt is None:
            interactive_mode = True
        elif actual_technique == "direct" and len(sys.argv) == 1: # No args at all -> interactive
            interactive_mode = True

    if interactive_mode:
        print("\n--- Interactive Obfuscator ---")
        if actual_prompt is None:
            try:
                actual_prompt = input("Enter the text you want to obfuscate: ").strip()
                if not actual_prompt:
                    print("[ERROR] No prompt text provided. Exiting.")
                    sys.exit(1)
            except EOFError:
                print("\n[ERROR] Input interrupted (EOF). Exiting.")
                sys.exit(1)
            except KeyboardInterrupt:
                print("\n[ERROR] Operation cancelled (Ctrl+C). Exiting.")
                sys.exit(1)
        
        # Offer technique selection if it's still default or if we just entered interactive mode
        if actual_technique == "direct":
            print("\nAvailable Obfuscation Techniques:")
            tech_names = list(obfuscation_techniques.keys())
            for i, tech_name in enumerate(tech_names):
                print(f"  {i+1}. {tech_name}")
            
            while True:
                try:
                    choice_prompt = f"Select a technique (1-{len(tech_names)}) or type name [{actual_technique}]: "
                    choice = input(choice_prompt).strip().lower()
                    
                    if not choice: # User pressed enter, use current actual_technique (default or already set)
                        break
                    
                    if choice.isdigit():
                        idx = int(choice) - 1
                        if 0 <= idx < len(tech_names):
                            actual_technique = tech_names[idx]
                            break
                        else:
                            print("[WARNING] Invalid number. Please enter a number from the list.")
                    elif choice in obfuscation_techniques:
                        actual_technique = choice
                        break
                    else:
                        print("[WARNING] Invalid selection. Please try again.")
                except EOFError:
                    print("\n[ERROR] Input interrupted (EOF). Exiting.")
                    sys.exit(1)
                except KeyboardInterrupt:
                    print("\n[ERROR] Operation cancelled (Ctrl+C). Exiting.")
                    sys.exit(1)
    
    # If, after interactive mode, no prompt was somehow set (e.g., user just pressed enter)
    if not actual_prompt:
        print("[ERROR] No prompt text provided for obfuscation. Exiting.")
        sys.exit(1)

    # 1. Apply the selected obfuscation technique to the core prompt
    payload_content = actual_prompt
    try:
        if actual_technique in obfuscation_techniques:
            payload_content = obfuscation_techniques[actual_technique](actual_prompt)
            print(f"[INFO] Applied '{actual_technique}' obfuscation.")
        else:
            print(f"[WARNING] Unknown obfuscation technique '{actual_technique}'. Using direct (unobfuscated) payload.")
    except Exception as e:
        print(f"[ERROR] Failed to apply obfuscation technique '{actual_technique}': {e}")
        print("[INFO] Falling back to direct (unobfuscated) payload content.")

    # 2. Construct the full UserQuery string with the obfuscated payload
    user_query_string = f"  (UserQuery: {payload_content})"

    # 3. Apply the outer circled Unicode styling to the entire UserQuery string for display
    circled_char_map = create_circled_char_map()
    final_display_text_inner = apply_circled_unicode_styling(user_query_string, circled_char_map)
    
    # 4. Construct the complete output block including the frame
    full_output_block = f".-.-.-.-<=|\n{final_display_text_inner}\n|=>-.-.-.-."

    # Print the stylized output
    print(full_output_block)

    # Copy the COMPLETE OUTPUT BLOCK to clipboard
    copy_to_clipboard(full_output_block)

if __name__ == "__main__":
    main()
