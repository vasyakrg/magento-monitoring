#!/bin/bash

[[ ! -f .env ]] && {
    cp .env.example .env
    echo "Please put data in .env file and rerun its script"
    exit 1
}

source .env

[[ -z $SITE ]] || [[ -z $ROOT_MYSQL_PASSWORD ]] || [[ -z $MAGENTO_MYSQL_PASSWORD ]]&& {
    echo "ENVS: SITE, ROOT_MYSQL_PASSWORD ans MAGENTO_MYSQL_PASSWORD must be not null"
    exit 1
}

echo "<<< start >>>"

apt update
apt-get -y install curl nano git software-properties-common sudo git
apt-get -y install mariadb-server


mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD("$ROOT_MYSQL_PASSWORD") WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE DATABASE magento;
CREATE USER 'magento'@'localhost' IDENTIFIED BY "$MAGENTO_MYSQL_PASSWORD";
GRANT ALL PRIVILEGES ON magento.* TO 'magento'@'localhost';
FLUSH PRIVILEGES;
EOF

add-apt-repository ppa:ondrej/php -y
apt-get -y install php7.3-fpm php7.3-common php7.3-mysql php7.3-xml php7.3-xmlrpc php7.3-curl \
    php7.3-gd php7.3-imagick php7.3-cli php7.3-dev php7.3-imap php7.3-mbstring php7.3-opcache \
    php7.3-soap php7.3-zip php7.3-intl php7.3-bcmath php-amqplib

sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.3/fpm/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 128M/" /etc/php/7.3/fpm/php.ini
sudo sed -i "s/zlib.output_compression = .*/zlib.output_compression = on/" /etc/php/7.3/fpm/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 18000/" /etc/php/7.3/fpm/php.ini

curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

git clone https://github.com/magento/magento2.git /var/www/${SITE}
cd /var/www/${SITE}
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))

composer install

bin/magento setup:install \
--base-url=http://${SITE}/ \
--db-host=localhost \
--db-name=magento \
--db-user=magento \
--db-password=${MAGENTO_MYSQL_PASSWORD} \
--admin-firstname=First  \
--admin-lastname=Last \
--admin-email=user@${SITE} \
--admin-user=admin \
--admin-password=${MAGENTO_MYSQL_PASSWORD} \
--language=ru_RU \
--currency=${CURRENCY} \
--timezone=Europe/Moscow \
--use-rewrites=1


echo "* * * * * /usr/bin/php /var/www/${SITE}/bin/magento cron:run | grep -v 'Run tasks from scheduler' >> /var/www/${SITE}/var/log/magento.cron.log" | crontab -u www-data -

chown -R www-data: /var/www/${SITE}

apt-get -y install nginx

tee /etc/nginx/sites-available/${SITE}-443.conf <<EOF
server {

    listen 443 ssl http2;

    server_name ${SITE} www.${SITE};


    index index.php index.html;

    access_log /var/log/nginx/${SITE}-443-access.log;
    error_log /var/log/nginx/${SITE}-443-error.log error;



    ssl                       on;
    add_header                Strict-Transport-Security "max-age=31536000" always;
    ssl_session_cache         shared:SSL:20m;
    ssl_session_timeout       10m;
    ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers               "ECDH+AESGCM:ECDH+AES256:ECDH+AES128:!ADH:!AECDH:!MD5;";
    ssl_stapling              on;
    ssl_stapling_verify       on;
    resolver                  8.8.8.8 8.8.4.4;
    ssl_certificate           /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key       /etc/ssl/private/ssl-cert-snakeoil.key;
    # ssl_trusted_certificate   /etc/dehydrated/certs/${SITE}/chain.pem;

    autoindex off;
    charset UTF-8;

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Ssl-Offloaded "1";
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_redirect  http://${SITE}:8080/  /;
        proxy_buffer_size          128k;
        proxy_buffers              1024 256k;
        proxy_busy_buffers_size    256k;
        proxy_http_version 1.1;
        proxy_read_timeout 600s;
        proxy_connect_timeout 600s;
    }

}
EOF

tee /etc/nginx/sites-available/${SITE}-80.conf <<EOF
server {

    listen 80;

    server_name ${SITE} www.${SITE};

    index index.html index.htm;
    return 301 https://${SITE}\$request_uri;
}
EOF

tee /etc/nginx/sites-available/${SITE}-8080.conf <<EOF
upstream fastcgi_backend {
    server unix:/var/run/php/php7.3-fpm.sock;
}

server {

    listen 127.0.0.1:8080;

    server_name ${SITE};

    set $MAGE_ROOT /var/www/${SITE};

    root $MAGE_ROOT/pub;

    index index.php index.html;

    error_page 404 403 = /errors/404.php;
    access_log /var/log/nginx/${SITE}-8080-access.log;
    error_log /var/log/nginx/${SITE}-8080-error.log error;

    include /etc/nginx/nginx.magento.conf;
}
EOF

cat nginx.conf > /etc/nginx/nginx.magento.conf
cat maintenance.html > /etc/varnish/maintenance.html
cat 503.phtml > /var/www/${SITE}/pub/errors/default/503.phtml

ln -s /etc/nginx/sites-available/${SITE}-443.conf /etc/nginx/sites-enabled/${SITE}-443.conf
ln -s /etc/nginx/sites-available/${SITE}-80.conf /etc/nginx/sites-enabled/${SITE}-80.conf

rm -f /etc/nginx/sites-enabled/default

service nginx restart

apt-get install -y varnish
php bin/magento cache:flush

rm -f /etc/varnish/default.vcl

sudo -u www-data /var/www/${SITE}/bin/magento varnish:vcl:generate > /var/www/${SITE}/var/varnish.vcl --export-version=5
ln -sf /var/www/${SITE}/var/varnish.vcl /etc/varnish/default.vcl

cat backend_error.file >> /etc/varnish/default.vcl

mkdir -p /etc/systemd/system/varnish.service.d

tee /etc/systemd/system/varnish.service.d/customexec.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd -j unix,user=vcache -F -a 127.0.0.1:6081 -T localhost:6082 -f /etc/varnish/default.vcl -S /etc/varnish/secret -s malloc,256m
EOF

systemctl daemon-reload

chown -R www-data:www-data /var/www/${SITE}

systemctl restart nginx && systemctl restart varnish

bin/magento setup:store-config:set --base-url="https://${SITE}"
php bin/magento cache:flush

echo "<<< end >>>"
