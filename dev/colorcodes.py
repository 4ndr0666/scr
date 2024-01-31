import re

# Function to extract color codes from CSS content
def extract_css_colors(css_content):
    # Regular expression to match hex color codes
    color_regex = r"#(?:[0-9a-fA-F]{3}){1,2}"
    # Find all color codes in the CSS content
    colors = re.findall(color_regex, css_content)
    # Remove duplicates and return the list of unique colors
    unique_colors = list(set(colors))
    return unique_colors

# Extract color codes from DarkReader ChatGPT theme CSS
darkreader_colors = extract_css_colors(darkreader_css_content)

# Display the extracted colors
darkreader_colors
