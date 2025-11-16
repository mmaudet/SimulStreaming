# Déploiement Distant - Mac Client vers Serveur GPU

Ce guide explique comment utiliser SimulStreaming depuis votre **Mac** en se connectant à une **machine distante avec GPU** qui exécute les services Docker.

## 📐 Architecture

```
┌─────────────────────────────────┐
│  Mac (Client)                   │
│                                 │
│  • Microphone                   │
│  • Audio files                  │
│  • SSH tunnel                   │
│  • Visualization tools          │
└────────────┬────────────────────┘
             │
             │ SSH + Audio stream
             │ (Port 43001)
             │
             ↓
┌─────────────────────────────────┐
│  Serveur GPU (Docker Host)      │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Whisper ASR Container     │  │
│  │ Port: 43001               │  │
│  │ GPU: NVIDIA               │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Translation Container     │  │
│  │ GPU: NVIDIA               │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## 🖥️ Configuration du Serveur GPU

### 1. Sur le serveur GPU (Linux avec NVIDIA)

#### Installation des prérequis
```bash
# Connectez-vous au serveur
ssh user@serveur-gpu

# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Installer NVIDIA Docker Runtime
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
    sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker

# Vérifier l'accès GPU
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

#### Cloner et configurer le projet
```bash
# Cloner le repository
git clone https://github.com/mmaudet/SimulStreaming.git
cd SimulStreaming

# Configurer pour le français
cp .env.example .env
nano .env  # ou vim .env

# Contenu recommandé pour .env :
# WHISPER_LANGUAGE=fr
# WHISPER_TASK=transcribe
# WHISPER_MIN_CHUNK_SIZE=1.2
# WHISPER_FRAME_THRESHOLD=25
# WHISPER_BEAMS=1
```

#### Build et démarrage des services
```bash
# Build des images Docker
docker build -f Dockerfile.whisper -t simulstreaming-whisper:latest .
docker build -f Dockerfile.translation -t simulstreaming-translation:latest .

# (Optionnel) Télécharger les modèles
./scripts/setup-models.sh

# Démarrer les services
docker compose up -d

# Vérifier que les services tournent
docker compose ps
docker compose logs -f whisper-asr
```

#### Configuration du firewall
```bash
# Autoriser le port 43001 (si firewall actif)
sudo ufw allow 43001/tcp
# Ou pour iptables :
sudo iptables -A INPUT -p tcp --dport 43001 -j ACCEPT
```

#### Obtenir l'adresse IP du serveur
```bash
# IP locale
hostname -I

# IP publique (si accessible depuis Internet)
curl ifconfig.me
```

Notez cette adresse IP (exemple: `192.168.1.100` ou IP publique).

## 🍎 Configuration du Mac (Client)

### Option 1 : Connexion Directe (Réseau Local)

Si votre Mac et le serveur GPU sont sur le **même réseau local** :

#### 1. Tester la connectivité
```bash
# Depuis votre Mac
ping 192.168.1.100  # Remplacez par l'IP de votre serveur

# Tester le port
nc -zv 192.168.1.100 43001
```

#### 2. Envoyer l'audio depuis le microphone
```bash
# Sur Mac, installer Sox (si pas déjà fait)
brew install sox

# Envoyer l'audio du microphone vers le serveur
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc 192.168.1.100 43001
```

#### 3. Envoyer un fichier audio
```bash
# Convertir et envoyer un fichier audio
ffmpeg -i votre-fichier.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc 192.168.1.100 43001
```

### Option 2 : Tunnel SSH (Recommandé pour connexion distante)

Si le serveur est **distant** ou **derrière un firewall** :

#### 1. Créer un tunnel SSH
```bash
# Depuis votre Mac, créer un tunnel SSH
# Cela redirige le port local 43001 vers le port 43001 du serveur
ssh -L 43001:localhost:43001 user@serveur-gpu.example.com

# Ou en arrière-plan
ssh -f -N -L 43001:localhost:43001 user@serveur-gpu.example.com
```

