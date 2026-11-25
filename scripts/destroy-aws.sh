#!/usr/bin/env bash
# destroy-aws.sh - loescht alle von deploy-aws.sh erstellten Ressourcen
# (Instanzen und Security Groups mit Tag Project=m346-nextcloud).
#
# Aufruf: ./scripts/destroy-aws.sh
set -euo pipefail

REGION="${REGION:-$(aws configure get region 2>/dev/null || true)}"
export AWS_DEFAULT_REGION="${REGION:-us-east-1}"
TAG="m346-nextcloud"

IDS=$(aws ec2 describe-instances \
  --filters Name=tag:Project,Values="$TAG" \
            Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -n "$IDS" ]; then
  echo "[destroy] Beende Instanzen: $IDS"
  # shellcheck disable=SC2086
  aws ec2 terminate-instances --instance-ids $IDS >/dev/null
  # shellcheck disable=SC2086
  aws ec2 wait instance-terminated --instance-ids $IDS
else
  echo "[destroy] Keine laufenden Instanzen gefunden."
fi

# DB-SG zuerst, da sie auf die Web-SG verweist
for name in "${TAG}-db" "${TAG}-web"; do
  SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$name" \
    --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$SG" != "None" ]; then
    echo "[destroy] Loesche Security Group $name ($SG)"
    aws ec2 delete-security-group --group-id "$SG"
  fi
done

echo "[destroy] Fertig. Lokale Passwoerter entfernen mit: rm -rf rendered/"
