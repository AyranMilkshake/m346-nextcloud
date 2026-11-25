# 2. Inbetriebnahme

## 2.1 Netz vorbereiten

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