#### 2. Utiliser le tunnel
```bash
# Maintenant, connectez-vous à localhost:43001
# L'audio sera automatiquement tunnelé vers le serveur

# Avec microphone
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc localhost 43001

# Avec fichier
ffmpeg -i audio.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001
```

### Option 3 : Script Automatisé pour Mac

#### Script de connexion automatique

Créez `~/connect-simulstreaming.sh` sur votre Mac :

```bash
#!/bin/bash
# Script de connexion à SimulStreaming distant

# Configuration
SERVEUR_IP="192.168.1.100"  # Remplacez par l'IP de votre serveur
SERVEUR_PORT="43001"
SERVEUR_USER="ubuntu"       # Remplacez par votre nom d'utilisateur
USE_SSH_TUNNEL=true         # true pour tunnel SSH, false pour connexion directe

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================"
echo "SimulStreaming - Connexion Mac"
echo "================================"
echo ""

# Fonction pour connexion directe
connect_direct() {
    echo -e "${GREEN}Mode: Connexion directe${NC}"
    echo "Serveur: $SERVEUR_IP:$SERVEUR_PORT"
    echo ""

    # Tester la connexion
    if nc -zv $SERVEUR_IP $SERVEUR_PORT 2>&1 | grep -q succeeded; then
        echo -e "${GREEN}✓ Serveur accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Serveur non accessible${NC}"
        return 1
    fi
}

# Fonction pour tunnel SSH
connect_ssh_tunnel() {
    echo -e "${GREEN}Mode: Tunnel SSH${NC}"
    echo "Serveur: $SERVEUR_USER@$SERVEUR_IP"
    echo ""

    # Vérifier si un tunnel existe déjà
    if lsof -ti:43001 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Port 43001 déjà utilisé, fermeture...${NC}"
        kill $(lsof -ti:43001) 2>/dev/null || true
        sleep 1
    fi

    # Créer le tunnel SSH
    echo "Création du tunnel SSH..."
    ssh -f -N -L 43001:localhost:43001 $SERVEUR_USER@$SERVEUR_IP

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Tunnel SSH créé${NC}"
        sleep 2
        SERVEUR_IP="localhost"
        return 0
    else
        echo -e "${RED}✗ Échec création tunnel${NC}"
        return 1
    fi
}

# Choisir le mode de connexion
if [ "$USE_SSH_TUNNEL" = true ]; then
    connect_ssh_tunnel || exit 1
else
    connect_direct || exit 1
fi

# Menu de sélection
echo ""
echo "Choisissez une option:"
echo "  1) Envoyer audio du microphone"
echo "  2) Envoyer un fichier audio"
echo "  3) Tester avec un fichier d'exemple"
echo "  4) Fermer le tunnel SSH et quitter"
echo ""
read -p "Votre choix [1-4]: " choix

case $choix in
    1)
        echo ""
        echo -e "${GREEN}Démarrage du microphone...${NC}"
        echo "Appuyez sur Ctrl+C pour arrêter"
        echo ""

        # Vérifier que sox est installé
        if ! command -v rec &> /dev/null; then
            echo -e "${RED}Sox n'est pas installé. Installez-le avec:${NC}"
            echo "  brew install sox"
            exit 1
        fi

        rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc $SERVEUR_IP $SERVEUR_PORT
        ;;

    2)
        echo ""
        read -p "Chemin du fichier audio: " audio_file

        if [ ! -f "$audio_file" ]; then
            echo -e "${RED}Fichier non trouvé: $audio_file${NC}"
            exit 1
        fi

        echo -e "${GREEN}Envoi de $audio_file...${NC}"

        # Vérifier que ffmpeg est installé
        if ! command -v ffmpeg &> /dev/null; then
            echo -e "${RED}FFmpeg n'est pas installé. Installez-le avec:${NC}"
            echo "  brew install ffmpeg"
            exit 1
        fi

        ffmpeg -i "$audio_file" -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
            nc $SERVEUR_IP $SERVEUR_PORT
        ;;

    3)
        echo ""
        echo -e "${GREEN}Test de connexion...${NC}"
        echo "Test en cours..." | nc $SERVEUR_IP $SERVEUR_PORT

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Connexion réussie${NC}"
        else
            echo -e "${RED}✗ Échec de connexion${NC}"
        fi
        ;;

    4)
        if [ "$USE_SSH_TUNNEL" = true ]; then
            echo ""
            echo "Fermeture du tunnel SSH..."
            kill $(lsof -ti:43001) 2>/dev/null || true
            echo -e "${GREEN}✓ Tunnel fermé${NC}"
        fi
        exit 0
        ;;

    *)
        echo -e "${RED}Option invalide${NC}"
        exit 1
        ;;
esac

# Nettoyage à la sortie
if [ "$USE_SSH_TUNNEL" = true ]; then
    echo ""
    echo "Fermeture du tunnel SSH..."
    kill $(lsof -ti:43001) 2>/dev/null || true
fi
```

