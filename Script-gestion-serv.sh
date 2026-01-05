#!/bin/bash
set -Eeuo pipefail

# === Couleurs & icônes (léger) ===
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
OK="OK"
ERR="ERREUR"
INFO="INFO"


# Icônes
OK="✅"
ERR="❌"
WARN="⚠"
INFO="ℹ"


log_ok()   { echo -e "${GREEN}${OK} $1${RESET}"; }
log_err()  { echo -e "${RED}${ERR} $1${RESET}"; }
log_info() { echo -e "${YELLOW}${INFO} $1${RESET}"; }




# === Variables globales ===
BACKUP_DEFAULT_DIR="/backups"
LOG_DIR="/var/log/serveur"

# Création répertoires si besoin
mkdir -p "$LOG_DIR" "$BACKUP_DEFAULT_DIR"


pause() { read -r -p "Appuyer sur Entrée pour continuer..."; }





# === 1. Usage des disques ===
usage_disque() {
clear
echo "==== USAGE DES DISQUES ==="
echo "Disques montés et leurs utilisations : "
echo "-----------------------------------" 
df -h | awk 'NR==1 {print; next} {printf "%-15s %-8s %-8s %-8s %s\n", $1, $2, $3, $4, $6}'
read -p "Appuie sur Entrée pour revenir au menu..."
}





# === 2. Usage des répertoires à un emplacement ===
usage_repertoire() {
clear
echo "--------USAGE DES REPERTOIRES------"
read -p "Quel répertoire veut tu voir ?" rep
# Vérifie si vide ou inexistant
    if [ -z "$rep" ] || [ ! -d "$rep" ]; then
        echo "Erreur : répertoire vide ou introuvable !"
    else
        echo "Taille de '$rep' :"
        du -sh "$rep" | cut -f1
    fi

    echo ""
    read -p "Appuie sur Entrée pour revenir..."
}






# === 3. Backup d’un répertoire  ===
backup() {
    clear
    echo "======BACKUP REPERTOIRE======"
    # Demande le dossier à sauvegarder
    read -p "Dossier à sauvegarder ? " source
    [ ! -d "$source" ] && echo "Dossier introuvable !" && read -p "Entrée..." && return

    # Dossier de destination
    dest="/backups"
    [ ! -d "$dest" ] && mkdir -p "$dest"

    # Nom du fichier avec la date
    nom=$(basename "$source")
    fichier="$dest/${nom}_$(date +%Y%m%d).tgz"

    # Crée le backup
    sudo tar -czf "$fichier" "$source"

    log_ok "Backup fait : $fichier"
    read -p "Appuie sur Entrée..."
}





CPU() {
clear
echo "------ETAT DU CPU------"
  top -bn1 | grep "Cpu(s)" | awk '{print "CPU : " $2 + $4 "%"}'
    echo ""
    read -p "Appuie sur Entrée..."
}



RAM() {
clear
echo "------USAGE DE LA RAM------"
 free -h | grep "Mem" | awk '{print "RAM : " $3 " / " $2 " (" $3*100/$2 "% )"}'
    echo ""
    read -p "Appuie sur Entrée..."
}



SERVICES() {
echo "---------VERIFICATION DU SERVICE----------"
read -p "Quel service veux-tu vérifier ?" service
if [ -z "$service" ]; then
        echo "Erreur : Service inexistant !"
    else
        echo "Etat de '$service' :"
        systemctl status "$service"
    fi

    echo ""
    read -p "Appuie sur Entrée pour revenir..."
}

# === 7. IP & Ports ===
IP_PORT() {
    clear
    echo "------ IP & PORTS ------"
    echo "IP(s) :"
    ip -4 addr show | grep "inet " | awk '{print "  →", $2}'
    echo "Ports ouverts :"
    ss -tulnp | grep LISTEN | awk '{print "  →", $5, $7}'
    read -p "Entrée..."
}



