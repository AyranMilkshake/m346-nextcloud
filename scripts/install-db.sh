#!/usr/bin/env bash
# install-db.sh - installiert und konfiguriert den MariaDB-Server fuer Nextcloud.
# Wird per Cloud-Init auf dem DB-Server ausgefuehrt (Ubuntu 24.04 LTS).
# Konfiguration kommt aus /etc/nextcloud-project.env (von render.sh erzeugt).
set -euo pipefail

# shellcheck source=/dev/null
source /etc/nextcloud-project.env

LOG=/var/log/nextcloud-project-db.log
exec > >(tee -a "$LOG") 2>&1
export DEBIAN_FRONTEND=noninteractive

say() { echo "$*" | tee /dev/console 2>/dev/null || echo "$*"; }

say "[db] Start $(date -Is)"

apt-get update -y
apt-get install -y mariadb-server ufw

# Interne IP dieses Servers (Interface, ueber das der Default-Route laeuft)
PRIV_IP=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
say "[db] Interne IP: ${PRIV_IP}"

# MariaDB nur auf der internen IP lauschen lassen (+ Nextcloud-Empfehlungen)
cat > /etc/mysql/mariadb.conf.d/99-nextcloud.cnf <<EOF
[mysqld]
bind-address = ${PRIV_IP}
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
transaction_isolation = READ-COMMITTED
binlog_format = ROW
skip-name-resolve
EOF

systemctl enable mariadb
systemctl restart mariadb

# Datenbank + User (nur aus dem Web-Subnetz erreichbar) + Root-Passwort
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'${WEB_HOST_MASK}' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'${WEB_HOST_MASK}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${WEB_HOST_MASK}';
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('${DB_ROOT_PASS}');
DELETE FROM mysql.global_priv WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

# Firewall: SSH + MariaDB nur vom Web-Subnetz
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from "${WEB_CIDR}" to any port 3306 proto tcp
ufw --force enable

# Selbsttest
mariadb -e "SELECT VERSION() AS version;" | tee -a "$LOG"
ss -ltn | grep ':3306' | tee -a "$LOG"

say "=============================================="
say " DB-Server fertig"
say "  Lauscht auf : ${PRIV_IP}:3306 (nur intern)"
say "  Erlaubt von : ${WEB_CIDR}"
say "  Datenbank   : ${DB_NAME}"
say "  Benutzer    : ${DB_USER}"
say "=============================================="
