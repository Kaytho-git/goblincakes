#!/bin/sh
# Ianseo's own Apache settings (/ianseo → /opt/ianseo and its PHP values) come with the zip,
# as in Ianseo's install guide: Install/apache-ianseo.conf → conf enabled.
if [ -f /opt/ianseo/Install/apache-ianseo.conf ]; then
    cp /opt/ianseo/Install/apache-ianseo.conf /etc/apache2/conf-enabled/apache-ianseo.conf
else
    printf 'Alias /ianseo /opt/ianseo\n<Directory /opt/ianseo>\n    Options FollowSymLinks\n    AllowOverride All\n    Require all granted\n</Directory>\n' \
        > /etc/apache2/conf-enabled/apache-ianseo.conf
fi
exec apache2-foreground