#### Rendre le script exécutable
```bash
chmod +x ~/connect-simulstreaming.sh
```

#### Utiliser le script
```bash
# Éditer la configuration au début du script
nano ~/connect-simulstreaming.sh

# Remplacer :
# SERVEUR_IP="192.168.1.100"      # avec votre IP
# SERVEUR_USER="ubuntu"           # avec votre username
# USE_SSH_TUNNEL=true             # true si serveur distant, false si local

# Lancer le script
~/connect-simulstreaming.sh
```

## 📱 Installation des Outils sur Mac

### Installer les dépendances
```bash
# Homebrew (si pas déjà installé)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Sox pour l'enregistrement microphone
brew install sox

# FFmpeg pour la conversion audio
brew install ffmpeg

# Netcat est déjà installé sur Mac
```

### Tester les outils
```bash
# Tester Sox
rec --help

# Tester FFmpeg
ffmpeg -version

# Tester Netcat
nc -h
```

## 🎙️ Utilisation Pratique

### Scénario 1 : Transcription en temps réel (Microphone)

```bash
# Avec tunnel SSH
ssh -f -N -L 43001:localhost:43001 user@serveur-gpu
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc localhost 43001

# Sans tunnel (réseau local)
rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - | nc 192.168.1.100 43001
```

Sortie attendue :
```
1200 0 1200  Bonjour
2400 1200 2400  comment
3600 2400 3600  allez-vous
4800 3600 4800  ?
```

### Scénario 2 : Transcription de fichier audio

```bash
# Avec FFmpeg (tous formats supportés)
ffmpeg -i mon-podcast.mp3 -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - | \
    nc localhost 43001 > transcription.txt

# Avec Sox (fichiers WAV)
sox mon-audio.wav -t raw -b 16 -c 1 -e signed-integer -r 16000 - | \
    nc localhost 43001 > transcription.txt
```

### Scénario 3 : Mode computationally unaware (fichier)

Pour tester avec simulation sans délai de calcul :

```bash
# Sur le serveur GPU
scp mac:mon-audio.wav /tmp/
docker compose exec whisper-asr python3 simulstreaming_whisper.py \
    /tmp/mon-audio.wav \
    --language fr \
    --task transcribe \
    --comp_unaware
```

## 🔧 Dépannage

### Problème : "Connection refused"

```bash
# Vérifier que le service tourne sur le serveur
ssh user@serveur-gpu "docker compose ps"

# Vérifier les logs
ssh user@serveur-gpu "docker compose logs whisper-asr"

# Tester la connectivité réseau
ping serveur-gpu
nc -zv serveur-gpu 43001
```

### Problème : "Broken pipe"

```bash
# Le service a peut-être planté, redémarrer
ssh user@serveur-gpu "docker compose restart whisper-asr"
```

### Problème : Audio de mauvaise qualité

```bash
# Vérifier le format audio envoyé
# Doit être: 16kHz, mono, signed 16-bit PCM

# Tester avec un fichier de test
rec -d 5 test.wav rate 16000 channels 1
sox test.wav -t raw -b 16 -c 1 -e signed-integer -r 16000 - | \
    nc localhost 43001
```

