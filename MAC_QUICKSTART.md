# 🍎 Guide Rapide - Mac vers Serveur GPU

Guide ultra-simplifié pour utiliser SimulStreaming depuis votre Mac.

## ⚡ Démarrage en 5 Minutes

### 1️⃣ Sur le Serveur GPU (Une seule fois)

```bash
# SSH vers votre serveur
ssh user@votre-serveur-gpu

# Cloner et démarrer
git clone https://github.com/mmaudet/SimulStreaming.git
cd SimulStreaming
cp .env.example .env

# Construire et démarrer
docker build -f Dockerfile.whisper -t simulstreaming-whisper:latest .
docker compose up -d

# Vérifier que ça tourne
docker compose ps
```

Notez l'adresse IP du serveur :
```bash
hostname -I
# Exemple de sortie: 192.168.1.100
```

### 2️⃣ Sur Votre Mac

#### Installation des outils (Une seule fois)

```bash
# Installer Homebrew si nécessaire
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Installer Sox et FFmpeg
brew install sox ffmpeg

# Télécharger le script de connexion
curl -O https://raw.githubusercontent.com/mmaudet/SimulStreaming/main/scripts/mac-connect.sh
chmod +x mac-connect.sh
```

#### Configuration du script

```bash
# Éditer la configuration
nano mac-connect.sh

# Modifier ces lignes (en haut du fichier) :
SERVEUR_IP="192.168.1.100"      # <- VOTRE IP serveur
SERVEUR_USER="ubuntu"           # <- VOTRE username SSH
USE_SSH_TUNNEL=true             # true si serveur distant, false si réseau local
```

### 3️⃣ Utilisation

```bash
# Lancer le script
./mac-connect.sh

# Puis suivre le menu interactif :
# - Option 1 : Utiliser votre microphone
# - Option 2 : Envoyer un fichier audio
# - Option 3 : Tester la connexion
```

## 🎯 Exemples d'Usage Rapide

### Transcription Microphone en Direct

```bash
# Tunnel SSH + Microphone
ssh -f -N -L 43001:localhost:43001 user@serveur-gpu
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc localhost 43001
```

### Transcription d'un Fichier Audio

```bash
# Tunnel SSH + Fichier
ssh -f -N -L 43001:localhost:43001 user@serveur-gpu
ffmpeg -i podcast.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | nc localhost 43001
```

### Sans Tunnel SSH (Réseau Local)

```bash
# Direct avec IP du serveur
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc 192.168.1.100 43001
```

## 📋 Configuration SSH Persistante (Recommandé)

Ajoutez dans `~/.ssh/config` :

```
Host simulstreaming
    HostName 192.168.1.100
    User ubuntu
    LocalForward 43001 localhost:43001
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Puis simplement :
```bash
# Créer le tunnel
ssh -N simulstreaming &

# Utiliser le service
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc localhost 43001
```

## 🔧 Formats Audio Supportés

Le script convertit automatiquement ces formats :
- MP3, M4A, AAC
- WAV, FLAC, OGG
- MP4, MOV (extrait l'audio)
- Et plus...

Exemple :
```bash
ffmpeg -i video.mp4 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | nc localhost 43001
```

## 📊 Sortie Attendue

Format de transcription :
```
1200 0 1200  Bonjour
2400 1200 2400  comment
3600 2400 3600  allez-vous
4800 3600 4800  aujourd'hui
6000 4800 6000  ?
```

Colonnes :
1. Temps d'émission (ms)
2. Début du segment (ms)
3. Fin du segment (ms)
4. Texte transcrit

## ⚙️ Paramètres Français

Le serveur est déjà configuré pour le français dans `.env` :

```bash
WHISPER_LANGUAGE=fr
WHISPER_TASK=transcribe
```

Pour changer :
```bash
# Sur le serveur
ssh user@serveur-gpu
cd SimulStreaming
nano .env

# Modifier puis redémarrer
docker compose restart whisper-asr
```

## 🚨 Dépannage Express

### "Connection refused"
```bash
# Vérifier que le service tourne
ssh user@serveur-gpu "docker compose ps"

# Relancer si nécessaire
ssh user@serveur-gpu "cd SimulStreaming && docker compose up -d"
```

### "Command not found: rec"
```bash
brew install sox
```

### "Command not found: ffmpeg"
```bash
brew install ffmpeg
```

### Tunnel SSH qui ne fonctionne pas
```bash
# Tester SSH d'abord
ssh user@serveur-gpu

# Si ça marche, créer le tunnel
ssh -L 43001:localhost:43001 user@serveur-gpu

# Dans un autre terminal, tester
nc -zv localhost 43001
```

### Pas de sortie / silence
```bash
# Vérifier les logs du serveur
ssh user@serveur-gpu "docker compose logs whisper-asr"

# Tester avec un message simple
echo "test" | nc localhost 43001
```

## 📱 Alternatives GUI (Interfaces Graphiques)

### Utiliser un navigateur Web (À venir)

Pour une interface Web, vous pouvez créer un tunnel HTTP :
```bash
ssh -L 8080:localhost:8080 user@serveur-gpu
```

### Utiliser Audacity pour enregistrer

1. Ouvrir Audacity
2. Exporter en WAV 16kHz mono
3. Utiliser le script pour envoyer le fichier

## 🔐 Sécurité

### Pour une connexion Internet (hors réseau local)

**Toujours utiliser un tunnel SSH** - Ne jamais exposer le port 43001 directement :

```bash
# BON ✓
ssh -L 43001:localhost:43001 user@serveur-public.com

# MAUVAIS ✗ (non sécurisé)
nc serveur-public.com 43001
```

### Clés SSH

Configurez l'authentification par clé :
```bash
# Générer une clé (si vous n'en avez pas)
ssh-keygen -t ed25519

# Copier vers le serveur
ssh-copy-id user@serveur-gpu

# Maintenant vous pouvez vous connecter sans mot de passe
ssh user@serveur-gpu
```

## 📖 Documentation Complète

- **`REMOTE_DEPLOYMENT.md`** - Guide détaillé avec toutes les options
- **`DOCKER_README.md`** - Configuration Docker complète
- **`CLAUDE.md`** - Architecture et développement

## 💡 Astuces Pro

### Enregistrer la transcription dans un fichier
```bash
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | \
    nc localhost 43001 | \
    tee transcription_$(date +%Y%m%d_%H%M%S).txt
```

### Afficher uniquement le texte (sans timestamps)
```bash
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | \
    nc localhost 43001 | \
    awk '{$1=$2=$3=""; print substr($0,4)}'
```

### Utiliser avec un fichier de sous-titres
```bash
ffmpeg -i video.mp4 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001 | \
    awk '{print $1/1000 " " $2/1000 " " substr($0, index($0,$4))}' > subtitles.srt
```

## 🎓 Exemples Pratiques

### Podcast en français
```bash
ffmpeg -i podcast_fr.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001 > podcast_transcription.txt
```

### Réunion Zoom (fichier audio)
```bash
ffmpeg -i reunion_zoom.m4a -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001 > reunion_notes.txt
```

### Vidéo YouTube (après téléchargement)
```bash
# Télécharger d'abord avec youtube-dl ou yt-dlp
yt-dlp -x --audio-format mp3 "URL_VIDEO"

# Puis transcrire
ffmpeg -i video.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001 > video_transcription.txt
```

---

**Besoin d'aide ?** Consultez `REMOTE_DEPLOYMENT.md` pour le guide complet !
