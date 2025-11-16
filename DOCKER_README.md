# Docker Deployment Guide for SimulStreaming

This guide explains how to deploy SimulStreaming using Docker with support for French and other languages.

## Prerequisites

- Docker (version 20.10+)
- Docker Compose (version 2.0+)
- NVIDIA Docker runtime (nvidia-docker2) for GPU support
- At least 30GB free disk space for models

### GPU Support Setup

```bash
# Install NVIDIA Docker runtime
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
    sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

## Quick Start

### 1. Setup Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit configuration for French (or other language)
nano .env
```

Example `.env` for French transcription:
```bash
WHISPER_LANGUAGE=fr
WHISPER_TASK=transcribe
WHISPER_MIN_CHUNK_SIZE=1.2
WHISPER_FRAME_THRESHOLD=25
WHISPER_BEAMS=1
```

### 2. Download Models

```bash
# Run the model setup script
./scripts/setup-models.sh
```

This will:
- Download Whisper large-v3 model (~3GB)
- Optionally download and convert EuroLLM-9B-Instruct (~20GB)

### 3. Build Docker Images

```bash
# Build all services
docker-compose build

# Or build specific service
docker-compose build whisper-asr
```

### 4. Start Services

```bash
# Start all services (Whisper + Translation)
docker-compose up -d

# Or start only Whisper ASR
docker-compose up whisper-asr

# Or use convenience script
./scripts/run-whisper-only.sh
```

## Usage

### Real-time Audio from Microphone (Linux)

```bash
# Start the service
docker-compose up -d whisper-asr

# Connect microphone
arecord -f S16_LE -c1 -r 16000 -t raw -D default | nc localhost 43001
```

### Process Audio File

```bash
# Using convenience script
./scripts/test-audio-pipeline.sh your-audio.wav

# Or manually with docker run
docker run --rm --gpus all \
    -v $(pwd)/models/whisper:/models \
    -v $(pwd)/your-audio.wav:/audio/input.wav:ro \
    simulstreaming-whisper:latest \
    python3 simulstreaming_whisper.py \
    /audio/input.wav \
    --language fr \
    --task transcribe \
    --comp_unaware
```

### With Translation Pipeline

```bash
# Start both services
docker-compose up -d

# Process through both ASR and translation
# (Input audio -> Whisper ASR -> EuroLLM Translation)
cat audio.wav | docker-compose exec -T whisper-asr \
    python3 simulstreaming_whisper.py - --language en --task transcribe | \
    docker-compose exec -T translation \
    python3 translate/simul_llm_translate.py --language fr
```

## Configuration

### Language Options

Set `WHISPER_LANGUAGE` in `.env`:
- `fr` - French
- `en` - English
- `de` - German
- `es` - Spanish
- `it` - Italian
- `auto` - Automatic detection

### Task Options

Set `WHISPER_TASK` in `.env`:
- `transcribe` - Speech-to-text in source language
- `translate` - Speech-to-English translation (direct from Whisper)

### Performance Tuning

**For lower latency:**
```bash
WHISPER_MIN_CHUNK_SIZE=0.8
WHISPER_FRAME_THRESHOLD=15
```

**For higher quality:**
```bash
WHISPER_MIN_CHUNK_SIZE=2.0
WHISPER_FRAME_THRESHOLD=35
WHISPER_BEAMS=5
```

## Architecture

```
┌─────────────────┐
│  Audio Input    │
│  (Microphone    │
│   or File)      │
└────────┬────────┘
         │
         │ Raw audio (16kHz mono)
         │
         v
┌─────────────────────────────┐
│  Whisper ASR Service        │
│  (Container: whisper-asr)   │
│                             │
│  - Port: 43001              │
│  - GPU: 1 device            │
│  - AlignAtt Policy          │
│  - Voice Activity Detection │
└────────┬────────────────────┘
         │
         │ Timestamped text
         │
         v
┌─────────────────────────────┐
│  EuroLLM Translation        │
│  (Container: translation)   │
│                             │
│  - GPU: 1 device            │
│  - LocalAgreement Policy    │
│  - Context Management       │
└────────┬────────────────────┘
         │
         │ Translated text
         │
         v
┌─────────────────┐
│  Output         │
└─────────────────┘
```

## Troubleshooting

### GPU not detected

```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Check docker-compose GPU configuration
docker-compose config
```

### Model download issues

```bash
# Manual Whisper model download
python3 -c "import whisper; whisper.load_model('large-v3')"
cp ~/.cache/whisper/large-v3.pt models/whisper/

# Manual EuroLLM download
cd models
git lfs install
git clone https://huggingface.co/utter-project/EuroLLM-9B-Instruct
```

### Connection refused to port 43001

```bash
# Check service status
docker-compose ps

# Check logs
docker-compose logs whisper-asr

# Verify port is accessible
docker-compose exec whisper-asr netstat -tuln | grep 43001
```

### Out of memory errors

```bash
# Reduce beam size
WHISPER_BEAMS=1

# Or reduce context length for translation
TRANSLATION_MAX_CONTEXT_LENGTH=150
```

## Monitoring

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f whisper-asr

# Check resource usage
docker stats
```

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop specific service
docker-compose stop whisper-asr
```

## Development

### Rebuild after code changes

```bash
# Rebuild specific service
docker-compose build whisper-asr

# Restart service
docker-compose up -d whisper-asr
```

### Run tests inside container

```bash
# Execute command in running container
docker-compose exec whisper-asr python3 -m pytest

# Or start interactive shell
docker-compose exec whisper-asr bash
```

## Production Considerations

1. **Model Persistence**: Models are mounted as volumes, ensure backup
2. **Logging**: Configure log rotation for production
3. **Monitoring**: Add Prometheus/Grafana for metrics
4. **Security**: Use firewall rules to restrict port access
5. **Scaling**: Use Docker Swarm or Kubernetes for horizontal scaling

## License

See main LICENSE.txt file.
