#!/bin/bash
# Script to run only Whisper ASR service

set -e

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set defaults
LANGUAGE=${WHISPER_LANGUAGE:-fr}
TASK=${WHISPER_TASK:-transcribe}

echo "Starting Whisper ASR service..."
echo "Language: $LANGUAGE"
echo "Task: $TASK"
echo ""
echo "Service will be available on port 43001"
echo ""
echo "Connect with: arecord -f S16_LE -c1 -r 16000 -t raw -D default | nc localhost 43001"
echo ""

docker-compose up whisper-asr
