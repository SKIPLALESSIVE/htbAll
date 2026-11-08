# 07 — Introduction to Web Applications

## Objectifs
Comprendre l'architecture d'une app web et énumérer méthodiquement : technologies, endpoints, authentification, rôles, API.

---

## 1. Anatomie

```
Navigateur → (HTTPS) → Serveur web (Apache/Nginx/IIS)
                        ├── Application (PHP/Python/Node/Java/.NET)
                        ├── Base de données (MySQL/PostgreSQL/MSSQL)
                        └── Services tierces (Redis, S3, API interne)
```

### Points d'attaque par couche
| Couche | Faiblesses |
|---|---|
| Transport | TLS faible, certificats, redirections |
| Serveur | version, fichiers par défaut, listing |
| Application | logique métier, auth, autorisation, validation |
| Données | SQLi, backups exposés, secrets en clair |
| Client | XSS, CSRF, clés API dans le JS |

---

## 2. Énumération

```bash
# Techno & serveur
whatweb -a3 http://<TARGET>
curl -sI http://<TARGET>
nmap -p80,443 --script http-headers,http-enum,http-title <TARGET>

# Contenu
ffuf -u http://<TARGET>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -mc all -fc 404
ffuf -u http://<TARGET>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt -e .php,.txt,.bak,.old,.zip,.tar.gz

# Extensions et backups
curl -s -o /dev/null -w "%{http_code}\n" http://<TARGET>/index.php.bak
curl -s -o /dev/null -w "%{http_code}\n" http://<TARGET>/.git/HEAD
```

```bash
# Fichiers à tester systématiquement
robots.txt sitemap.xml .git/config .env .htaccess web.config
phpinfo.php server-status server-info backup.zip db.sql dump.sql
```

---

## 3. Cartographier l'application à la main

1. **Parcourir** avec Burp en proxy : chaque clic génère une requête.
2. **Lister les endpoints** : `sitemap` de Burp, ou
   ```bash
   cat burp_requests.txt | grep -oP '(?<=GET |POST )/[^ ?]*' | sort -u
   ```
3. **Identifier les paramètres** : `?id=`, `?page=`, `?file=`, `?url=`, `?cmd=`.
4. **Repérer les rôles** : cookie, JWT, champ `role`, `admin=true`.
5. **Noter les formulaires** : login, recherche, upload, profil, contact.

### Questions à se poser
- Quelle est la techno ? (header `X-Powered-By`, extension `.php`, erreurs)
- Où sont les données utilisateur reflétées ?
- Y a-t-il des IDs numériques séquentiels ?
- Les fichiers uploadés sont-ils accessibles par URL ?
- L'app fait-elle des requêtes sortantes (SSRF) ?

---

## 4. Authentification & sessions

```bash
# Cookie / token
curl -si -d "user=test&pass=test" http://<TARGET>/login | grep -i "set-cookie\|location"

# JWT : décoder sans vérifier
echo "<JWT>" | cut -d. -f2 | base64 -d 2>/dev/null | jq

# Tester le rôle
# Modifier "role":"user" → "role":"admin", re-signer si secret faible
```

| Mécanisme | Faiblesse typique |
|---|---|
| Cookie de session | prédictible, pas de flag `HttpOnly` |
| JWT | `alg:none`, secret faible, `kid` injection |
| Basic auth | brute force, pas de lockout |
| API key en clair | dans le JS ou `.env` |

---

## 5. Technologies & indices

```bash
# Depuis les headers
curl -sI http://<TARGET> | grep -iE "server|x-powered-by|x-aspnet|set-cookie"

# Depuis le HTML
curl -s http://<TARGET> | grep -oiE "(wp-content|drupal|joomla|laravel|django|react|angular|vue)[^\"']*" | sort -u

# Versions
curl -s http://<TARGET>/readme.html      # WordPress
curl -s http://<TARGET>/CHANGELOG.txt    # Drupal
```

| Indice | Techno |
|---|---|
| `wp-content`, `wp-login.php` | WordPress |
| `sites/default/files` | Drupal |
| `index.php?option=com_` | Joomla |
| `X-Powered-By: Express` | Node/Express |
| `.aspx`, `__VIEWSTATE` | ASP.NET |
| `JSESSIONID` | Java/Tomcat |

---

## 6. Fuzzing structuré

```bash
# Répertoires (filtrer par taille pour éliminer les pages génériques)
ffuf -u http://<TARGET>/FUZZ -w <WORDLIST> -mc 200,204,301,302,307,401,403 -fs 0

# Paramètres (GET)
ffuf -u "http://<TARGET>/page?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs <TAILLE>

# Valeurs d'un paramètre connu
ffuf -u "http://<TARGET>/index.php?id=FUZZ" -w <WORDLIST_NUMBERS> -fs <TAILLE>

# POST body
ffuf -u http://<TARGET>/login -X POST -d "username=FUZZ&password=test" -w users.txt -fc 200 -fs 1234

# Sous-domaines / vhosts
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fs <TAILLE>
```

Options à connaître :
| Option | Rôle |
|---|---|
| `-mc all` | tous les codes |
| `-fc 404` | filtrer un code |
| `-fs <n>` | filtrer une taille |
| `-fw <n>` | filtrer un nombre de mots |
| `-mr <regex>` | garder si la réponse matche |
| `-recursion` | descendre dans les dirs |
| `-rate 50` | limiter (utile si instable) |
| `-o out.json -of json` | sauvegarder |

---

## 7. Checklist d'énumération web

- [ ] Techno + version serveur/app
- [ ] Arborescence (ffuf dirs + fichiers + extensions)
- [ ] robots.txt, sitemap, `.git`, `.env`, backups
- [ ] Tous les paramètres listés (GET/POST/JSON)
- [ ] Login / inscription / reset password testés fonctionnellement
- [ ] Rôles et IDs observés
- [ ] Upload repéré et fichiers accessibles
- [ ] API découverte (`/api`, `swagger`, `graphql`)
- [ ] Erreurs provoquées (injection de `'`, `"`, `{{7*7}}`, `../../`)
