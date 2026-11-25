# M346 Projekt: Nextcloud in der Cloud

Nextcloud (Community Edition, Archiv-Variante, ohne Docker, ohne Web Installer) auf zwei getrennten Servern, vollständig als Infrastructure as Code (Cloud-Init + Bash).

| | |
|---|---|
| Modul | 346 Cloudlösungen konzipieren und realisieren |
| Gruppe | `Ayan Basalamah`, `Samiullah Safi` |
| Lehrperson | `Oliver Lux` |
| Cloud-Anbieter | `AWS` |

## Inhalt

1. [Architektur](docs/01-architektur.md)
2. [Inbetriebnahme](docs/02-inbetriebnahme.md)
3. [Testprotokoll](docs/03-tests.md)
4. [Projektorganisation und Aufgabenverteilung](docs/04-projektorganisation.md)
5. [Git-Workflow und Commit-Konventionen](docs/05-git-workflow.md)

## Quickstart AWS (1 Befehl)

Voraussetzung: [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) mit gültigen Credentials (z. B. aus dem AWS Academy Learner Lab).

```bash
./scripts/deploy-aws.sh
```

Das Skript legt Security Groups an, startet DB- und Web-Server mit Cloud-Init, wartet bis der Installationsassistent erreichbar ist und gibt URL und Datenbank-Angaben aus. Aufräumen mit `./scripts/destroy-aws.sh`.

## Quickstart manuell (beliebige Cloud)

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
├── .github/workflows/       # CI: ShellCheck + Validierung der Cloud-Init-Dateien
├── scripts/
│   ├── deploy-aws.sh        # komplette Bereitstellung in AWS per CLI
│   ├── destroy-aws.sh       # entfernt alle AWS-Ressourcen des Projekts
│   ├── render.sh            # erzeugt Cloud-Init-Dateien inkl. zufälliger Passwörter
│   ├── install-db.sh        # MariaDB installieren, absichern, Firewall
│   └── install-web.sh       # Apache + PHP + Nextcloud-Archiv, Verbindungstest, IP-Ausgabe
└── docs/                    # Dokumentation (Markdown), Screenshots in docs/img/
```

## Voraussetzungen

- Zwei Ubuntu-24.04-LTS-Server im **gleichen privaten Netz** (Cloud-Init-fähiges Image)
- Web-Server mit öffentlicher IP, Security Group: 22, 80, 443 eingehend
- DB-Server **ohne** öffentliche Erreichbarkeit der Port 3306 (nur Web-Subnetz)
- `bash`, `openssl`, `python3` auf dem Rechner, auf dem `render.sh` läuft
- Für `deploy-aws.sh` zusätzlich `aws` (CLI v2) und `curl`; die Default-VPC wird verwendet
