#!/bin/bash
# ================================================
# SCRIPT SIMPLE + CORRIGÉ : WordPress + Sécurité
# ================================================
 
echo "Mise à jour du système..."
sudo apt update
sudo apt upgrade -y
 
echo "Installation d'Apache, MariaDB et PHP..."
sudo apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql wget unzip
 
echo "Démarrage des services..."
sudo systemctl start apache2
sudo systemctl start mariadb
 
echo "Téléchargement de WordPress..."
cd /tmp
wget https://wordpress.org/latest.zip
unzip latest.zip
 
echo "Copie des fichiers WordPress..."
sudo rm -rf /var/www/html/*
sudo mv wordpress/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html
 
echo "Création de la base de données..."
sudo mysql <<EOF
CREATE DATABASE wordpress;
CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'monmotdepasse123';
GRANT ALL ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EOF
 
echo "Configuration de WordPress..."
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/monmotdepasse123/" /var/www/html/wp-config.php
 
echo "Redémarrage du serveur web..."
sudo systemctl restart apache2
 
# === FAIL2BAN AVEC LA BONNE RÈGLE ===
echo "Installation de Fail2Ban..."
sudo apt install -y fail2ban
 
# Règle principale
sudo bash -c 'cat > /etc/fail2ban/jail.local' <<EOF
[wp-login]
enabled = true
port = http,https
filter = wp-login
logpath = /var/log/apache2/access.log
maxretry = 5
findtime = 600
bantime = 3600
EOF
 

sudo bash -c 'cat > /etc/fail2ban/filter.d/wp-login.conf' <<EOF
[Definition]
failregex = ^<HOST> -.*POST /wp-login\.php HTTP.*
ignoreregex =
EOF
 
sudo systemctl restart fail2ban
 

echo ""
echo "WORDPRESS EST PRÊT !"
echo "Va sur : http://localhost"
echo "Admin : http://localhost/wp-admin"
echo ""
echo "Fail2Ban est actif et protège wp-login.php"
echo "Règle : 5 erreurs en 10 min → bloqué 1 heure"
echo ""
