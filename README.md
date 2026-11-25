# M346 Projekt: Nextcloud in der Cloud

Nextcloud (Community Edition, Archiv-Variante, **ohne Docker, ohne Web Installer**) auf zwei getrennten Servern, vollständig als Infrastructure as Code (Cloud-Init + Bash).

| | |
|---|---|
| Modul | 346 Cloudlösungen konzipieren und realisieren, GBS St.Gallen |
| Gruppe | `[Name A]`, `[Name B]`, `[Name C]` |
| Lehrperson | `[Name]` (Repository-Zugriff erteilt) |
| Cloud-Anbieter | `[z. B. AWS / Azure / Infomaniak]` |

## Inhalt

1. [Architektur](docs/01-architektur.md)
2. [Inbetriebnahme](docs/02-inbetriebnahme.md)
3. [Testprotokoll](docs/03-tests.md)
4. [Projektorganisation und Aufgabenverteilung](docs/04-projektorganisation.md)
5. [Git-Workflow und Commit-Konventionen](docs/05-git-workflow.md)

## Quickstart (3 Schritte)

```bash
# 1. Cloud-Init-Dateien erzeugen (Web-Subnetz, interne IP des DB-Servers)
./scripts/render.sh 10.0.1.0/24 10.0.1.10

# 2. DB-Server starten, User-Data = rendered/db.user-data.yaml  (interne IP 10.0.1.10)
# 3. Web-Server starten, User-Data = rendered/web.user-data.yaml
```

Nach ca. 3-5 Minuten zeigt die Konsole des Web-Servers (und `/etc/motd` nach dem Login) die URL sowie die Datenbank-Angaben für den Nextcloud-Installationsassistenten:

```
URL (oeffentlich) : http://<öffentliche IP>/
Datenbank-Benutzer / -Passwort / -Name / -Host
```

Details und Cloud-spezifische Hinweise: [docs/02-inbetriebnahme.md](docs/02-inbetriebnahme.md).

## Repository-Struktur

```
.
├── README.md
├── .gitignore               # rendered/ (enthält Passwörter) wird nie eingecheckt
├── scripts/
│   ├── render.sh            # erzeugt Cloud-Init-Dateien inkl. zufälliger Passwörter
│   ├── install-db.sh        # MariaDB installieren, absichern, Firewall
│   └── install-web.sh       # Apache + PHP + Nextcloud-Archiv, Verbindungstest, IP-Ausgabe
└── docs/                    # Dokumentation (Markdown)
```

## Voraussetzungen

- Zwei Ubuntu-24.04-LTS-Server im **gleichen privaten Netz** (Cloud-Init-fähiges Image)
- Web-Server mit öffentlicher IP, Security Group: 22, 80, 443 eingehend
- DB-Server **ohne** öffentliche Erreichbarkeit der Port 3306 (nur Web-Subnetz)
- `bash`, `openssl`, `python3` auf dem Rechner, auf dem `render.sh` läuft
