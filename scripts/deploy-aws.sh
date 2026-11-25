#!/usr/bin/env bash
# deploy-aws.sh - stellt Web- und DB-Server vollautomatisch in AWS bereit.
#
# Voraussetzung: AWS CLI v2 ist konfiguriert (z. B. AWS Academy Learner Lab:
#                Credentials aus "AWS Details" nach ~/.aws/credentials kopieren).
# Aufruf:        ./scripts/deploy-aws.sh
# Optional:      KEY_NAME=vockey REGION=us-east-1 ./scripts/deploy-aws.sh
#
# Ablauf: Default-VPC/Subnetz ermitteln -> Security Groups anlegen ->
#         Cloud-Init-Dateien rendern (render.sh) -> DB- und Web-Server starten ->
#         warten bis der Installationsassistent erreichbar ist -> URL + DB-Angaben ausgeben.
set -euo pipefail

REGION="${REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
WEB_TYPE="${WEB_TYPE:-t3.small}"
DB_TYPE="${DB_TYPE:-t3.small}"
KEY_NAME="${KEY_NAME:-}"
TAG="m346-nextcloud"

export AWS_DEFAULT_REGION="$REGION"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DIR/../rendered"

log() { echo "[deploy] $*"; }

command -v aws >/dev/null || { echo "AWS CLI nicht gefunden." >&2; exit 1; }
aws sts get-caller-identity >/dev/null || { echo "AWS-Credentials fehlen/abgelaufen." >&2; exit 1; }

# --- Netz ---------------------------------------------------------------------
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
[ "$VPC_ID" = "None" ] && { echo "Keine Default-VPC in $REGION gefunden." >&2; exit 1; }

read -r SUBNET_ID SUBNET_CIDR < <(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'sort_by(Subnets,&AvailabilityZone)[0].[SubnetId,CidrBlock]' --output text)
log "Region $REGION, VPC $VPC_ID, Subnetz $SUBNET_ID ($SUBNET_CIDR)"

# --- Security Groups (werden wiederverwendet, falls vorhanden) -----------------
sg_id() {
  aws ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$1" \
    --query 'SecurityGroups[0].GroupId' --output text
}

ensure_sg() {
  local name="$1" desc="$2" id
  id=$(sg_id "$name")
  if [ "$id" = "None" ]; then
    id=$(aws ec2 create-security-group --group-name "$name" --description "$desc" \
      --vpc-id "$VPC_ID" --query GroupId --output text)
    aws ec2 create-tags --resources "$id" --tags Key=Project,Value="$TAG"
  fi
  echo "$id"
}

allow() {  # Regel hinzufuegen, "existiert bereits" ignorieren
  aws ec2 authorize-security-group-ingress "$@" >/dev/null 2>&1 || true
}

SG_WEB=$(ensure_sg "${TAG}-web" "M346 Nextcloud Web: 22/80/443")
SG_DB=$(ensure_sg "${TAG}-db" "M346 Nextcloud DB: 3306 nur vom Web-Server")
for p in 22 80 443; do
  allow --group-id "$SG_WEB" --protocol tcp --port "$p" --cidr 0.0.0.0/0
done
allow --group-id "$SG_DB" --protocol tcp --port 3306 --source-group "$SG_WEB"
allow --group-id "$SG_DB" --protocol tcp --port 22 --source-group "$SG_WEB"
log "Security Groups: web=$SG_WEB db=$SG_DB"

# --- Image: aktuelles Ubuntu 24.04 LTS von Canonical ---------------------------
AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*' \
            Name=state,Values=available \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
log "AMI $AMI_ID (Ubuntu 24.04)"

KEY_ARGS=()
[ -n "$KEY_NAME" ] && KEY_ARGS=(--key-name "$KEY_NAME")

launch() {  # launch <rolle> <typ> <sg> <user-data> [weitere Argumente]
  local role="$1" type="$2" sg="$3" ud="$4"; shift 4
  aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$type" \
    --subnet-id "$SUBNET_ID" --security-group-ids "$sg" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} \
    --user-data "file://$ud" "$@" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG}-${role}},{Key=Project,Value=${TAG}}]" \
    --query 'Instances[0].InstanceId' --output text
}

# --- DB-Server mit fester privater IP starten ---------------------------------
# Freie IP im Subnetz zufaellig waehlen; falls belegt, neuer Versuch.
DB_ID=""
for _ in 1 2 3 4 5; do
  DB_IP=$(python3 -I - "$SUBNET_CIDR" <<'PY'
import ipaddress, random, sys
net = ipaddress.ip_network(sys.argv[1])
print(net[random.randint(20, min(250, net.num_addresses - 2))])
PY
)
  "$DIR/render.sh" "$SUBNET_CIDR" "$DB_IP" >/dev/null
  if DB_ID=$(launch db "$DB_TYPE" "$SG_DB" "$OUT/db.user-data.yaml" \
      --private-ip-address "$DB_IP" 2>/dev/null); then
    break
  fi
  log "IP $DB_IP nicht verfuegbar, neuer Versuch ..."
  DB_ID=""
done
[ -z "$DB_ID" ] && { echo "DB-Server konnte nicht gestartet werden." >&2; exit 1; }
log "DB-Server  $DB_ID (interne IP $DB_IP)"

WEB_ID=$(launch web "$WEB_TYPE" "$SG_WEB" "$OUT/web.user-data.yaml" \
  --associate-public-ip-address)
log "Web-Server $WEB_ID"

aws ec2 wait instance-running --instance-ids "$DB_ID" "$WEB_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$WEB_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
log "Instanzen laufen. Oeffentliche IP: $PUBLIC_IP"

# --- Warten bis der Installationsassistent antwortet (max. 15 Min) ------------
log "Warte auf Installation (dauert ca. 3-5 Minuten) ..."
READY="NEIN"
for _ in $(seq 1 90); do
  PAGE=$(curl -s --max-time 5 "http://${PUBLIC_IP}/" || true)
  if grep -qi 'nextcloud' <<<"$PAGE"; then READY="JA"; break; fi
  sleep 10
done

# shellcheck source=/dev/null
source "$OUT/secrets.env"
cat <<EOF

==============================================
 Nextcloud auf AWS
==============================================
 URL                 : http://${PUBLIC_IP}/
 Assistent erreichbar: ${READY}
 Web-Server          : ${WEB_ID}
 DB-Server           : ${DB_ID} (${DB_HOST})

 Angaben fuer den Assistenten:
  Datenverzeichnis   : /var/nextcloud-data
  Datenbank-Typ      : MySQL/MariaDB
  Datenbank-Benutzer : ${DB_USER}
  Datenbank-Passwort : ${DB_PASS}
  Datenbank-Name     : ${DB_NAME}
  Datenbank-Host     : ${DB_HOST}:3306

 DB-Root-Passwort    : siehe rendered/secrets.env
 Aufraeumen          : ./scripts/destroy-aws.sh
==============================================
EOF