surveillance_web() {
    clear
    LOG_WEB="/var/log/web_changes.log"
    touch "$LOG_WEB"
    echo "Surveillance du répertoire /var/www/html"
    echo "Log → $LOG_WEB"
    echo "Appuyez sur Ctrl+C pour arrêter."

    # Lancer inotifywait en arrière‑plan
    inotifywait -m -e create,modify,delete,move \
        /var/www/html \
        --outfile "$LOG_WEB" \
        --format '%T [%e] %w%f' \
        --timefmt '%Y-%m-%d %H:%M:%S' &
    INOTIFY_PID=$!
}

ssh_connexion()  {
    clear
    echo "====== AJOUTER CLÉ SSH AU SERVEUR ======"

    # Demander les infos
    read -p "Utilisateur sur le serveur ? " user
    read -p "IP ou nom du serveur ? " host
    read -p "Mot de passe SSH (une fois seulement) : " -s password
    echo

    # Chemin de la clé (dans le home de l'utilisateur)
    keyfile="$HOME/.ssh/id_rsa_menu"

    # 1. Générer la clé si elle n'existe pas
    if [ ! -f "$keyfile" ]; then
        echo "Génération de la clé SSH..."
        ssh-keygen -t rsa -b 4096 -f "$keyfile" -N "" -q
        log_ok "Clé générée : $keyfile"
    else
        log_info "Clé existante réutilisée : $keyfile"
    fi
     
    # 2. Envoyer la clé avec ssh-copy-id (via mot de passe)
    echo "Envoi de la clé au serveur $user@$host..."
    sshpass -p "$password" ssh-copy-id -i "$keyfile.pub" "$user@$host" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_ok "Clé ajoutée avec succès sur $user@$host !"
        echo "→ Tu peux maintenant te connecter SANS mot de passe :"
        echo "   ssh -i $keyfile $user@$host"
    else
        log_err "Échec : mot de passe incorrect ou serveur inaccessible"
    fi

echo "Création d'un fichier de configuration avec Alias"
mkdir  -p ~/.ssh
touch ~/.ssh/config
read -p "Quel nom d'Alias veut-tu donner au serveur" alias
cat << EOF >> ~/.ssh/config 
Host $alias
    HostName $host
    User $user
    RemoteCommand ~/Launch.sh; bash -i
    RequestTTY yes
EOF

# Permissions correctes
chmod 600 ~/.ssh/config
    pause
} 



menu() {
    clear
    printf "${GREEN}=== MENU GESTION SERVEUR ===${RESET}\n"
    printf "1)${YELLOW} Usage des disques${RESET}\n"
    printf "2) Usage des répertoires\n"
    printf "3) Backup\n"
    printf "4) CPU\n"
    printf "5) RAM\n"
    printf "6) IP & Ports\n"
    printf "7) Services\n"
    printf "8) Surveillance Web\n"
    printf "9) Accès SSH\n"
    printf "${GREEN}0) Quitter${RESET}\n"
}

main() {
  while true; do
    menu
    read -r -p "Ton choix : " c
    case "${c:-}" in
      1) usage_disque; pause;;
      2) usage_repertoire; pause;;
      3) backup; pause;;
      4) CPU; pause;;
      5) RAM; pause;;
      6) IP_PORT; pause;;
      7) SERVICES; pause;;
      8) surveillance_web; pause;;
      9) ssh_connexion; pause;;  
      *) echo "Choix invalide."; pause;;
      esac
  done
}

# === Exécution directe avec UN SEUL argument (et pause) ===
[ "$#" -eq 1 ] && {
    case "$1" in
        1) usage_disque; pause ;;
        2) usage_repertoire; pause ;;
        3) backup; pause ;;
        4) CPU; pause ;;
        5) RAM; pause ;;
        6) IP_PORT; pause ;;
        7) SERVICES; pause ;;
        8) surveillance_web ;;
        9) ssh_connexion; pause ;;
        *) echo "Choix invalide : $1" >&2; pause ;;
    esac
    exit 0
}

trap 'echo "Erreur ligne $LINENO (code $?)" ; exit 1' ERR
main
