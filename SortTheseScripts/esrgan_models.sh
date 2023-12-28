#!/bin/bash

# Define the directory where the models should be placed
# Replace this with the correct directory for your VapourSynth installation
MODEL_DIR="$HOME/.vapoursynth/vsrealesrgan/models"

# Create the model directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Define the URLs of the models to download
MODEL_URLS=(
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus.pth"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth"
)

# Download each model
for url in "${MODEL_URLS[@]}"; do
    # Get the name of the model from the URL
    model_name=$(basename "$url")

    # Download the model to the model directory
    wget -O "$MODEL_DIR/$model_name" "$url"
done

echo "Models downloaded successfully!"
