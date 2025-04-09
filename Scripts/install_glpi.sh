#!/bin/bash

#=============================================
# Script d'installation de GLPI
# Auteur : Garance Defrel
# Version : 2.0
# Date : 09/04/2025
#============================================

LOG_FILE="/var/log/glpi-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo ou en tant que root."
    exit 1
fi

#Variables
DB_NAME=glpi_db
DB_USER=glpi_user
TMP_DIR="/tmp"

# Demande des informations utilisateur
read -sp "Entrez le mot de passe MySQL pour l'utilisateur GLPI : " MYSQL_PASS
echo
read -p "Entrez le nom de domaine ou l'IP du serveur (ex: glpi.exemple.com ou 192.168.10.15) : " SERVER_NAME

# Fonction : Mise à jour du système et installation des dépendances
function update_system(){
    echo "[INFO] Mise à jour du système..."
    if apt update && apt upgrade -y; then
        echo "[OK] Système à jour"
    else
        echo "[ERREUR] Echec de la mise à jour."
        exit 1
    fi
    echo "[INFO] Installation des dépendances..."
    if apt-get install -y apache2 libapache2-mod-php mariadb-server php php-{curl,gd,imagick,intl,apcu,memcache,imap,mysql,cas,ldap,tidy,pear,xmlrpc,pspell,mbstring,json,iconv,xml,xsl,zip,bz2}; then
        echo "[OK] Dépendances installées."
    else
        echo "[ERREUR] Echec de l'installation des paquets."
        exit 1
    fi
}

# Fonction : Sécurisation de MariaDB
function secure_mariaDB(){
    echo "[INFO] Sécurisation de MariaDB..."
    if mysql_secure_installation <<EOF
Y
Y
$MYSQL_PASS
$MYSQL_PASS
Y
Y
Y
Y
EOF
    then
        echo "[OK] MariaDB sécurisée."
    else
        echo "[ERREUR] La sécurisation de MariaDB a échoué."
        exit 1
    fi
}

# Fonction : Configuratoin de la base de données
function config_database(){
    echo "[INFO] Création et configuratoin de la base de données..."
    if mysql -u root -p$MYSQL_PASS -e "
        CREATE DATABASE IF NOT EXISTS $DB_NAME;
        CREATE USER IF NOT EXISTS $DB_USER@localhost IDENTIFIED BY '$MYSQL_PASS';
        GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
        FLUSH PRIVILEGES;"; then
        echo "[OK] Base de données configurée"
    else
        echo "[ERREUR] Erreur lors de la configuration de la base de données."
        exit 1
    fi
}

# Fonction : Installation de GLPI

function install_glpi(){
    echo "[INFO] Téléchargement de GLPI..."
    GLPI_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)
    GLPI_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"

    cd $TMP_DIR || exit 1

    if wget -q $GLPI_URL -O glpi.tgz && tar -xzf glpi.tgz; then
        echo "[OK] Téléchargement et extraction réussis."
    else
        echo "[ERREUR] Échec lors du téléchargement ou de l'extraction."
        exit 1
    fi

    GLPI_DIR=$(tar -tzf glpi.tgz | head -1 | cut -d"/" -f1)
    mv "$GLPI_DIR" /var/www/glpi

    mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
    cp -r /var/www/glpi/config /etc/glpi
    cp -r /var/www/glpi/files/* /var/lib/glpi/

    chown -R www-data:www-data /var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi
    chmod -R 750 /etc/glpi /var/lib/glpi /var/log/glpi

    echo "[OK] GLPI installé dans /var/www/glpi."
}

#Fonction : Configuration de GLPI
function config_files(){
    # Création et configuration du fichier apache2
    echo "[INFO] Configuration d'Apache..."
    VHOST="/etc/apache2/sites-available/$SERVER_NAME.conf"

    cat << EOF > $VHOST
    <VirtualHost *:80>
    ServerName $SERVER_NAME
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

    if a2enmod rewrite && a2ensite $SERVER_NAME && a2dissite 000-default.conf && systemctl reload apache2; then
        echo "[OK] VirtualHost Apache configuré."
    else
        echo "[ERREUR] Erreur lors de la configuration d'apache."
        exit 1
    fi

    echo "<?php define('GLPI_CONFIG_DIR', '/etc/glpi/'); if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) require_once GLPI_CONFIG_DIR . '/local_define.php'; ?>" > /var/www/glpi/inc/downstream.php
    echo "<?php define('GLPI_VAR_DIR', '/var/lib/glpi'); define('GLPI_LOG_DIR', '/var/log/glpi'); ?>" > /etc/glpi/local_define.php
}

# Sécurisation PHP

function secure_php(){
    echo "[INFO] Sécurisation PHP..."
    PHP_INI="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"
    if [ -f "$PHP_INI" ]; then
        sed -i 's/^;*session.cookie_httponly.*/session.cookie_httponly = On/' "$PHP_INI"
        systemctl reload apache2
        echo "[OK] session.cookie_httponly activé."
    else
        echo "[ERREUR] Fichier php.ini introuvable."
        exit 1
    fi
}

# Installation complète
function full_install(){
    update_system
    secure_mariaDB
    config_database
    install_glpi
    config_files
    secure_php
}

# Menu interactif
function interactive_menu() {
    while true; do
        echo
        read -n1 -p "Menu : [1] MAJ, [2] MariaDB, [3] DB, [4] GLPI, [5] Apache, [6] PHP, [7] INSTALLATION COMPLETE, [q] Quitter : " choice
        echo
        case $choice in
            1) update_system ;;
            2) secure_mariaDB ;;
            3) config_database ;;
            4) install_glpi ;;
            5) config_files ;;
            6) secure_php ;;
            7) full_install ;;
            [qQ]) echo "Fin du script." ; break ;;
            *) echo "[ERREUR] Option invalide." ;;
        esac
    done
}

# Lancement
if [[ "$1" == "--auto" ]]; then
    full_install_glpi
else
    interactive_menu
fi