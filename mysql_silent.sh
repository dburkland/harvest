#!/bin/bash
# Filename:             mysql_silent.sh
# By:                   Dan Burkland
# Date:                 2015-12-23
# Purpose:              The purpose of this script is to silently configure MySQL which is a component
#                       of the "dburkland/harvest" Docker container. 

### Setup MySQL ###
echo "Setting up MySQL..."

# Not required in actual script
MYSQL_ROOT_PASSWORD=abcd1234

SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"

mysql -e "CREATE USER 'graphite'@'localhost' IDENTIFIED BY 'netapp123';" -u root
mysql -e "GRANT ALL PRIVILEGES ON graphite.* TO 'graphite'@'localhost';" -u root
mysql -e "CREATE DATABASE graphite;" -u root
mysql -e 'FLUSH PRIVILEGES;' -u root

echo "Setup of MySQL is complete."

###
