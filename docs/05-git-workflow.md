# 5. Git-Workflow

## 5.1 Regeln

- Gemeinsames Repository, jede Person arbeitet mit dem **eigenen** Git-Account.
- `main` ist geschützt: keine direkten Pushes, Änderungen nur über **Pull Requests**.
- Jede Änderung entsteht in einem eigenen Branch.
- Jeder Pull Request wird von **einer anderen Person** geprüft und freigegeben, bevor gemergt wird.
- Merge-Konflikte löst die Person, die den Branch ändert (`git pull --rebase origin main` bzw. Merge und manuelles Auflösen).
- Die Lehrperson ist als Mitglied/Collaborator eingeladen.

## 5.2 Ablauf

```bash
git clone <repo-url>
git switch -c feature/db-firewall          # eigener Branch
# ... Änderungen ...
git add scripts/install-db.sh
git commit -m "feat(db): Firewall erlaubt 3306 nur aus Web-Subnetz"
git push -u origin feature/db-firewall     # danach Pull Request auf GitHub
```

Nach dem Merge lokal aktualisieren: `git switch main && git pull`.

## 5.3 Branch-Namen

`<typ>/<kurzbeschreibung>` in Kleinbuchstaben, z. B. `feature/web-apache`, `fix/db-bind-address`, `docs/testprotokoll`.

## 5.4 Commit-Messages

Format: `<typ>(<bereich>): <kurze Beschreibung im Präsens>`

| Typ | Verwendung |
|---|---|
| `feat` | neue Funktion |
| `fix` | Fehlerbehebung |
| `docs` | Dokumentation |
| `test` | Testprotokoll, Screenshots |
| `refactor` | Umbau ohne Verhaltensänderung |
| `chore` | Sonstiges (z. B. `.gitignore`) |

Bereiche: `db`, `web`, `render`, `readme`, `docs`.

Beispiele:

```
feat(web): Apache-VirtualHost mit Document Root auf Nextcloud
fix(db): bind-address auf interne IP statt 127.0.0.1
docs(tests): Screenshots für T1-T3 ergänzt
```

Pro Commit eine logische Änderung, keine Sammel-Commits wie "update" oder "fix".

## 5.5 Checkliste vor Abgabe

- [ ] Lehrperson hat Zugriff aufs Repository
- [ ] Alle Pull Requests gemergt, `main` ist lauffähig
- [ ] Alle Gruppenmitglieder haben Commits in der History
- [ ] `rendered/` und Passwörter sind **nicht** im Repository (`git log -p | grep -i pass` prüfen)
- [ ] Testprotokoll ausgefüllt, Screenshots eingebunden und Links funktionieren
- [ ] README-Quickstart auf frischer Umgebung getestet
