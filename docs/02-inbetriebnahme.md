# 2. Inbetriebnahme

Es gibt zwei Wege: **automatisch mit AWS** (empfohlen, Kapitel 2.0) oder **manuell** in einer beliebigen Cloud (Kapitel 2.1-2.3).

## 2.0 Automatisch mit AWS

```bash
git clone https://github.com/AyranMilkshake/m346-nextcloud.git && cd m346-nextcloud
aws configure            # bzw. Learner-Lab-Credentials nach ~/.aws/credentials kopieren
./scripts/deploy-aws.sh
```

| Schritt | Was `deploy-aws.sh` macht |
|---|---|
| 1 | Default-VPC und ein Default-Subnetz ermitteln |
| 2 | Security Groups `m346-nextcloud-web` (22/80/443 öffentlich) und `m346-nextcloud-db` (3306 und 22 **nur** von der Web-SG) anlegen |
| 3 | Aktuelles Ubuntu-24.04-Image von Canonical suchen |
| 4 | Freie interne IP für den DB-Server wählen und `render.sh` aufrufen |
| 5 | DB-Server (feste interne IP) und Web-Server (öffentliche IP) mit Cloud-Init starten |
| 6 | Warten, bis `http://<IP>/` den Installationsassistenten zeigt (max. 15 Min) |
| 7 | URL und Datenbank-Angaben ausgeben |

Optionale Variablen:

| Variable | Standard | Zweck |
|---|---|---|
| `REGION` | aus `aws configure`, sonst `us-east-1` | AWS-Region |
| `KEY_NAME` | leer | Key Pair für SSH, im Learner Lab `vockey` |
| `WEB_TYPE` / `DB_TYPE` | `t3.small` | Instanztypen |

Beispiel: `KEY_NAME=vockey ./scripts/deploy-aws.sh`

Aufräumen: `./scripts/destroy-aws.sh` (beendet alle Instanzen mit Tag `Project=m346-nextcloud` und löscht die Security Groups).

> **Hinweis:** Der DB-Server erhält im Default-Subnetz eine öffentliche IP, damit er Pakete installieren kann. Die Security Group lässt eingehend aber nur Verbindungen vom Web-Server zu, MariaDB lauscht nur auf der internen IP.

## 2.1 Netz vorbereiten (manuell)

1. Privates Netz/Subnetz anlegen, z. B. `10.0.1.0/24`.
2. Security Groups:

| Server | Eingehend |
|---|---|
| Web | TCP 22, 80, 443 aus `0.0.0.0/0` |
| DB | TCP 22 (Admin-IP), TCP 3306 **nur** aus dem Web-Subnetz |

3. DB-Server mit **fester privater IP** planen, z. B. `10.0.1.10`, weil sie in der Konfiguration des Web-Servers stehen muss.

## 2.2 Cloud-Init-Dateien erzeugen

```bash
git clone <repo-url> && cd <repo>
./scripts/render.sh 10.0.1.0/24 10.0.1.10
```

Ausgabe in `rendered/` (wird nicht eingecheckt):

- `db.user-data.yaml`
- `web.user-data.yaml`
- `secrets.env`

## 2.3 Server starten

1. **DB-Server** zuerst: Ubuntu 24.04 LTS, private IP `10.0.1.10`, **keine** öffentliche Freigabe von 3306. Inhalt von `db.user-data.yaml` als *User Data / Cloud-Init* einfügen.
2. **Web-Server**: Ubuntu 24.04 LTS, öffentliche IP, Inhalt von `web.user-data.yaml` als *User Data* einfügen.

Der Web-Server wartet bis zu 10 Minuten auf die Datenbank, die Reihenfolge ist also nicht kritisch.

### Beispiel mit AWS CLI

```bash
aws ec2 run-instances --image-id <ubuntu-24.04-ami> --instance-type t3.small \
  --subnet-id <subnet> --private-ip-address 10.0.1.10 --security-group-ids <sg-db> \
  --user-data file://rendered/db.user-data.yaml

aws ec2 run-instances --image-id <ubuntu-24.04-ami> --instance-type t3.small \
  --subnet-id <subnet> --associate-public-ip-address --security-group-ids <sg-web> \
  --user-data file://rendered/web.user-data.yaml
```

## 2.4 Ergebnis prüfen

Nach ca. 3-5 Minuten (Konsole/Systemlog des Web-Servers oder per SSH `cat /root/nextcloud-install-info.txt`):

```
URL (oeffentlich) : http://<IP>/
Assistent erreichbar: JA
DB-Verbindung OK  : JA
Datenbank-Benutzer / -Passwort / -Name / -Host ...
```

URL im Browser öffnen, der Nextcloud-Installationsassistent erscheint. Dort Admin-Konto anlegen, Datenverzeichnis `/var/nextcloud-data` belassen, die ausgegebenen Datenbank-Angaben eintragen.

## 2.5 Fehlersuche

| Symptom | Prüfen |
|---|---|
| Keine Ausgabe auf der Konsole | `sudo cat /var/log/cloud-init-output.log`, `/var/log/nextcloud-project-web.log` |
| `DB-Verbindung OK: NEIN` | Security Group der DB, richtige DB-IP an `render.sh` übergeben, `ufw status` und `ss -ltn` auf dem DB-Server |
| Seite lädt nicht | `systemctl status apache2`, Security Group Port 80 |
| Assistent meldet Datenbankfehler | Host im Assistenten als `<DB-IP>:3306` angeben, Subnetz-Angabe aus `render.sh` mit tatsächlichem Subnetz vergleichen |

## 2.6 Aufräumen

Server in der Cloud-Konsole löschen. Lokal `rm -rf rendered/`.
