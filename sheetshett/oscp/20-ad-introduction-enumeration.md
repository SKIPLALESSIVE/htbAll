# 20 — Active Directory Introduction and Enumeration

## Objectifs
Comprendre AD (domaines, forêts, OU, GPO, trusts) et énumérer sans credentials puis avec un compte. 26 % de l'examen.

---

## 1. Vocabulaire

| Terme | Sens |
|---|---|
| **Domain** | limite d'administration (`corp.local`) |
| **Forest** | ensemble de domaines partageant un schéma |
| **DC** | contrôleur de domaine (KDC, LDAP, DNS) |
| **OU** | unité d'organisation (délégation) |
| **GPO** | stratégie de groupe |
| **Trust** | relation entre domaines/forêts |
| **SPN** | Service Principal Name (Kerberoast) |
| **ACL/ACE** | permissions AD (GenericAll, WriteDACL…) |

Comptes clés : `Administrator` (domaine), `krbtgt` (Golden Ticket), comptes de service (souvent faibles).

---

## 2. Prérequis réseau

```bash
# DNS : indispensable pour AD
sudo nano /etc/resolv.conf
nameserver <DC_IP>
# ou
echo "<DC_IP> <DOMAIN> dc01.<DOMAIN>" | sudo tee -a /etc/hosts

# Vérifier
nslookup <DOMAIN>
dig SRV _ldap._tcp.dc._msdcs.<DOMAIN>
```

---

## 3. Énumération sans credentials

```bash
# SMB null session
netexec smb <DC_IP> -u '' -p '' --shares --users --groups
netexec smb <DC_IP> -u '' -p '' --pass-pol
smbclient -L //<DC_IP>/ -N
enum4linux-ng -A <DC_IP>

# RPC
rpcclient -U '' -N <DC_IP>
rpcclient $> enumdomusers
rpcclient $> enumdomgroups
rpcclient $> querydominfo
rpcclient $> queryuser 0x1f4

# LDAP anonyme (rare mais possible)
ldapsearch -x -H ldap://<DC_IP> -b "dc=<DOMAIN>,dc=local"
```

```bash
# AS-REP roasting sans credentials (comptes sans pré-auth)
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -no-pass -format hashcat
hashcat -m 18200 asrep.txt <WORDLIST>
```

### Construire une liste d'utilisateurs
```bash
# RID brute force (si null session)
netexec smb <DC_IP> -u '' -p '' --rid-brute 4000
# Kerberos user enum (pas de lockout)
./kerbrute userenum --dc <DC_IP> -d <DOMAIN> users.txt
```

---

## 4. Énumération avec credentials

```bash
# SMB
netexec smb <DC_IP> -u <USER> -p <PASS> --users --groups --shares --loggedon-users
netexec smb <DC_IP> -u <USER> -p <PASS> --pass-pol
netexec smb <DC_IP> -u <USER> -p <PASS> -M spider_plus

# LDAP
ldapsearch -x -H ldap://<DC_IP> -D "<USER>@<DOMAIN>" -w '<PASS>' -b "dc=<DOMAIN>,dc=local" "(objectClass=user)" sAMAccountName
ldapsearch -x -H ldap://<DC_IP> -D "<USER>@<DOMAIN>" -w '<PASS>' -b "dc=<DOMAIN>,dc=local" "(objectClass=group)" cn

# BloodHound (collecte)
bloodhound-python -u <USER> -p <PASS> -d <DOMAIN> -ns <DC_IP> -c All
# ou
netexec ldap <DC_IP> -u <USER> -p <PASS> --bloodhound -c All
```

```bash
# Importer dans BloodHound
sudo neo4j start
bloodhound --no-sandbox
# Upload des .json → onglet Analysis
```

### Requêtes BloodHound essentielles
- Shortest Paths to Domain Admins
- Find Principals with DCSync Rights
- Shortest Paths to Unconstrained Delegation Systems
- Find All Kerberoastable Users
- Find Computers where Domain Users are Local Admin
- Shortest Paths from Kerberoastable Users

---

## 5. Cartographier le domaine

```bash
# Password policy AVANT tout spray
netexec smb <DC_IP> -u <USER> -p <PASS> --pass-pol
```

```bash
# Partages intéressants
netexec smb <DC_IP> -u <USER> -p <PASS> --shares
smbclient //<DC_IP>/SYSVOL -U '<USER>%<PASS>'
# chercher les scripts de login, GPO, cpassword
findstr /S /I cpassword \\<DC>\SYSVOL\<DOMAIN>\Policies\*.xml
```

```bash
# Session / sessions ouvertes
netexec smb <DC_IP> -u <USER> -p <PASS> --sessions
# Machines du domaine
netexec smb 10.10.10.0/24 -u <USER> -p <PASS> --gen-relay-list relay.txt
```

---

## 6. Outils Windows (si accès à une machine)

```powershell
# PowerView
Import-Module .\PowerView.ps1
Get-NetDomain
Get-NetUser | select samaccountname,description,lastlogon
Get-NetGroup "Domain Admins" | select member
Get-NetComputer -FullData | select name,operatingsystem
Find-LocalAdminAccess
Invoke-UserHunter
Get-ObjectAcl -SamAccountName <USER> -ResolveGUIDs | ? {$_.ActiveDirectoryRights -match "GenericAll|WriteDACL"}

# SharpHound
.\SharpHound.exe -c All
```

```cmd
:: Natif
net user /domain
net group "Domain Admins" /domain
net group "Enterprise Admins" /domain
nltest /dclist:<DOMAIN>
nltest /trusted_domains
```

---

## 7. Ce qu'il faut retenir de l'énumération

| Élément trouvé | Piste |
|---|---|
| Compte sans pré-auth | AS-REP roast |
| Compte avec SPN | Kerberoast |
| Description de compte avec un mot de passe | test direct |
| GenericAll / WriteDACL sur un groupe | prise de contrôle |
| Unconstrained delegation | capture de TGT |
| Machine où Domain Users est admin local | privesc immédiate |
| ACL sur le DC | DCSync |
| Partages SYSVOL avec cpassword | déchiffrement GPP |

---

## 8. Checklist

- [ ] DNS configuré vers le DC
- [ ] Null session / RPC testés
- [ ] Liste d'utilisateurs (RID, kerbrute, OSINT)
- [ ] AS-REP roast tenté
- [ ] Password policy lue
- [ ] BloodHound collecté et analysé
- [ ] Partages (SYSVOL, NETLOGON) inspectés
- [ ] Sessions / admins locaux cartographiés
- [ ] Chemins d'attaque notés par priorité
