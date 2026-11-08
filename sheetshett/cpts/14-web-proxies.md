# 14 — Using Web Proxies

## Objectifs
Intercepter, modifier et rejouer le trafic HTTP(S) avec Burp Suite et ZAP ; configurer les outils CLI pour passer par le proxy ; automatiser les tests.

---

## 1. Burp Suite — setup

```bash
# Lancer
burpsuite

# Proxy listener par défaut : 127.0.0.1:8080
# Configurer le navigateur (FoxyProxy) ou le proxy système
```

### Certificat CA
1. Naviguer sur `http://burp` → *CA Certificate*
2. Importer le certificat dans le navigateur / système
3. Ou depuis le proxy : `http://127.0.0.1:8080/cert`

```bash
# Import système (Linux) pour curl/wget
sudo cp cacert.der /usr/local/share/ca-certificates/burp.crt
sudo update-ca-certificates
```

### Modules clés
| Module | Usage |
|---|---|
| **Proxy → HTTP history** | Voir toutes les requêtes |
| **Repeater** (Ctrl+R) | Rejouer / modifier une requête |
| **Intruder** (Ctrl+I) | Fuzzing / brute force |
| **Decoder** | Encoder/décoder (URL, base64, HTML, hex) |
| **Comparer** | Diff de réponses |
| **Scanner** (Pro) | Scan actif |
| **Extensions** | BApp Store (Autorize, JWT Editor, Param Miner) |

---

## 2. Burp — techniques

### Repeater
- Modifier méthode, path, headers, body → observer status/length.
- `Ctrl+Space` autocomplétion des headers.
- Comparer avec *Send to Comparer*.

### Intruder — types d'attaque
| Type | Usage |
|---|---|
| **Sniper** | 1 payload set, 1 position à la fois |
| **Battering ram** | Même payload partout |
| **Pitchfork** | Plusieurs sets en parallèle (1:1) |
| **Cluster bomb** | Produit cartésien |

```
# Positions
§payload§

# Payloads
Simple list, Runtime file, Custom iterator, Character blocks, Numbers, Dates, Brute forcer, Null payloads

# Options
Grep - Match / Extract, Redirections, Threads
```

> Community Edition : Intruder est throttlé (1 req/s). Utiliser ffuf pour la vitesse.

### Extensions utiles
- **Autorize** : détection de contrôle d'accès manquant
- **JWT Editor** : forge/attaque de JWT
- **Param Miner** : paramètres cachés
- **Turbo Intruder** : requêtes massives
- **Logger++** : journalisation avancée

---

## 3. ZAP

```bash
zaproxy
# ou en daemon
zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.key=<KEY>

# Scan rapide
zap-cli quick-scan -s xss,sqli http://<TARGET>
zap-cli active-scan http://<TARGET>
```

Fonctions : Spider, Ajax Spider, Active Scan, Fuzzer, Break points, HUD.

---

## 4. Outils CLI via proxy

```bash
# curl
curl -x http://127.0.0.1:8080 -k https://<TARGET>/
curl -x http://127.0.0.1:8080 --proxy-user user:pass https://<TARGET>/

# ffuf (n'utilise pas le proxy par défaut)
ffuf -u https://<TARGET>/FUZZ -w words.txt -x http://127.0.0.1:8080 -k

# sqlmap
sqlmap -u "https://<TARGET>/?id=1" --proxy=http://127.0.0.1:8080 --force-ssl

# nmap (via HTTP proxy pour scripts http)
nmap --proxies http://127.0.0.1:8080 -p80 <TARGET>

# proxychains
proxychains4 curl http://<TARGET>/

# Chrome/Chromium
chromium --proxy-server=http://127.0.0.1:8080 --ignore-certificate-errors
```

---

## 5. Manipulation de requêtes

```bash
# Rejouer avec headers custom
curl -X POST http://<TARGET>/api -H "Content-Type: application/json" -d '{"user":"admin"}'

# Changer la méthode
curl -X PUT http://<TARGET>/api/user/1 -d 'role=admin'

# Forcer Host / X-Forwarded-For
curl -H "X-Forwarded-For: 127.0.0.1" http://<TARGET>/admin
curl -H "X-Original-URL: /admin" http://<TARGET>/
curl -H "Host: internal.<DOMAIN>" http://<TARGET>/
```

### Encodage / décodage
```bash
# URL
python3 -c "import urllib.parse;print(urllib.parse.quote('test test'))"
# Base64
echo -n 'admin:admin' | base64
echo 'YWRtaW46YWRtaW4=' | base64 -d
# Hex
xxd -p <<< 'test'
```

---

## 6. Automatisation & interception

```bash
# mitmproxy (alternative CLI)
mitmproxy -p 8080
mitmdump -p 8080 -w flows.mitm
mitmweb -p 8080

# Rejouer un flow
mitmdump -nc -r flows.mitm
```

### Burp — match & replace
Proxy → Options → *Match and Replace* : modifier User-Agent, ajouter un header d'auth, remplacer `role=user` par `role=admin`.

### Burp — session handling
Permet d'injecter un token CSRF ou un cookie dynamique dans les requêtes automatisées (macro + rule).

---

## 7. Tests guidés par proxy

1. **Cartographier** : parcourir l'app, historique complet.
2. **Repérer** : paramètres, cookies, JWT, headers, API.
3. **Tester** : Repeater (manipulation fine), Intruder/ffuf (volume).
4. **Vérifier** : contrôle d'accès (Autorize), IDOR, injection.
5. **Documenter** : requête/réponse brutes dans le rapport.

### Checklist d'analyse d'une requête
- [ ] Méthode HTTP alternative acceptée ?
- [ ] Headers de confiance (`X-Forwarded-For`, `X-Original-URL`) ?
- [ ] Paramètres cachés / mass assignment ?
- [ ] Cookies : flags `HttpOnly`, `Secure`, `SameSite` ?
- [ ] JWT : algorithme (`none`, HS256 vs RS256), expiration ?
- [ ] Contrôle d'accès horizontal/vertical ?
- [ ] Encodages alternatifs (double URL, unicode) ?

---

## Commandes utiles
```bash
# Démarrer Burp headless (Pro)
java -jar burpsuite_pro.jar --project-file=proj.burp

# Exporter l'historique
# Proxy → HTTP history → Save items

# Comparer deux réponses
diff <(curl -s http://<TARGET>/a) <(curl -s http://<TARGET>/b)
```
