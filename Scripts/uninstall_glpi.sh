#!/bin/bash

# Script de désinstallation de GLPI
# Auteur : Garance Defrel 
# Date : 10/04/2025
# Version : 1.0

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo ou en tant que root."
    exit 1
fi

echo "Lancement de la désinstallation complète de GLPI et de sa stack..."

function stop_service(){
    echo "Arrêt des services Apache et MariaDB"
    systemctl stop apache2
    systemctl stop mariadb
}

function erase_pkg(){
    echo "Suppression des paquets Apache, PHP et MariaDB"
    apt purge -y apache2* php* mariadb-* mysql-* libapache2-mod-php*
    apt autoremove - y
    apt autoclean
}

function erase_folders_glpi(){
    echo "Suppression des dossiers GLPI"
    rm -rf /var/www/glpi
    rm -rf /etc/glpi
    rm -rf /var/lib/glpi
    rm -rf /var/log/glpi
    rm -rf /tmp/glpi.tgz
}

function erase_vhost(){
    echo "Nettoyage des virtuals hosts Apache"
    rm -f /etc/apache2/sites-available/*.conf
    rm -f /etc/apache2/sites-enable/*.conf
}

function erase_bddmaria(){
    echo "Suppression de la base de données et de l'utilisateur MYSQL"
    read -sp "Mot de passe root MariaDB pour supprimer la base de données : " MYSQL_PASS
    echo 
    mysql -u root -p$MYSQL_PASS -e "DROP DATABASE IF EXISTS glpi_db; DROP USER IF EXISTS 'glpi_user'@'localhost'; FLUSH PRIVILEGES;"
}

# Installation complète
function full_uninstall(){
    stop_service
    erase_pkg
    erase_folders_glpi
    erase_vhost
    erase_bddmaria
}

# Menu interactif
function interactive_menu() {
    while true; do
        echo
        read -n1 -p "Menu : [1] STOP SERVICE, [2] PACKAGES, [3] FOLDERS, [4] VHOST, [5] MARIADB, [6] DESINSTALLATION COMPLETE, [q] Quitter : " choice
        echo
        case $choice in
            1) stop_service ;;
            2) erase_pkg ;;
            3) erase_folders_glpi ;;
            4) erase_vhost ;;
            5) erase_bddmaria ;;
            6) full_uninstall ;;
            [qQ]) echo "Fin du script." ; break ;;
            *) echo "[ERREUR] Option invalide." ;;
        esac
    done
}

# Lancement
if [[ "$1" == "--auto" ]]; then
    full_uninstall_glpi
else
    interactive_menu
fi

echo "Désinstallation terminée"