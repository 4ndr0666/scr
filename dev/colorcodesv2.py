# Load the content of the Brackets Dark.sublime-color-scheme file
with open('/mnt/data/Brackets Dark.sublime-color-scheme', 'r') as file:
    brackets_dark_content = file.read()

# Placeholder for the extracted colors from the DarkReader ChatGPT theme
darkreader_colors = ['#f5f5f5', '#4f9fcf', '#1c1c1c']

# Function to replace colors in the Brackets Dark scheme with DarkReader colors
def adapt_color_scheme(brackets_content, new_colors):
    # Extract the current color codes from Brackets Dark scheme
    current_colors = re.findall(r"#(?:[0-9a-fA-F]{3}){1,2}", brackets_content)

    # Mapping current colors to new colors (assumes equal number of unique colors in both schemes)
    color_map = dict(zip(set(current_colors), new_colors))

    # Replace colors in the Brackets Dark scheme
    adapted_content = brackets_content
    for old_color, new_color in color_map.items():
        adapted_content = adapted_content.replace(old_color, new_color)

    return adapted_content

# Adapt the color scheme
adapted_brackets_content = adapt_color_scheme(brackets_dark_content, darkreader_colors)

# Save the adapted color scheme to a new file
adapted_file_path = '/mnt/data/Adapted Brackets Dark.sublime-color-scheme'
with open(adapted_file_path, 'w') as file:
    file.write(adapted_brackets_content)

adapted_file_path
