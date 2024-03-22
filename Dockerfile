FROM ubuntu:latest



# Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
apt-get -y install ca-certificates apt-transport-https software-properties-common curl wget gnupg2 lsb-release apt-transport-https && \
add-apt-repository ppa:ondrej/php -y
RUN apt-get update && \
apt-get -y install libaio1 libaio-dev supervisor git apache2 curl mysql-server php libapache2-mod-php8.3 php8.3-mysql php8.3-imap php8.3-ldap php8.3-xml php8.3-curl php8.3-mbstring php8.3-zip && \
echo "ServerName localhost" >> /etc/apache2/apache2.conf


# Start Apache script
RUN echo '#!/bin/bash\n\
source /etc/apache2/envvars\n\
service apache2 start\n\
' > /start-apache2.sh
RUN chmod +x /start-apache2.sh

RUN echo '#!/bin/bash\n\
service mysql start\n\
' > /start-mysqld.sh
RUN chmod +x  /start-mysqld.sh

# Configuration for MySQL
RUN echo "[mysqld]\n\
bind-address=0.0.0.0\n\
" > /etc/mysql/conf.d/my.cnf

# Configuration for Supervisor - Apache
RUN echo "[program:apache2]\n\
command=/start-apache2.sh\n\
numprocs=1\n\
autostart=true\n\
autorestart=true\n\
" > /etc/supervisor/conf.d/supervisord-apache2.conf

RUN echo "[program:mysqld]\n\
command=/start-mysqld.sh\n\
numprocs=1\n\
autostart=true\n\
autorestart=true\n\
" >  /etc/supervisor/conf.d/supervisord-mysqld.conf



# Add MySQL utils
RUN usermod -d /var/lib/mysql/ mysql


# Configuration for Apache
RUN echo '<VirtualHost *:80>\n\
ServerName localhost\n\
ServerAdmin webmaster@localhost\n\
\n\
DocumentRoot /var/www/html\n\
\n\
<Directory />\n\
Options FollowSymLinks\n\
AllowOverride None\n\
</Directory>\n\
\n\
<Directory /var/www/html>\n\
# Options Indexes FollowSymLinks MultiViews\n\
# To make wordpress .htaccess work\n\
AllowOverride all\n\
Order allow,deny\n\
allow from all\n\
</Directory>\n\
\n\
ErrorLog ${APACHE_LOG_DIR}/error.log\n\
\n\
# Possible values include: debug, info, notice, warn, error, crit,\n\
# alert, emerg.\n\
LogLevel warn\n\
\n\
CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
\n\
#\n\
# Set HTTPS environment variable if we came in over secure\n\
# channel.\n\
SetEnvIf x-forwarded-proto https HTTPS=on\n\
\n\
</VirtualHost>\n\
' > /etc/apache2/sites-available/000-default.conf


RUN a2enmod rewrite


# Configure /app folder with sample app

RUN mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html



#Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 128M
ENV PHP_POST_MAX_SIZE 128M


# Start MySQL service and setup
RUN echo '#!/bin/bash\n\
service mysql start\n\
mysql -uroot <<MYSQL_SCRIPT\n\
CREATE DATABASE IF NOT EXISTS wordpress;\n\
CREATE USER IF NOT EXISTS "wordpressuser"@"localhost" IDENTIFIED BY "password";\n\
GRANT ALL PRIVILEGES ON wordpress.* TO "wordpressuser"@"localhost";\n\
FLUSH PRIVILEGES;\n\
MYSQL_SCRIPT\n\
service mysql stop\n\
exec supervisord -n\n\
' > /run.sh
RUN chmod +x /run.sh

# Add volumes for MySQL
VOLUME ["/etc/mysql", "/var/lib/mysql", "/app" ]



EXPOSE 80 3306
CMD ["/run.sh"]
