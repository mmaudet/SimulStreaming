# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SimulStreaming implements the Whisper model for simultaneous speech translation and transcription using the AlignAtt policy. This system merges Simul-Whisper and Whisper-Streaming projects, adding support for large-v3 models, beam search, and cascaded machine translation via EuroLLM.

## Key Commands

### Installation
```bash
pip install -r requirements.txt
```

For lighter installation without Silero VAD, remove `torchaudio` from requirements.txt before installing.

### Running Speech-to-Text

**Real-time simulation from audio file (computationally aware):**
```bash
python3 simulstreaming_whisper.py audio.wav --language cs --task translate
```

**Computationally unaware simulation:**
```bash
python3 simulstreaming_whisper.py audio.wav --language cs --task translate --comp_unaware
```

**With VAC (Voice Activity Controller):**
```bash
python3 simulstreaming_whisper.py audio.wav --language cs --task translate --vac
```

**Server mode (real-time from microphone):**
```bash
python3 simulstreaming_whisper_server.py --language en --task translate --port 43001
```

Connect microphone on Linux:
```bash
arecord -f S16_LE -c1 -r 16000 -t raw -D default | nc localhost 43001
```

### Text-to-Text Translation (EuroLLM cascade)

First install dependencies per `translate/README.txt`, then:
```bash
python3 translate/simul_llm_translate.py --input-instance input.instance.log --min-chunk-size 1 --language de --max-context-length 300
```

## Architecture

### Core Components

**Three-layer architecture:**

1. **ASR Backend (`simul_whisper/`)**: Core AlignAtt + Whisper implementation
   - `simul_whisper/simul_whisper.py`: PaddedAlignAttWhisper class implementing AlignAtt policy
   - `simul_whisper/config.py`: AlignAttConfig and SimulWhisperConfig dataclasses
   - `simul_whisper/eow_detection.py`: End-of-word detection using CIF model
   - `simul_whisper/whisper/`: Modified OpenAI Whisper code adapted for simultaneous decoding

2. **Streaming Interface (`whisper_streaming/`)**: Online processing framework from Whisper-Streaming
   - `base.py`: ASRBase and OnlineProcessorInterface abstract classes
   - `whisper_online_main.py`: Audio loading and shared argument parsing
   - `vac_online_processor.py`: Voice Activity Controller wrapper
   - `silero_vad_iterator.py`: Silero VAD implementation
   - `whisper_server.py`: TCP server for real-time microphone input
   - `line_packet.py`: Output formatting utilities

3. **Entry Points**: Tie together backend and interface
   - `simulstreaming_whisper.py`: Main script for file simulation (SimulWhisperASR and SimulWhisperOnline classes)
   - `simulstreaming_whisper_server.py`: Server mode entry point

**Translation Cascade (`translate/`):**
- `simul_llm_translate.py`: EuroLLM-based machine translation with LocalAgreement policy
- `sentence_segmenter.py`: Sentence boundary detection
- Requires CTranslate2-converted EuroLLM model in `ct2_EuroLLM-9B-Instruct/`

### Key Algorithms

**AlignAtt Policy:**
- Attention-guided simultaneous decoding that reads ahead based on cross-attention patterns
- `--frame_threshold`: Controls lagging (lower = more aggressive, higher = more conservative)
- One frame = 0.02 seconds for large-v3 model
- Implemented in `simul_whisper/simul_whisper.py:PaddedAlignAttWhisper.infer()`

**Audio Buffering:**
- `--audio_max_len`: Maximum audio buffer (default 30s, matching Whisper's window)
- `--audio_min_len`: Skip processing if buffer too short
- `--min-chunk-size`: Minimum time between processing updates
- Audio chunks processed in `SimulWhisperOnline.process_iter()`

**End-of-Word Truncation:**
- CIF model detects incomplete words at chunk boundaries
- `--cif_ckpt_path`: Path to CIF checkpoint (get from simul_whisper repo)
- `--never_fire`: Override to never truncate (useful for large-v3 which lacks CIF model)
- Without CIF model: always trims last word by default

**Context and Prompting:**
- `--init_prompt`: Dynamic prompt in target language (scrolls with context)
- `--static_init_prompt`: Fixed terminology prompt (never scrolled out)
- `--max_context_tokens`: Context window size for cross-chunk coherence

### Simulation Modes

1. **Default (computationally aware)**: Realistic timing that accounts for processing delays
2. **`--comp_unaware`**: Timer pauses during computation to measure theoretical lower bound
3. **`--start_at START_AT`**: Debug mode to jump to specific timestamp

### Output Format

Space-separated columns:
```
<emission_time_ms> <start_ms> <end_ms> <text_fragment>
```

Server mode omits the first column. Text fragments either start with space (append with space) or punctuation (append directly).

## Important Implementation Notes

- **Model paths**: `--model_path` defaults to `./large-v3.pt`, downloads if missing
- **Beam search**: `--beams 1` uses GreedyDecoder (faster), `>1` uses beam search
- **VAD requirement**: `--vac` requires `torchaudio` (can be removed for lighter install)
- **Unicode handling**: `SimulWhisperOnline.hide_incomplete_unicode()` prevents '�' artifacts
- **Language detection**: `--language auto` enables automatic detection
- **Translation task**: Use `--task translate` for direct speech-to-text translation (no cascaded MT)

## Dependencies

- **PyTorch**: Required by simul_whisper
- **librosa**: Audio loading in whisper_streaming
- **torchaudio**: Optional, only for Silero VAD (`--vac`)
- **tiktoken**: Whisper tokenization
- **triton**: Linux x86_64 only, required by simul_whisper (version <3)

For EuroLLM translation cascade:
- **CTranslate2**: Fast inference engine
- **sentencepiece**: Tokenization
- **transformers**: Model and tokenizer loading

## Docker Deployment

SimulStreaming includes complete Docker support for easy deployment with GPU acceleration.

### Quick Start with Docker

```bash
# 1. Copy and configure environment
cp .env.example .env
# Edit .env to set WHISPER_LANGUAGE=fr for French

# 2. Build images
docker build -f Dockerfile.whisper -t simulstreaming-whisper:latest .
docker build -f Dockerfile.translation -t simulstreaming-translation:latest .

# 3. Download models (optional, for production use)
./scripts/setup-models.sh

# 4. Start services
docker compose up -d

# 5. Connect microphone (Linux)
arecord -f S16_LE -c1 -r 16000 -t raw -D default | nc localhost 43001
```

### Docker Files

- **Dockerfile.whisper**: Whisper ASR service with AlignAtt (port 43001)
- **Dockerfile.translation**: EuroLLM translation service
- **docker-compose.yml**: Orchestrates both services with GPU support
- **.env**: Configuration for language, task, and parameters

### Testing Docker Deployment

```bash
# Quick validation test
./scripts/quick-test.sh

# Test with audio file
./scripts/test-audio-pipeline.sh your-audio.wav

# Run Whisper service only
./scripts/run-whisper-only.sh
```

### French Language Configuration

Set in `.env`:
```bash
WHISPER_LANGUAGE=fr
WHISPER_TASK=transcribe  # or 'translate' for French->English
WHISPER_MIN_CHUNK_SIZE=1.2
WHISPER_FRAME_THRESHOLD=25
```

See `DOCKER_README.md` for complete deployment documentation.
