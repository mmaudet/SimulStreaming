#!/bin/bash
# Script de connexion à SimulStreaming distant depuis Mac
# Usage: ./mac-connect.sh

# ============================================
# CONFIGURATION - À MODIFIER SELON VOS BESOINS
# ============================================

SERVEUR_IP="192.168.1.100"      # IP du serveur GPU (modifiez cette valeur)
SERVEUR_PORT="43001"             # Port du service Whisper
SERVEUR_USER="ubuntu"            # Nom d'utilisateur SSH (modifiez cette valeur)
USE_SSH_TUNNEL=true              # true pour tunnel SSH, false pour connexion directe

# ============================================
# NE PAS MODIFIER EN DESSOUS DE CETTE LIGNE
# ============================================

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo "╔════════════════════════════════════════╗"
echo "║   SimulStreaming - Connexion Mac      ║"
echo "║   Vers serveur GPU distant            ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Fonction pour vérifier les dépendances
check_dependencies() {
    local missing=0

    echo -e "${BLUE}Vérification des dépendances...${NC}"

    # Vérifier Sox
    if ! command -v rec &> /dev/null; then
        echo -e "${RED}✗ Sox non installé${NC}"
        echo "  Installez avec: brew install sox"
        missing=1
    else
        echo -e "${GREEN}✓ Sox installé${NC}"
    fi

    # Vérifier FFmpeg
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}✗ FFmpeg non installé${NC}"
        echo "  Installez avec: brew install ffmpeg"
        missing=1
    else
        echo -e "${GREEN}✓ FFmpeg installé${NC}"
    fi

    # Vérifier Netcat
    if ! command -v nc &> /dev/null; then
        echo -e "${RED}✗ Netcat non installé${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Netcat installé${NC}"
    fi

    # Vérifier SSH (si tunnel activé)
    if [ "$USE_SSH_TUNNEL" = true ]; then
        if ! command -v ssh &> /dev/null; then
            echo -e "${RED}✗ SSH non installé${NC}"
            missing=1
        else
            echo -e "${GREEN}✓ SSH installé${NC}"
        fi
    fi

    echo ""

    if [ $missing -eq 1 ]; then
        echo -e "${RED}Des dépendances sont manquantes. Veuillez les installer avant de continuer.${NC}"
        exit 1
    fi
}

# Fonction pour tester la connexion directe
connect_direct() {
    echo -e "${BLUE}Mode: Connexion directe${NC}"
    echo "Serveur: $SERVEUR_IP:$SERVEUR_PORT"
    echo ""

    # Tester la connexion
    echo "Test de connexion..."
    if nc -z -w 5 $SERVEUR_IP $SERVEUR_PORT 2>/dev/null; then
        echo -e "${GREEN}✓ Serveur accessible sur $SERVEUR_IP:$SERVEUR_PORT${NC}"
        return 0
    else
        echo -e "${RED}✗ Impossible de se connecter à $SERVEUR_IP:$SERVEUR_PORT${NC}"
        echo ""
        echo "Vérifiez que :"
        echo "  1. Le serveur est démarré"
        echo "  2. Docker compose tourne (docker compose ps)"
        echo "  3. Le firewall autorise le port $SERVEUR_PORT"
        echo "  4. Vous êtes sur le même réseau"
        return 1
    fi
}

# Fonction pour créer un tunnel SSH
connect_ssh_tunnel() {
    echo -e "${BLUE}Mode: Tunnel SSH${NC}"
    echo "Serveur: $SERVEUR_USER@$SERVEUR_IP"
    echo ""

    # Vérifier si un tunnel existe déjà
    if lsof -ti:43001 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Port 43001 déjà utilisé${NC}"
        read -p "Voulez-vous fermer la connexion existante ? [O/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]] || [[ -z $REPLY ]]; then
            echo "Fermeture de la connexion existante..."
            kill $(lsof -ti:43001) 2>/dev/null || true
            sleep 2
        else
            echo "Utilisation du tunnel existant..."
            SERVEUR_IP="localhost"
            return 0
        fi
    fi

    # Créer le tunnel SSH
    echo "Création du tunnel SSH..."
    echo "Commande: ssh -f -N -L 43001:localhost:43001 $SERVEUR_USER@$SERVEUR_IP"

    ssh -f -N -L 43001:localhost:43001 $SERVEUR_USER@$SERVEUR_IP

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Tunnel SSH créé avec succès${NC}"
        sleep 2

        # Tester le tunnel
        if nc -z -w 5 localhost 43001 2>/dev/null; then
            echo -e "${GREEN}✓ Tunnel fonctionnel${NC}"
            SERVEUR_IP="localhost"
            return 0
        else
            echo -e "${RED}✗ Tunnel créé mais service non accessible${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Échec de création du tunnel SSH${NC}"
        echo ""
        echo "Vérifiez que :"
        echo "  1. Vous pouvez vous connecter en SSH : ssh $SERVEUR_USER@$SERVEUR_IP"
        echo "  2. Le service Docker tourne sur le serveur"
        echo "  3. Votre clé SSH est correctement configurée"
        return 1
    fi
}

