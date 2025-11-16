#!/bin/bash
# Quick test script for SimulStreaming Docker deployment

set -e

echo "================================"
echo "SimulStreaming Quick Test"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker images exist
echo "Checking Docker images..."
if docker images | grep -q "simulstreaming-whisper"; then
    echo -e "${GREEN}✓${NC} Whisper image found"
else
    echo -e "${RED}✗${NC} Whisper image not found. Run: docker build -f Dockerfile.whisper -t simulstreaming-whisper:latest ."
    exit 1
fi

if docker images | grep -q "simulstreaming-translation"; then
    echo -e "${GREEN}✓${NC} Translation image found"
else
    echo -e "${YELLOW}⚠${NC} Translation image not found (optional for Whisper-only testing)"
fi

echo ""
echo "Docker images are ready!"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠${NC} .env file not found, creating from example..."
    cp .env.example .env
    echo -e "${GREEN}✓${NC} Created .env file"
fi

# Load environment
export $(cat .env | grep -v '^#' | xargs)

echo "Configuration:"
echo "  Language: ${WHISPER_LANGUAGE:-fr}"
echo "  Task: ${WHISPER_TASK:-transcribe}"
echo ""

# Test 1: Docker image inspection
echo "Test 1: Inspecting Whisper Docker image..."
docker run --rm simulstreaming-whisper:latest python3 --version
echo -e "${GREEN}✓${NC} Python version check passed"
echo ""

# Test 2: Check dependencies
echo "Test 2: Checking dependencies..."
docker run --rm simulstreaming-whisper:latest python3 -c "import torch; import librosa; import simul_whisper; print('All imports successful')"
echo -e "${GREEN}✓${NC} Dependencies check passed"
echo ""

# Test 3: Configuration validation
echo "Test 3: Validating docker-compose configuration..."
docker compose config --quiet && echo -e "${GREEN}✓${NC} docker-compose.yml is valid" || (echo -e "${RED}✗${NC} docker-compose.yml has errors" && exit 1)
echo ""

echo "================================"
echo -e "${GREEN}All tests passed!${NC}"
echo "================================"
echo ""
echo "Next steps:"
echo "  1. Download models: ./scripts/setup-models.sh"
echo "  2. Start services: docker compose up -d"
echo "  3. Test with audio: ./scripts/test-audio-pipeline.sh your-file.wav"
echo ""
echo "For French transcription, ensure your .env has:"
echo "  WHISPER_LANGUAGE=fr"
echo "  WHISPER_TASK=transcribe"
