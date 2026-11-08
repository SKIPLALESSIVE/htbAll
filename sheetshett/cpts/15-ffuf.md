# 15 — Attacking Web Applications with Ffuf

## Objectifs
Fuzzer directories, fichiers, vhosts, paramètres et valeurs avec ffuf ; maîtriser les filtres/matchers, la récursion et les wordlists.

---

## 1. Bases

```bash
ffuf -u http://<TARGET>/FUZZ -w <WORDLIST>
ffuf -u http://<TARGET>/FUZZ -w <WORDLIST> -mc 200
ffuf -u http://<TARGET>/FUZZ -w <WORDLIST> -e .php,.html,.txt
```

### Wordlists
```bash
/usr/share/seclists/Discovery/Web-Content/common.txt
/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt
/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt
/usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt
/usr/share/seclists/Discovery/Web-Content/api/objects.txt
/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt
```

---

## 2. Directory / file fuzzing

```bash
# Répertoires
ffuf -u http://<TARGET>/FUZZ -w raft-medium-directories.txt -mc 200,204,301,302,307,401,403 -fc 404

# Fichiers avec extensions
ffuf -u http://<TARGET>/FUZZ -w common.txt -e .php,.bak,.old,.txt,.zip

# Ajouter un slash final
ffuf -u http://<TARGET>/FUZZ/ -w dirs.txt

# Fuzzer un chemin complet
ffuf -u http://<TARGET>/FUZZ -w paths.txt -recursion -recursion-depth 2

# Récursion
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -recursion -recursion-depth 2 -recursion-strategy default
```

### Options de sortie
```bash
-o results.json -of json
-o results.html -of html
-o results.csv -of csv
-s                      # silent
-v                      # verbose (URL complète)
-c                      # couleur
```

---

## 3. Vhosts / sous-domaines

```bash
# Host header fuzzing
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fs 0

# Filtrer par taille de la réponse par défaut
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fw 10 -fs 1234

# DNS
ffuf -u http://FUZZ.<DOMAIN> -w subdomains.txt -mc all -fl 0
```

---

## 4. Paramètres & valeurs

```bash
# Découvrir des paramètres GET
ffuf -u "http://<TARGET>/page?FUZZ=test" -w burp-parameter-names.txt -fs 0

# Découvrir des paramètres POST
ffuf -u "http://<TARGET>/login" -X POST -d "FUZZ=test" -H "Content-Type: application/x-www-form-urlencoded" -w burp-parameter-names.txt -fs 0

# Fuzzer une valeur (IDOR, injection)
ffuf -u "http://<TARGET>/user?id=FUZZ" -w ids.txt -mc all -fs 0

# Fuzzer un JSON
ffuf -u http://<TARGET>/api -X POST -H "Content-Type: application/json" -d '{"user":"FUZZ"}' -w users.txt

# Fuzzer un cookie / header
ffuf -u http://<TARGET>/ -b "session=FUZZ" -w sessions.txt
ffuf -u http://<TARGET>/ -H "X-Forwarded-For: FUZZ" -w ips.txt
```

---

## 5. Matchers & filtres

| Option | Effet |
|---|---|
| `-mc` | Match status codes (ex. `-mc 200,302`) |
| `-fc` | Filter status codes |
| `-ms` | Match size |
| `-fs` | Filter size |
| `-mw` | Match words |
| `-fw` | Filter words |
| `-ml` | Match lines |
| `-fl` | Filter lines |
| `-mr` | Match regex |
| `-fr` | Filter regex |
| `-mt` | Match time |
| `-ft` | Filter time |

```bash
# Exclure les 404 et les réponses vides
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -fc 404 -fs 0

# Filtrer plusieurs tailles
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -fs 1234,0,5678

# Filtrer par regex (page "not found")
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -fr "not found|error"

# Match regex (tokens, emails)
ffuf -u http://<TARGET>/FUZZ -w files -mr "AKIA[0-9A-Z]{16}"
```

> Important : sur une app avec réponses dynamiques, filtrer par **size** ou **words** peut masquer des résultats. Toujours inspecter un échantillon.

---

## 6. Authentification & headers

```bash
# Cookie
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -H "Cookie: PHPSESSID=<SESSION>"

# Bearer token
ffuf -u http://<TARGET>/api/FUZZ -w endpoints.txt -H "Authorization: Bearer <TOKEN>"

# Basic auth
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -H "Authorization: Basic $(echo -n user:pass | base64)"

# Suivre les redirections
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -r

# Ignorer TLS
ffuf -u https://<TARGET>/FUZZ -w dirs.txt -k
```

---

## 7. Performance & automatisation

```bash
# Threads / rate
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -t 100 -rate 200

# Timeout
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -timeout 10

# Reprise
ffuf -u http://<TARGET>/FUZZ -w dirs.txt -o out.json -of json

# Input depuis stdin
ffuf -u http://<TARGET>/FUZZ -w - < words.txt

# Encodage des payloads
ffuf -u http://<TARGET>/FUZZ -w words.txt -enc utf-8
```

### Exemple : découverte complète
```bash
# 1) Répertoires
ffuf -u http://<TARGET>/FUZZ -w raft-medium-directories.txt -mc 200,301,302,403 -fc 404 -o dirs.json -of json

# 2) Fichiers sur les répertoires trouvés
ffuf -u http://<TARGET>/admin/FUZZ -w common.txt -e .php,.bak -mc 200

# 3) Paramètres
ffuf -u "http://<TARGET>/admin/index.php?FUZZ=1" -w burp-parameter-names.txt -fs 0

# 4) Valeurs
ffuf -u "http://<TARGET>/admin/index.php?id=FUZZ" -w ids.txt -mc all
```

---

## 8. Comparaison d'outils

| Outil | Points forts |
|---|---|
| **ffuf** | rapide, filtres puissants, vhosts, params |
| **gobuster** | simple, dir/dns/vhost |
| **feroxbuster** | récursif automatique, rust |
| **wfuzz** | très flexible, scripting |
| **dirsearch** | orienté fichiers/extensions |

```bash
feroxbuster -u http://<TARGET> -w raft-medium-directories.txt -x php,html -d 3
gobuster dir -u http://<TARGET> -w common.txt -x php,txt -t 50
```

---

## Checklist
- [ ] Wordlist adaptée (taille, techno)
- [ ] Extensions testées
- [ ] Vhosts testés
- [ ] Paramètres GET/POST découverts
- [ ] Résultats filtrés mais échantillon vérifié manuellement
- [ ] Sortie sauvegardée (json/html)
