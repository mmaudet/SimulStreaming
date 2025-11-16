#!/bin/bash
# Script to download and setup models for SimulStreaming

set -e

echo "==================================="
echo "SimulStreaming Model Setup Script"
echo "==================================="

# Create model directories
mkdir -p models/whisper
mkdir -p models/EuroLLM-9B-Instruct
mkdir -p models/ct2_EuroLLM-9B-Instruct

# Function to download Whisper model
download_whisper() {
    echo ""
    echo "Downloading Whisper large-v3 model..."

    if [ ! -f "models/whisper/large-v3.pt" ]; then
        python3 -c "
import whisper
import os
import shutil

# This will download the model to cache
model = whisper.load_model('large-v3')

# Find the cached model
cache_dir = os.path.expanduser('~/.cache/whisper')
model_file = os.path.join(cache_dir, 'large-v3.pt')

if os.path.exists(model_file):
    shutil.copy(model_file, 'models/whisper/large-v3.pt')
    print('Model copied successfully!')
else:
    print('Model file not found in cache.')
"
        echo "Whisper model downloaded to models/whisper/large-v3.pt"
    else
        echo "Whisper model already exists, skipping download."
    fi
}

# Function to setup EuroLLM model
setup_eurollm() {
    echo ""
    echo "Setting up EuroLLM model..."
    echo "Note: This requires ~20GB of disk space and git-lfs"

    read -p "Do you want to download EuroLLM-9B-Instruct model? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -d "models/EuroLLM-9B-Instruct/.git" ]; then
            echo "Cloning EuroLLM-9B-Instruct from HuggingFace..."
            cd models
            git clone https://huggingface.co/utter-project/EuroLLM-9B-Instruct
            cd ..
        else
            echo "EuroLLM model already cloned, skipping."
        fi

        # Convert to CTranslate2 format
        if [ ! -f "models/ct2_EuroLLM-9B-Instruct/model.bin" ]; then
            echo "Converting EuroLLM to CTranslate2 format..."
            echo "This may take several minutes..."

            # Check if ct2-transformers-converter is installed
            if ! command -v ct2-transformers-converter &> /dev/null; then
                echo "Installing CTranslate2 converter..."
                pip3 install ctranslate2
            fi

            ct2-transformers-converter \
                --model models/EuroLLM-9B-Instruct/ \
                --output_dir models/ct2_EuroLLM-9B-Instruct \
                --quantization float16

            echo "EuroLLM model converted to CTranslate2 format!"
        else
            echo "CTranslate2 model already exists, skipping conversion."
        fi
    else
        echo "Skipping EuroLLM model download."
        echo "Note: Translation service will not work without this model."
    fi
}

# Main execution
echo ""
echo "This script will download and setup models for SimulStreaming."
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

# Install required packages if needed
echo "Checking Python dependencies..."
pip3 install -q whisper ctranslate2 2>/dev/null || true

# Download models
download_whisper
setup_eurollm

echo ""
echo "==================================="
echo "Model setup complete!"
echo "==================================="
echo ""
echo "Model locations:"
echo "  - Whisper: models/whisper/large-v3.pt"
echo "  - EuroLLM: models/EuroLLM-9B-Instruct/"
echo "  - CTranslate2: models/ct2_EuroLLM-9B-Instruct/"
echo ""
echo "You can now run: docker-compose up"