### Problème : Tunnel SSH qui se ferme

```bash
# Utiliser autossh pour maintenir le tunnel
brew install autossh

autossh -M 0 -f -N -L 43001:localhost:43001 user@serveur-gpu

# Ou avec configuration SSH persistante
# Ajouter dans ~/.ssh/config :
Host simulstreaming
    HostName serveur-gpu.example.com
    User ubuntu
    LocalForward 43001 localhost:43001
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Puis simplement :
ssh -N simulstreaming
```

## 📊 Monitoring depuis Mac

### Surveiller l'utilisation GPU sur le serveur

```bash
# En temps réel
ssh user@serveur-gpu "watch -n 1 nvidia-smi"

# Ou avec htop pour voir CPU/RAM
ssh user@serveur-gpu htop
```

### Surveiller les logs

```bash
# Logs en temps réel
ssh user@serveur-gpu "docker compose logs -f whisper-asr"

# Ou avec filtre
ssh user@serveur-gpu "docker compose logs -f whisper-asr | grep ERROR"
```

## 🌐 Accès depuis Internet (Avancé)

Si vous voulez accéder au serveur depuis n'importe où :

### Option A : SSH uniquement (Recommandé - Sécurisé)

```bash
# Configurez votre routeur pour faire du port forwarding :
# Port externe 22 → Port interne 22 (SSH) de votre serveur GPU

# Puis utilisez le tunnel SSH comme expliqué plus haut
ssh -f -N -L 43001:localhost:43001 user@votre-ip-publique
```

### Option B : Exposer le port directement (Non recommandé)

```bash
# Sur le serveur, modifier docker-compose.yml
# Changer:
ports:
  - "43001:43001"
# En:
ports:
  - "0.0.0.0:43001:43001"

# Configurer le firewall pour IP autorisées uniquement
sudo ufw allow from VOTRE_IP_MAC to any port 43001

# Configurer le routeur : Port forwarding 43001 → 43001
```

### Option C : VPN (Le plus sécurisé)

Utilisez WireGuard ou OpenVPN pour créer un réseau privé virtuel.

## 💡 Conseils de Performance

### Pour améliorer la latence

1. **Sur le serveur** - Modifier `.env` :
   ```bash
   WHISPER_MIN_CHUNK_SIZE=0.8
   WHISPER_FRAME_THRESHOLD=15
   ```

2. **Réseau** :
   - Préférer connexion Ethernet vs WiFi
   - Utiliser réseau local plutôt qu'Internet
   - Réduire la charge réseau simultanée

3. **Compression** (si bande passante limitée) :
   ```bash
   # Utiliser opus codec via SSH
   ssh -C user@serveur-gpu
   ```

### Pour améliorer la qualité

1. **Sur le serveur** - Modifier `.env` :
   ```bash
   WHISPER_BEAMS=5
   WHISPER_FRAME_THRESHOLD=35
   ```

2. **Audio** :
   - Utiliser un bon microphone
   - Environnement silencieux
   - Parler clairement

## 📋 Checklist de Déploiement

- [ ] Serveur GPU configuré avec Docker + NVIDIA runtime
- [ ] Services Docker démarrés (`docker compose up -d`)
- [ ] Port 43001 accessible (firewall configuré)
- [ ] Tunnel SSH configuré (si serveur distant)
- [ ] Sox et FFmpeg installés sur Mac
- [ ] Script de connexion configuré et testé
- [ ] Test de transcription réussi

## 📞 Support

En cas de problème, vérifier dans l'ordre :

1. `DOCKER_README.md` - Guide Docker complet
2. `CLAUDE.md` - Architecture et détails techniques
3. Logs serveur : `docker compose logs`
4. GitHub Issues : https://github.com/mmaudet/SimulStreaming/issues

---

**Dernière mise à jour**: 2025-11-16
**Compatible avec**: macOS 11+ (Big Sur et supérieur)
