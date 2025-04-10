#!/bin/bash

echo "🧨 Lancement de la désinstallation complète de GLPI et de sa stack..."

# Stop services
echo "⛔ Arrêt des services Apache et MariaDB..."
sudo systemctl stop apache2
sudo systemctl stop mariadb

# Supprimer les paquets
echo "📦 Suppression des paquets Apache, PHP et MariaDB..."
sudo apt purge -y apache2* php* mariadb-* mysql-* libapache2-mod-php* 
sudo apt autoremove -y
sudo apt autoclean

# Supprimer les répertoires de GLPI
echo "🗑️ Suppression des dossiers GLPI..."
sudo rm -rf /var/www/glpi
sudo rm -rf /etc/glpi
sudo rm -rf /var/lib/glpi
sudo rm -rf /var/log/glpi
sudo rm -f /tmp/glpi.tgz

# Supprimer les virtual hosts Apache
echo "🧹 Nettoyage des virtual hosts Apache..."
sudo rm -f /etc/apache2/sites-available/*.conf
sudo rm -f /etc/apache2/sites-enabled/*.conf

# Supprimer la base de données GLPI
echo "🗃️ Suppression de la base de données et de l'utilisateur MySQL..."
read -sp "Mot de passe root MariaDB pour supprimer la base : " MYSQL_PASS
echo
mysql -u root -p$MYSQL_PASS -e "DROP DATABASE IF EXISTS glpi_db; DROP USER IF EXISTS 'glpi_user'@'localhost'; FLUSH PRIVILEGES;"

echo "✅ Désinstallation terminée. Tu peux relancer ton script sur une base propre !"
