# Function to generate a reference file for default permissions
generate_permission_reference() {
    echo "Home directory: $HOME"
    reference_file="$HOME/.local/share/permissions/archcraft_default_permissions.txt"
    echo "Reference file will be saved at: $reference_file"
    mkdir -p "$(dirname "$reference_file")" || { echo "Failed to create directory"; return 1; }
    find / -type f -or -type d | xargs stat -c "%a %n" > "$reference_file" || { echo "Failed to generate reference file"; return 1; }
    echo "Reference file for default permissions has been generated."
}
