#!/usr/bin/env bash
# install-web.sh - installiert Apache, PHP und Nextcloud (Archiv-Variante).
# Kein Docker, kein Web Installer. Ziel: Installationsassistent unter http://<IP>/
# Wird per Cloud-Init auf dem Web-Server ausgefuehrt (Ubuntu 24.04 LTS).
set -euo pipefail

# shellcheck source=/dev/null
source /etc/nextcloud-project.env

LOG=/var/log/nextcloud-project-web.log
INFO=/root/nextcloud-install-info.txt
exec > >(tee -a "$LOG") 2>&1
export DEBIAN_FRONTEND=noninteractive

say() { echo "$*" | tee /dev/console 2>/dev/null || echo "$*"; }

WEBROOT=/var/www/nextcloud
DATADIR=/var/nextcloud-data
NC_URL="https://download.nextcloud.com/server/releases/latest.tar.bz2"

say "[web] Start $(date -Is)"

apt-get update -y
apt-get install -y apache2 libapache2-mod-php \
  php php-cli php-mysql php-gd php-curl php-mbstring php-intl php-gmp \
  php-bcmath php-xml php-zip php-imagick php-apcu \
  mariadb-client curl bzip2 unzip netcat-openbsd ufw

# --- Nextcloud-Archiv laden und pruefen --------------------------------------
cd /tmp
curl -fsSL -o nextcloud.tar.bz2 "$NC_URL"
curl -fsSL -o nextcloud.tar.bz2.sha256 "${NC_URL}.sha256"
EXPECTED=$(awk '{print $1; exit}' nextcloud.tar.bz2.sha256)
ACTUAL=$(sha256sum nextcloud.tar.bz2 | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then
  say "[web] FEHLER: SHA256 stimmt nicht (erwartet $EXPECTED, erhalten $ACTUAL)"
  exit 1
fi
say "[web] Archiv-Pruefsumme OK"

rm -rf "$WEBROOT"
tar -xjf nextcloud.tar.bz2 -C /var/www
mkdir -p "$DATADIR"
chown -R www-data:www-data "$WEBROOT" "$DATADIR"
chmod 750 "$DATADIR"

# --- PHP ----------------------------------------------------------------------
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
cat > "/etc/php/${PHPV}/apache2/conf.d/99-nextcloud.ini" <<'EOF'
memory_limit = 512M
upload_max_filesize = 512M
post_max_size = 512M
max_execution_time = 360
output_buffering = 0
opcache.enable = 1
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.memory_consumption = 128
opcache.save_comments = 1
opcache.revalidate_freq = 60
apc.enable_cli = 1
EOF

# --- Apache: Nextcloud direkt unter / (nicht unter /nextcloud) ---------------
cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    DocumentRoot ${WEBROOT}

    <Directory ${WEBROOT}/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf || true
a2ensite nextcloud.conf
a2enmod rewrite headers env dir mime setenvif
systemctl enable apache2
systemctl restart apache2

# --- Firewall ----------------------------------------------------------------
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# --- Verbindung zur Datenbank testen (max. 10 Min warten) ---------------------
DB_OK="NEIN"
for i in $(seq 1 60); do
  if mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e 'SELECT 1;' >/dev/null 2>&1; then
    DB_OK="JA"
    break
  fi
  say "[web] Warte auf Datenbank ${DB_HOST} (Versuch ${i}/60) ..."
  sleep 10
done

# --- Webserver testen --------------------------------------------------------
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ || true)
WIZARD_OK="NEIN"
if curl -sL http://localhost/ | grep -qi 'nextcloud'; then WIZARD_OK="JA"; fi

# --- IP-Adresse(n) ermitteln --------------------------------------------------
LOCAL_IP=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
PUBLIC_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]' || true)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="$LOCAL_IP"

# --- Zusammenfassung in Konsole + Datei + MOTD -------------------------------
SUMMARY=$(cat <<EOF
==============================================
 Nextcloud ist bereit - Installationsassistent
==============================================
 URL (oeffentlich) : http://${PUBLIC_IP}/
 Interne IP        : ${LOCAL_IP}
 HTTP-Status       : ${HTTP_CODE}
 Assistent erreichbar: ${WIZARD_OK}
 DB-Verbindung OK  : ${DB_OK}

 Angaben fuer den Assistenten:
  Datenverzeichnis : ${DATADIR}
  Datenbank-Typ    : MySQL/MariaDB
  Datenbank-Benutzer  : ${DB_USER}
  Datenbank-Passwort  : ${DB_PASS}
  Datenbank-Name      : ${DB_NAME}
  Datenbank-Host      : ${DB_HOST}:3306
==============================================
EOF
)

echo "$SUMMARY" > "$INFO"
chmod 600 "$INFO"
echo "$SUMMARY" > /etc/motd
say "$SUMMARY"
say "[web] Fertig $(date -Is)"
