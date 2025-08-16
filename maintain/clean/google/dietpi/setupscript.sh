#!/bin/bash

# Set permissions for the notebook file
chmod +x /content/Takeout_Processing_and_Organization_Script.ipynb

# Define paths and URLs
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/your-github-username/your-repo-name/main/takeout_processor.py" # Replace with the actual URL
PROCESSOR_SCRIPT_PATH="/content/takeout_processor.py"
AUTOSTART_SCRIPT_PATH="/root/.config/startup/run_takeout_processor.sh"

# Create necessary directories
mkdir -p /root/.config/startup
mkdir -p /content/drive/MyDrive/TakeoutProject/00-ALL-ARCHIVES/
mkdir -p /content/drive/MyDrive/TakeoutProject/01-PROCESSING-STAGING/
mkdir -p /content/drive/MyDrive/TakeoutProject/03-organized/My-Photos/
mkdir -p /content/drive/MyDrive/TakeoutProject/04-trash/quarantined_artifacts/
mkdir -p /content/drive/MyDrive/TakeoutProject/04-trash/duplicates/
mkdir -p /content/drive/MyDrive/TakeoutProject/05-COMPLETED-ARCHIVES/

# Download the processor script
# Corrected curl command: use -o to specify the output file path
curl -sSl "$PROCESSOR_SCRIPT_URL" -o "$PROCESSOR_SCRIPT_PATH"

# Make the processor script executable
chmod +x "$PROCESSOR_SCRIPT_PATH"

# Create the autostart script
cat <<EOF > "$AUTOSTART_SCRIPT_PATH"
#!/bin/bash
python "$PROCESSOR_SCRIPT_PATH"
EOF

# Make the autostart script executable
chmod +x "$AUTOSTART_SCRIPT_PATH"

echo "Setup complete. The takeout processor script is downloaded and configured to run on startup."
