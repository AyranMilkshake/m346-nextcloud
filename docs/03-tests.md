# 3. Testprotokoll

> **Hinweis:** Die Felder mit `[...]` werden nach der echten Durchführung in der Cloud ausgefüllt. Screenshots in `docs/img/` ablegen und hier einbinden.

| Angabe | Wert |
|---|---|
| Testzeitpunkt | `[TT.MM.JJJJ, hh:mm]` |
| Testperson(en) | `[Name]` |
| Cloud / Region | `[...]` |
| Image | Ubuntu 24.04 LTS |
| Nextcloud-Version | `[z. B. 31.x]` |
| Repository-Stand (Commit) | `[git rev-parse --short HEAD]` |

## Übersicht

| ID | Testfall | Ergebnis |
|---|---|---|
| T1 | Cloud-Init läuft auf beiden Servern fehlerfrei durch | `[OK / NOK]` |
| T2 | Installationsassistent unter `http://<öffentliche IP>/` erreichbar | `[OK / NOK]` |
| T3 | DB-Server nur intern erreichbar (von aussen kein Zugriff auf 3306) | `[OK / NOK]` |
| T4 | Verbindung Web zu DB über interne IP funktioniert | `[OK / NOK]` |
| T5 | Konsole zeigt IP und DB-Angaben | `[OK / NOK]` |
| T6 | Root-Zugang DB nur mit Passwort (nicht ohne) | `[OK / NOK]` |
| T7 | Installationsassistent schliesst mit den ausgegebenen DB-Angaben erfolgreich ab | `[OK / NOK]` |
| T8 | Anmeldung und Datei-Upload in Nextcloud | `[OK / NOK]` |

---

## T1 Cloud-Init

- **Vorgehen:** Beide Server starten, `sudo cloud-init status --long` ausführen.
- **Erwartet:** `status: done`, keine Fehler in `/var/log/cloud-init-output.log`.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T1](img/t1-cloud-init.png)`
- **Fazit / Massnahmen:** `[...]`

## T2 Installationsassistent erreichbar

- **Vorgehen:** `http://<öffentliche IP>/` im Browser öffnen.
- **Erwartet:** Der Installationsassistent von Nextcloud wird direkt angezeigt (nicht unter `/nextcloud`).
- **Ergebnis:** `[...]`
- **Screenshot:** `![T2](img/t2-assistent.png)`
- **Fazit / Massnahmen:** `[...]`

## T3 DB von aussen nicht erreichbar

- **Vorgehen:** Von einem externen Rechner `nc -vz <DB-IP-oder-öffentliche-IP> 3306` bzw. `nmap -p 3306 <IP>`.
- **Erwartet:** Timeout / filtered / refused.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T3](img/t3-db-extern.png)`
- **Fazit / Massnahmen:** `[...]`

## T4 Verbindung Web zu DB

- **Vorgehen:** Auf dem Web-Server `mariadb -h <DB-IP> -u nextcloud -p nextcloud -e 'SELECT 1;'`.
- **Erwartet:** Ausgabe `1`.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T4](img/t4-db-verbindung.png)`
- **Fazit / Massnahmen:** `[...]`

## T5 Konsolenausgabe

- **Vorgehen:** Systemlog/Konsole des Web-Servers bzw. `cat /root/nextcloud-install-info.txt`.
- **Erwartet:** URL, interne IP, DB-Benutzer, DB-Passwort, DB-Name, DB-Host.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T5](img/t5-konsole.png)`
- **Fazit / Massnahmen:** `[...]`

## T6 DB-Root nur mit Passwort

- **Vorgehen:** Auf dem DB-Server als normaler Benutzer `mariadb -u root` (soll fehlschlagen), danach `mariadb -u root -p` mit Passwort aus `secrets.env`.
- **Erwartet:** Ohne Passwort Access denied, mit Passwort Erfolg.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T6](img/t6-root.png)`
- **Fazit / Massnahmen:** `[...]`

## T7 Installationsassistent abschliessen

- **Vorgehen:** Admin-Konto anlegen, DB-Angaben aus der Konsole eintragen, Installation starten.
- **Erwartet:** Installation erfolgreich, Nextcloud-Startseite wird angezeigt.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T7](img/t7-installation.png)`
- **Fazit / Massnahmen:** `[...]`

## T8 Login und Upload

- **Vorgehen:** Mit Admin-Konto anmelden, eine Datei hochladen und wieder öffnen.
- **Erwartet:** Datei erscheint in der Dateiliste und lässt sich öffnen.
- **Ergebnis:** `[...]`
- **Screenshot:** `![T8](img/t8-upload.png)`
- **Fazit / Massnahmen:** `[...]`

---

## Gesamtfazit

`[Zusammenfassung: Was lief gut, welche Probleme traten auf, welche Massnahmen/Empfehlungen ergeben sich?]`
