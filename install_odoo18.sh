#!/bin/bash
################################################################################
# Script d'installation Odoo 18 pour Ubuntu 24.04
################################################################################

# Variables de configuration
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_PORT="8069"
OE_VERSION="18.0"
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"
INSTALL_WKHTMLTOPDF="True"
INSTALL_NGINX="True"
ENABLE_SSL="True"
WEBSITE_NAME="odoo.example.com"  # Changez ceci avec votre nom de domaine
ADMIN_EMAIL="admin@example.com"  # Changez ceci avec votre email
INSTALL_POSTGRESQL="True"
GENERATE_RANDOM_PASSWORD="True"
LONGPOLLING_PORT="8072"
VENV_PATH="$OE_HOME/venv"  # Chemin de l'environnement virtuel

#--------------------------------------------------
# Mise à jour du serveur
#--------------------------------------------------
echo -e "\n==== Mise à jour du serveur ===="
sudo apt update
sudo apt upgrade -y

#--------------------------------------------------
# Installation des dépendances système
#--------------------------------------------------
echo -e "\n==== Installation des dépendances système ===="
sudo apt install -y \
    git \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-wheel \
    python3-full \
    libxml2-dev \
    libxslt1-dev \
    libevent-dev \
    libsasl2-dev \
    libldap2-dev \
    libpq-dev \
    libpng-dev \
    libjpeg-dev \
    xfonts-75dpi \
    xfonts-base \
    libssl-dev \
    node-less \
    npm \
    python3-setuptools \
    python3-tk \
    libxrender1 \
    libfontconfig1 \
    libx11-dev \
    libjpeg-dev \
    node-clean-css \
    node-less \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-vobject \
    python3-watchdog \
    python3-xlwt \
    xfonts-75dpi \
    xfonts-base

#--------------------------------------------------
# Installation de PostgreSQL
#--------------------------------------------------
if [ $INSTALL_POSTGRESQL = "True" ]; then
    echo -e "\n==== Installation de PostgreSQL ===="
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt update
    sudo apt install -y postgresql-16
    
    echo -e "\n==== Création de l'utilisateur PostgreSQL ===="
    sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
fi

#--------------------------------------------------
# Installation de wkhtmltopdf
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\n==== Installation de wkhtmltopdf ===="
    sudo apt install -y wkhtmltopdf
fi

#--------------------------------------------------
# Création de l'utilisateur système Odoo
#--------------------------------------------------
echo -e "\n==== Création de l'utilisateur système Odoo ===="
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

#--------------------------------------------------
# Installation d'Odoo
#--------------------------------------------------
echo -e "\n==== Installation d'Odoo ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

#--------------------------------------------------
# Création et configuration de l'environnement virtuel
#--------------------------------------------------
echo -e "\n==== Création de l'environnement virtuel Python ===="
sudo python3 -m venv $VENV_PATH
sudo chown -R $OE_USER:$OE_USER $VENV_PATH

# Activation de l'environnement virtuel et installation des dépendances
echo -e "\n==== Installation des dépendances Python dans l'environnement virtuel ===="
sudo -H -u $OE_USER bash -c "$VENV_PATH/bin/pip install wheel"
sudo -H -u $OE_USER bash -c "$VENV_PATH/bin/pip install -r $OE_HOME_EXT/requirements.txt"

# Création des répertoires pour les modules personnalisés
sudo -H -u $OE_USER bash -c "mkdir -p $OE_HOME/custom/addons"

# Configuration des permissions
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

#--------------------------------------------------
# Configuration d'Odoo
#--------------------------------------------------
echo -e "\n==== Configuration d'Odoo ===="
sudo touch /etc/${OE_CONFIG}.conf

# Génération du mot de passe admin si nécessaire
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    OE_SUPERADMIN=$(openssl rand -base64 12)
fi

# Configuration du fichier de configuration
sudo tee /etc/${OE_CONFIG}.conf > /dev/null <<EOF
[options]
admin_passwd = ${OE_SUPERADMIN}
db_host = False
db_port = False
db_user = ${OE_USER}
db_password = False
addons_path = ${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons
http_port = ${OE_PORT}
logfile = /var/log/${OE_USER}/${OE_CONFIG}.log
proxy_mode = True
longpolling_port = ${LONGPOLLING_PORT}
EOF

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

# Création du répertoire de logs
sudo mkdir -p /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Configuration du service systemd
#--------------------------------------------------
echo -e "\n==== Configuration du service systemd ===="
sudo tee /etc/systemd/system/$OE_CONFIG.service > /dev/null <<EOF
[Unit]
Description=Odoo
After=network.target postgresql.service

[Service]
Type=simple
User=$OE_USER
Group=$OE_USER
ExecStart=$VENV_PATH/bin/python $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf
StandardOutput=journal+console
Environment=PATH=$VENV_PATH/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $OE_CONFIG
sudo systemctl start $OE_CONFIG

#--------------------------------------------------
# Installation et configuration de Nginx
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
    echo -e "\n==== Installation et configuration de Nginx ===="
    sudo apt install -y nginx

    sudo tee /etc/nginx/sites-available/$WEBSITE_NAME > /dev/null <<EOF
upstream odoo {
    server 127.0.0.1:${OE_PORT};
}

upstream odoochat {
    server 127.0.0.1:${LONGPOLLING_PORT};
}

server {
    listen 80;
    server_name $WEBSITE_NAME;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    client_max_body_size 100m;
    
    location / {
        proxy_pass http://odoo;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forward-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://odoochat;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forward-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

    gzip on;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
    gzip_proxied any;
}
EOF

    sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
fi

#--------------------------------------------------
# Configuration SSL avec Certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ]; then
    echo -e "\n==== Configuration SSL avec Certbot ===="
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
    sudo systemctl restart nginx
fi

#--------------------------------------------------
# Fin de l'installation
#--------------------------------------------------
echo -e "\n==== Installation terminée ===="
echo "-----------------------------------------------------------"
echo "Installation d'Odoo terminée. Détails de l'installation :"
echo "Version Odoo : $OE_VERSION"
echo "Port : $OE_PORT"
echo "Utilisateur : $OE_USER"
echo "Environnement virtuel : $VENV_PATH"
echo "Fichier de configuration : /etc/${OE_CONFIG}.conf"
echo "Logs : /var/log/$OE_USER"
echo "Mot de passe admin : $OE_SUPERADMIN"
echo ""
echo "Pour gérer le service Odoo :"
echo "Démarrer : sudo systemctl start $OE_CONFIG"
echo "Arrêter : sudo systemctl stop $OE_CONFIG"
echo "Redémarrer : sudo systemctl restart $OE_CONFIG"
echo "Statut : sudo systemctl status $OE_CONFIG"
echo "Logs : sudo journalctl -u $OE_CONFIG"
if [ $INSTALL_NGINX = "True" ]; then
    echo ""
    echo "Configuration Nginx : /etc/nginx/sites-available/$WEBSITE_NAME"
    echo "Site web accessible sur : https://$WEBSITE_NAME"
fi
echo "-----------------------------------------------------------"
