#!/bin/bash
# Script to test the audio pipeline with a sample file

set -e

AUDIO_FILE=${1:-"test.wav"}

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: Audio file '$AUDIO_FILE' not found."
    echo "Usage: $0 <audio_file.wav>"
    exit 1
fi

echo "Testing SimulStreaming pipeline with $AUDIO_FILE"
echo ""

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

LANGUAGE=${WHISPER_LANGUAGE:-fr}
TASK=${WHISPER_TASK:-transcribe}

echo "Configuration:"
echo "  Language: $LANGUAGE"
echo "  Task: $TASK"
echo ""

# Test with Docker
if command -v docker &> /dev/null; then
    echo "Running test with Docker..."

    docker run --rm \
        --gpus all \
        -v "$(pwd)/models/whisper:/models" \
        -v "$(pwd)/$AUDIO_FILE:/audio/test.wav:ro" \
        simulstreaming-whisper:latest \
        python3 simulstreaming_whisper.py \
        /audio/test.wav \
        --language "$LANGUAGE" \
        --task "$TASK" \
        --comp_unaware
else
    # Test locally
    echo "Running test locally..."
    python3 simulstreaming_whisper.py \
        "$AUDIO_FILE" \
        --language "$LANGUAGE" \
        --task "$TASK" \
        --comp_unaware
fi