# Fonction pour envoyer l'audio du microphone
send_microphone() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Enregistrement Microphone            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Configuration:"
    echo "  • Format: PCM 16-bit, mono"
    echo "  • Fréquence: 16 kHz"
    echo "  • Serveur: $SERVEUR_IP:$SERVEUR_PORT"
    echo ""
    echo -e "${YELLOW}Appuyez sur Ctrl+C pour arrêter l'enregistrement${NC}"
    echo ""

    # Petit délai pour que l'utilisateur puisse lire
    sleep 2

    # Lancer l'enregistrement et l'envoi
    rec -t raw -b 16 -c 1 -e signed-integer -r 16000 - 2>/dev/null | nc $SERVEUR_IP $SERVEUR_PORT
}

# Fonction pour envoyer un fichier audio
send_file() {
    echo ""
    read -p "Chemin du fichier audio (ou glissez-déposez le fichier): " audio_file

    # Nettoyer le chemin (enlever les guillemets si présents)
    audio_file="${audio_file//\'/}"
    audio_file="${audio_file//\"/}"
    audio_file="${audio_file// /\\ }"

    # Évaluer le chemin (pour résoudre ~)
    audio_file=$(eval echo $audio_file)

    if [ ! -f "$audio_file" ]; then
        echo -e "${RED}✗ Fichier non trouvé: $audio_file${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}Traitement de: $audio_file${NC}"

    # Obtenir les infos du fichier
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null)
    if [ ! -z "$duration" ]; then
        echo "Durée: ${duration%.*} secondes"
    fi

    echo ""
    echo "Conversion et envoi en cours..."
    echo -e "${YELLOW}La transcription apparaîtra en temps réel...${NC}"
    echo ""

    # Convertir et envoyer
    ffmpeg -i "$audio_file" -f s16le -acodec pcm_s16le -ar 16000 -ac 1 - 2>/dev/null | \
        nc $SERVEUR_IP $SERVEUR_PORT

    echo ""
    echo -e "${GREEN}✓ Envoi terminé${NC}"
}

# Fonction pour tester la connexion
test_connection() {
    echo ""
    echo -e "${BLUE}Test de connexion au serveur...${NC}"
    echo ""

    # Envoyer un message de test
    echo "TEST_CONNECTION" | nc -w 5 $SERVEUR_IP $SERVEUR_PORT

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connexion réussie${NC}"
        echo "Le serveur est prêt à recevoir de l'audio"
    else
        echo -e "${RED}✗ Échec de connexion${NC}"
    fi
}

# Fonction pour afficher les statistiques du serveur
show_server_stats() {
    if [ "$USE_SSH_TUNNEL" = true ] || [ "$SERVEUR_IP" = "localhost" ]; then
        # Utiliser SSH pour obtenir les stats
        local original_ip=$(echo $SERVEUR_IP | grep -v localhost | head -1)
        if [ -z "$original_ip" ]; then
            # Extraire l'IP de la config au début du script
            original_ip=$(grep "^SERVEUR_IP=" "$0" | cut -d'"' -f2)
        fi

        echo ""
        echo -e "${BLUE}Statistiques du serveur GPU...${NC}"
        echo ""

        echo "=== État des conteneurs ==="
        ssh $SERVEUR_USER@$original_ip "docker compose ps" 2>/dev/null || echo "Impossible de se connecter"

        echo ""
        echo "=== Utilisation GPU ==="
        ssh $SERVEUR_USER@$original_ip "nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader" 2>/dev/null || echo "Impossible d'obtenir les stats GPU"

        echo ""
        echo "=== Logs récents ==="
        ssh $SERVEUR_USER@$original_ip "docker compose logs --tail=10 whisper-asr" 2>/dev/null || echo "Impossible d'obtenir les logs"
    else
        echo -e "${YELLOW}Les statistiques ne sont disponibles qu'en mode tunnel SSH${NC}"
    fi
}

# Fonction pour nettoyer à la sortie
cleanup() {
    echo ""
    if [ "$USE_SSH_TUNNEL" = true ] && [ "$SERVEUR_IP" = "localhost" ]; then
        read -p "Voulez-vous fermer le tunnel SSH ? [O/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]] || [[ -z $REPLY ]]; then
            echo "Fermeture du tunnel SSH..."
            kill $(lsof -ti:43001) 2>/dev/null || true
            echo -e "${GREEN}✓ Tunnel fermé${NC}"
        else
            echo -e "${YELLOW}Tunnel SSH maintenu actif${NC}"
        fi
    fi
}

# Trap pour nettoyer à la sortie
trap cleanup EXIT

# ============================================
# PROGRAMME PRINCIPAL
# ============================================

# Vérifier les dépendances
check_dependencies

# Établir la connexion
if [ "$USE_SSH_TUNNEL" = true ]; then
    connect_ssh_tunnel || exit 1
else
    connect_direct || exit 1
fi

# Menu principal
while true; do
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║           MENU PRINCIPAL               ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "  1) 🎤 Envoyer audio du microphone"
    echo "  2) 📁 Envoyer un fichier audio"
    echo "  3) 🔍 Tester la connexion"
    echo "  4) 📊 Afficher statistiques serveur"
    echo "  5) 🚪 Quitter"
    echo ""
    read -p "Votre choix [1-5]: " choix

    case $choix in
        1)
            send_microphone
            ;;

        2)
            send_file
            ;;

        3)
            test_connection
            ;;

        4)
            show_server_stats
            ;;

        5)
            echo ""
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;

        *)
            echo -e "${RED}Option invalide${NC}"
            ;;
    esac
done
