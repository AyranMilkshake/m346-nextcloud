#!/usr/bin/env bash
# render.sh - erzeugt die fertigen Cloud-Init-Dateien (user-data) fuer DB- und Web-Server.
#
# Aufruf:   ./scripts/render.sh <WEB_SUBNETZ_CIDR> <DB_INTERNE_IP>
# Beispiel: ./scripts/render.sh 10.0.1.0/24 10.0.1.10
#
# Ergebnis (Ordner rendered/, steht in .gitignore, enthaelt Passwoerter!):
#   rendered/db.user-data.yaml    -> beim Erstellen des DB-Servers als User-Data einfuegen
#   rendered/web.user-data.yaml   -> beim Erstellen des Web-Servers als User-Data einfuegen
#   rendered/secrets.env          -> generierte Passwoerter
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Aufruf: $0 <WEB_SUBNETZ_CIDR> <DB_INTERNE_IP>" >&2
  echo "Beispiel: $0 10.0.1.0/24 10.0.1.10" >&2
  exit 1
fi

WEB_CIDR="$1"
DB_HOST="$2"

# Eingaben pruefen und CIDR in MariaDB-Schreibweise (10.0.1.0/255.255.255.0) umwandeln
WEB_HOST_MASK=$(python3 -I - "$WEB_CIDR" "$DB_HOST" <<'PY'
import ipaddress, sys
net = ipaddress.ip_network(sys.argv[1], strict=False)
ipaddress.ip_address(sys.argv[2])
print(net.with_netmask)
PY
)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DIR/../rendered"
mkdir -p "$OUT"

genpw() { openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c 24; }

DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASS="$(genpw)"
DB_ROOT_PASS="$(genpw)"

ENV_CONTENT="DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_ROOT_PASS=${DB_ROOT_PASS}
DB_HOST=${DB_HOST}
WEB_CIDR=${WEB_CIDR}
WEB_HOST_MASK=${WEB_HOST_MASK}"

indent() { sed 's/^/      /'; }

build() {
  local role="$1" script="$2" out="$3"
  {
    echo "#cloud-config"
    echo "# Automatisch erzeugt von render.sh - enthaelt Passwoerter, NICHT einchecken!"
    echo "hostname: nextcloud-${role}"
    echo "write_files:"
    echo "  - path: /etc/nextcloud-project.env"
    echo "    permissions: '0600'"
    echo "    content: |"
    echo "$ENV_CONTENT" | indent
    echo "  - path: /usr/local/sbin/install-${role}.sh"
    echo "    permissions: '0755'"
    echo "    content: |"
    indent < "$script"
    echo "runcmd:"
    echo "  - [ bash, /usr/local/sbin/install-${role}.sh ]"
  } > "$out"
}

build db  "$DIR/install-db.sh"  "$OUT/db.user-data.yaml"
build web "$DIR/install-web.sh" "$OUT/web.user-data.yaml"

cat > "$OUT/secrets.env" <<EOF
${ENV_CONTENT}
EOF
chmod 600 "$OUT"/*

echo "Fertig. Dateien in: $OUT"
echo "  1) DB-Server  mit rendered/db.user-data.yaml starten (interne IP ${DB_HOST})"
echo "  2) Web-Server mit rendered/web.user-data.yaml starten"
echo "  3) Konsole/Log des Web-Servers zeigt die URL und die DB-Angaben"
