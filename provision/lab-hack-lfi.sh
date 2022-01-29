#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo '[START] Provisioning script'
echo -e '\n[INFO] Upgrading system software\n'
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

echo -e '\n[INFO] Installing packages\n'
apt-get -yq install \
    php \
    apache2 \
    libapache2-mod-php \
    ca-certificates \
    curl \
    php-curl \
    php-json \
    php-mysql \
    php-odbc \
    php-sqlite3
apt-get autoremove
apt-get clean
rm -rf /tmp/* /var/cache/apt/archive/*.deb /var/lib/apt/lists/* /var/tmp/* 

echo -e '\n[INFO] Configuring the HTTP server\n'
a2enmod rewrite
systemctl restart apache2
systemctl enable apache2

echo -e '\n[INFO] Allowing www-data to write in DocumentRoot\n'
chown root.www-data /var/www/html/
chmod g+w /var/www/html/

echo -e '[INFO] Allowing www-data to access httpd logs\n'
chmod o+rx /var/log/apache2/
chmod o+r /var/log/apache2/*.log

echo -e '[INFO] Allowing www-data to access auth log\n'
touch /var/log/auth.log 
chown root.adm /var/log/auth.log
chmod 644 /var/log/auth.log 


echo -e '[INFO] Deploying vulnerable site\n'
chown -R www-data.www-data /home/vagrant/site/
cp /home/vagrant/site/*.php /var/www/html/
rm -f /var/www/html/index.html
rm -rf /home/vagrant/site/

echo '[END] Provisioning script'
